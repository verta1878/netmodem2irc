{ ===========================================================================
  netmodem2irc — D5 Direct UART Relay
  GPLv3 — Copyright (C) 2026 verta1878, sysop/0, wrench, kiddo, evga
  ---------------------------------------------------------------------------
  Direct TCP <-> UART relay. Bypasses the FOSSIL dispatch table entirely.
  Talks to NM_UART16550 register-level API:

    TCP socket → UartNetToGuest() → RX ring → BBS reads via FOSSIL
    BBS writes via FOSSIL → TX ring → UartGuestToNet() → TCP socket

  Why: lower latency, no INT 14h dispatch overhead, no function-number
  switching. The BBS door still calls FOSSIL (it doesn't know the
  difference). But the NETWORK side of the relay uses direct register
  access instead of FOSSIL functions.

  This is what netmodem2irc was built for — a virtual modem. The UART
  is emulated (NM_UART16550), so "direct port I/O" means writing to
  the emulated register set, not real hardware. Same byte path, less
  overhead.

  Architecture:
    ┌─────────────────────────────────────────────┐
    │  TCP listener                               │
    │       │                                     │
    │       ▼                                     │
    │  TDirectRelay                               │
    │  ┌────────────────┐   ┌──────────────────┐  │
    │  │ Socket recv    │──>│ UartNetToGuest()  │  │
    │  │                │   │ (into RX ring)    │  │
    │  └────────────────┘   └──────────────────┘  │
    │                                             │
    │  ┌────────────────┐   ┌──────────────────┐  │
    │  │ Socket send    │<──│ UartGuestToNet()  │  │
    │  │                │   │ (from TX ring)    │  │
    │  └────────────────┘   └──────────────────┘  │
    │                                             │
    │  The BBS door calls INT 14h (FOSSIL).       │
    │  FOSSIL reads/writes the SAME UART rings.   │
    │  The relay never touches INT 14h.           │
    └─────────────────────────────────────────────┘
  =========================================================================== }

{$MODE OBJFPC}{$H+}

unit NM_DirectRelay;

interface

uses
  SysUtils, NM_UART16550, NM_Debug
  {$IFDEF HAS_SYNAPSE}, blcksock{$ENDIF};

type
  { TDirectRelay — one per node. Owns a UART instance and a socket.
    Pump() moves bytes both directions without FOSSIL overhead. }
  TDirectRelay = class
  private
    FUart: TUart16550;
    {$IFDEF HAS_SYNAPSE}
    FSock: TTCPBlockSocket;
    {$ENDIF}
    FConnected: Boolean;
    FNodeIndex: Integer;
    FBytesIn: LongInt;
    FBytesOut: LongInt;
  public
    constructor Create(ANodeIndex: Integer);
    destructor Destroy; override;

    { Attach an accepted socket to this relay }
    procedure AttachSocket({$IFDEF HAS_SYNAPSE}ASock: TTCPBlockSocket{$ENDIF});

    { Detach and close the socket }
    procedure Detach;

    { Pump data both directions. Call this in the server's idle loop.
      Returns the number of bytes moved (both directions combined). }
    function Pump: Integer;

    { Set carrier detect (DCD) in the emulated UART }
    procedure SetCarrier(AOnline: Boolean);

    { Set RING indicator }
    procedure SetRing(ARinging: Boolean);

    { Direct register access — for FOSSIL to read/write the same UART }
    function ReadReg(Offset: Byte): Byte;
    procedure WriteReg(Offset: Byte; Value: Byte);

    { Feed a byte from the network into the UART's RX ring.
      Returns False if the ring is full (back-pressure). }
    function FeedByte(B: Byte): Boolean;

    { Pull a byte from the UART's TX ring (guest wrote it).
      Returns False if the ring is empty. }
    function DrainByte(out B: Byte): Boolean;

    property Connected: Boolean read FConnected;
    property NodeIndex: Integer read FNodeIndex;
    property BytesIn: LongInt read FBytesIn;
    property BytesOut: LongInt read FBytesOut;
    property Uart: TUart16550 read FUart write FUart;
  end;

  { TRelayManager — manages N direct relays }
  TRelayManager = class
  private
    FRelays: array of TDirectRelay;
    FCount: Integer;
  public
    constructor Create(AMaxNodes: Integer);
    destructor Destroy; override;

    { Get relay by index }
    function GetRelay(Index: Integer): TDirectRelay;

    { Pump all active relays. Returns total bytes moved. }
    function PumpAll: Integer;

    property Count: Integer read FCount;
  end;

implementation

{ === TDirectRelay === }

constructor TDirectRelay.Create(ANodeIndex: Integer);
begin
  inherited Create;
  FNodeIndex := ANodeIndex;
  FConnected := False;
  FBytesIn := 0;
  FBytesOut := 0;
  UartReset(FUart);
  DebugLog('Relay', 'Node ' + IntToStr(ANodeIndex) + ' created');
end;

destructor TDirectRelay.Destroy;
begin
  Detach;
  inherited;
end;

procedure TDirectRelay.AttachSocket({$IFDEF HAS_SYNAPSE}ASock: TTCPBlockSocket{$ENDIF});
begin
  {$IFDEF HAS_SYNAPSE}
  FSock := ASock;
  {$ENDIF}
  FConnected := True;
  FBytesIn := 0;
  FBytesOut := 0;
  UartReset(FUart);
  UartSetCarrier(FUart, True);   { DCD on — caller connected }
  DebugLog('Relay', 'Node ' + IntToStr(FNodeIndex) + ' attached, DCD on');
end;

procedure TDirectRelay.Detach;
begin
  if FConnected then
  begin
    UartSetCarrier(FUart, False);   { DCD off — caller gone }
    {$IFDEF HAS_SYNAPSE}
    if Assigned(FSock) then
    begin
      FSock.CloseSocket;
      FSock := nil;
    end;
    {$ENDIF}
    FConnected := False;
    DebugLog('Relay', 'Node ' + IntToStr(FNodeIndex) +
             ' detached. In=' + IntToStr(FBytesIn) +
             ' Out=' + IntToStr(FBytesOut));
  end;
end;

function TDirectRelay.Pump: Integer;
var
  B: Byte;
  Moved: Integer;
  {$IFDEF HAS_SYNAPSE}
  RawBuf: array[0..511] of Byte;
  Got, I: Integer;
  {$ENDIF}
begin
  Result := 0;
  if not FConnected then Exit;
  Moved := 0;

  {$IFDEF HAS_SYNAPSE}
  { === Network → UART (caller sending to BBS) === }
  if Assigned(FSock) and FSock.CanRead(0) then
  begin
    Got := FSock.RecvBuffer(@RawBuf, SizeOf(RawBuf));
    if Got <= 0 then
    begin
      { Connection lost }
      DebugLog('Relay', 'Node ' + IntToStr(FNodeIndex) +
               ' connection lost');
      Detach;
      Exit;
    end;
    for I := 0 to Got - 1 do
    begin
      { Direct UART feed — no FOSSIL dispatch, no function switching }
      if UartNetToGuest(FUart, RawBuf[I]) then
      begin
        Inc(FBytesIn);
        Inc(Moved);
      end;
      { else: RX ring full — back-pressure. Byte is lost.
        In practice the ring is 4KB so this rarely happens. }
    end;
  end;

  { === UART → Network (BBS sending to caller) === }
  while UartGuestToNet(FUart, B) do
  begin
    if Assigned(FSock) then
      FSock.SendBuffer(@B, 1);
    Inc(FBytesOut);
    Inc(Moved);
  end;
  {$ENDIF}

  Result := Moved;
end;

procedure TDirectRelay.SetCarrier(AOnline: Boolean);
begin
  UartSetCarrier(FUart, AOnline);
end;

procedure TDirectRelay.SetRing(ARinging: Boolean);
begin
  UartSetRing(FUart, ARinging);
end;

function TDirectRelay.ReadReg(Offset: Byte): Byte;
begin
  Result := UartReadReg(FUart, Offset);
end;

procedure TDirectRelay.WriteReg(Offset: Byte; Value: Byte);
begin
  UartWriteReg(FUart, Offset, Value);
end;

function TDirectRelay.FeedByte(B: Byte): Boolean;
begin
  Result := UartNetToGuest(FUart, B);
  if Result then Inc(FBytesIn);
end;

function TDirectRelay.DrainByte(out B: Byte): Boolean;
begin
  Result := UartGuestToNet(FUart, B);
  if Result then Inc(FBytesOut);
end;

{ === TRelayManager === }

constructor TRelayManager.Create(AMaxNodes: Integer);
var I: Integer;
begin
  inherited Create;
  FCount := AMaxNodes;
  SetLength(FRelays, AMaxNodes);
  for I := 0 to AMaxNodes - 1 do
    FRelays[I] := TDirectRelay.Create(I);
  DebugLog('Relay', 'RelayManager created, ' + IntToStr(AMaxNodes) + ' nodes');
end;

destructor TRelayManager.Destroy;
var I: Integer;
begin
  for I := 0 to FCount - 1 do
    FRelays[I].Free;
  SetLength(FRelays, 0);
  inherited;
end;

function TRelayManager.GetRelay(Index: Integer): TDirectRelay;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := FRelays[Index]
  else
    Result := nil;
end;

function TRelayManager.PumpAll: Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to FCount - 1 do
    if FRelays[I].Connected then
      Inc(Result, FRelays[I].Pump);
end;

end.
