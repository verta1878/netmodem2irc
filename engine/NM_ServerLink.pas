unit NM_ServerLink;
{ ===========================================================================
  netmodem2irc — concrete TServerLink implementations
  ---------------------------------------------------------------------------
  The TSR (NM_TSR) talks to the server through a TServerLink (Send / Poll). Until
  now it was only exercised against a FAKE link in tests. This unit provides REAL
  implementations:

    TLoopbackServerLink  — an in-process byte-queue link. Whatever is Sent can be
                           read back via Poll (and vice-versa through a paired
                           endpoint). Fully host-testable NOW; lets the whole
                           driver<->server loop run against a real link object,
                           and is a genuine transport for same-process wiring.

    TSynapseServerLink   — a real TCP link over Ararat Synapse (blcksock), guarded
                           by {$IFDEF HAS_SYNAPSE}. This is the shape the i8086 TSR
                           will use to reach the server over a socket.

  Both honor the TServerLink contract: Send pushes bytes out, Poll pulls available
  bytes in (0 if none), non-blocking.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  NM_TSR
  {$IFDEF HAS_SYNAPSE}, blcksock, synsock{$ENDIF};

type
  { A simple growable byte queue (FIFO) used by the loopback link. Not a ring —
    a plain queue with a read cursor, compacted when drained, so it can hold
    arbitrary amounts without a fixed cap. }
  TByteQueue = class
  private
    FData : array of Byte;
    FHead : Integer;   // read cursor
  public
    constructor Create;
    procedure Push(const Buf; Len: Integer);
    function Pull(var Buf; MaxLen: Integer): Integer;   // returns bytes copied
    function Available: Integer;
    procedure Clear;
  end;

  { In-process loopback link. Two of these can be paired (A's out is B's in) to
    model a full duplex channel, or a single one used as an echo/testing link. }
  TLoopbackServerLink = class(TServerLink)
  private
    FOut : TByteQueue;   // bytes this side Sent (readable by the peer's Poll)
    FIn  : TByteQueue;   // bytes destined for this side's Poll
  public
    constructor Create;
    destructor Destroy; override;
    function Send(const Buf; Len: Integer): Integer; override;   // -> FOut
    function Poll(var Buf; MaxLen: Integer): Integer; override;  // <- FIn
    { pairing: wire this link's OUT to a peer's IN and vice-versa }
    procedure PairWith(APeer: TLoopbackServerLink);
    { direct injection for tests / same-process server: feed this side's Poll }
    procedure DeliverToPoll(const Buf; Len: Integer);
    { read what this side Sent (server-side of a same-process wiring) }
    function ReadSent(var Buf; MaxLen: Integer): Integer;
    property OutQueue: TByteQueue read FOut;
    property InQueue: TByteQueue read FIn;
  end;

{$IFDEF HAS_SYNAPSE}
  { Real TCP link to the server over Synapse. Non-blocking Poll. }
  TSynapseServerLink = class(TServerLink)
  private
    FSock : TTCPBlockSocket;
    FConnected : Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function ConnectTo(const AHost: string; APort: Word): Boolean;
    function Send(const Buf; Len: Integer): Integer; override;
    function Poll(var Buf; MaxLen: Integer): Integer; override;
    function IsConnected: Boolean;
    procedure Close;
  end;
{$ENDIF}

implementation

{ ---------------- TByteQueue ---------------- }

constructor TByteQueue.Create;
begin
  inherited Create;
  SetLength(FData, 0);
  FHead := 0;
end;

procedure TByteQueue.Push(const Buf; Len: Integer);
var p: PByte; i, base: Integer;
begin
  if Len <= 0 then Exit;
  p := @Buf;
  base := Length(FData);
  SetLength(FData, base + Len);
  for i := 0 to Len - 1 do
    FData[base + i] := p[i];
end;

function TByteQueue.Pull(var Buf; MaxLen: Integer): Integer;
var p: PByte; avail, n, i: Integer;
begin
  Result := 0;
  if MaxLen <= 0 then Exit;
  avail := Length(FData) - FHead;
  if avail <= 0 then
  begin
    { fully drained — compact back to empty }
    SetLength(FData, 0); FHead := 0;
    Exit;
  end;
  n := avail;
  if n > MaxLen then n := MaxLen;
  p := @Buf;
  for i := 0 to n - 1 do
    p[i] := FData[FHead + i];
  Inc(FHead, n);
  { compact when fully drained to keep memory bounded }
  if FHead >= Length(FData) then
  begin
    SetLength(FData, 0); FHead := 0;
  end;
  Result := n;
end;

function TByteQueue.Available: Integer;
begin
  Result := Length(FData) - FHead;
end;

procedure TByteQueue.Clear;
begin
  SetLength(FData, 0); FHead := 0;
end;

{ ---------------- TLoopbackServerLink ---------------- }

constructor TLoopbackServerLink.Create;
begin
  inherited Create;
  FOut := TByteQueue.Create;
  FIn  := TByteQueue.Create;
end;

destructor TLoopbackServerLink.Destroy;
begin
  FOut.Free;
  FIn.Free;
  inherited Destroy;
end;

function TLoopbackServerLink.Send(const Buf; Len: Integer): Integer;
begin
  FOut.Push(Buf, Len);
  Result := Len;
end;

function TLoopbackServerLink.Poll(var Buf; MaxLen: Integer): Integer;
begin
  Result := FIn.Pull(Buf, MaxLen);
end;

procedure TLoopbackServerLink.DeliverToPoll(const Buf; Len: Integer);
begin
  FIn.Push(Buf, Len);
end;

function TLoopbackServerLink.ReadSent(var Buf; MaxLen: Integer): Integer;
begin
  Result := FOut.Pull(Buf, MaxLen);
end;

procedure TLoopbackServerLink.PairWith(APeer: TLoopbackServerLink);
begin
  { A's OUT becomes B's IN and vice-versa: share the queue objects so a Send on one
    is Pollable on the other. We swap so both directions are wired. }
  if APeer = nil then Exit;
  { this.OUT <-> peer.IN }
  APeer.FIn.Free;
  APeer.FIn := FOut;
  { peer.OUT <-> this.IN }
  FIn.Free;
  FIn := APeer.FOut;
end;

{$IFDEF HAS_SYNAPSE}
{ ---------------- TSynapseServerLink ---------------- }

constructor TSynapseServerLink.Create;
begin
  inherited Create;
  FSock := TTCPBlockSocket.Create;
  FConnected := False;
end;

destructor TSynapseServerLink.Destroy;
begin
  Close;
  FSock.Free;
  inherited Destroy;
end;

function TSynapseServerLink.ConnectTo(const AHost: string; APort: Word): Boolean;
begin
  FSock.Connect(AHost, IntToStr(APort));
  FConnected := (FSock.LastError = 0);
  Result := FConnected;
end;

function TSynapseServerLink.Send(const Buf; Len: Integer): Integer;
begin
  Result := 0;
  if not FConnected then Exit;
  FSock.SendBuffer(@Buf, Len);
  if FSock.LastError = 0 then Result := Len
  else FConnected := False;
end;

function TSynapseServerLink.Poll(var Buf; MaxLen: Integer): Integer;
begin
  Result := 0;
  if not FConnected then Exit;
  { non-blocking: only read if data is waiting }
  if FSock.CanRead(0) then
  begin
    Result := FSock.RecvBufferEx(@Buf, MaxLen, 0);
    if FSock.LastError <> 0 then
    begin
      Result := 0;
      FConnected := False;
    end;
  end;
end;

function TSynapseServerLink.IsConnected: Boolean;
begin
  Result := FConnected;
end;

procedure TSynapseServerLink.Close;
begin
  if FConnected then FSock.CloseSocket;
  FConnected := False;
end;
{$ENDIF}

end.
