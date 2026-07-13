unit NetTransport;
{ ===========================================================================
  netmodem2irc — Telnet transport (NT-branch, user-mode)
  ---------------------------------------------------------------------------
  Bridges the emulated modem (NM_UART16550 / NM_Fossil) to a TCP/Telnet
  connection. This is the `server/NetTransport.pas` slot the revival's docs
  already specify (docs/BUILD.md, docs/GUI_BLUEPRINT.md):

     "add server/NetTransport.pas using Synapse (TTCPBlockSocket) ...
      wire it to CM_CONNECT_NODE; handle Telnet BINARY negotiation."

  Responsibilities:
    - Move bytes between the UART's TX ring (guest->net) and the socket.
    - Move bytes from the socket into the UART's RX ring (net->guest).
    - Handle the Telnet protocol layer: IAC command filtering + BINARY
      option negotiation, so raw 8-bit BBS data passes clean (CP437, Zmodem).
    - Drive carrier state: connected => carrier on (MSR DCD); closed => off.

  DESIGN — swappable socket:
    The Telnet/ring logic here is PURE and testable. The actual socket lives
    behind ISocketLink (Connect/Send/Recv/Close). A Synapse-backed link
    (TTCPBlockSocket) plugs in for Win32/real builds; a fake link is used in
    tests. This keeps the protocol logic verifiable without a live network,
    and lets the same code target WinSock (via Synapse) or fpc264irc sockets.

  Telnet reference: RFC 854 (IAC), RFC 856 (BINARY). BBS work REQUIRES binary
  mode so 8-bit data (box-drawing, Zmodem) is not mangled.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  NM_UART16550;

const
  { Telnet protocol bytes (RFC 854 / 856) }
  TELNET_IAC   = 255;   // Interpret As Command
  TELNET_DONT  = 254;
  TELNET_DO    = 253;
  TELNET_WONT  = 252;
  TELNET_WILL  = 251;
  TELNET_SB    = 250;   // subnegotiation begin
  TELNET_SE    = 240;   // subnegotiation end
  TELNET_OPT_BINARY = 0;   // RFC 856 BINARY transmission
  TELNET_OPT_SGA    = 3;   // suppress go-ahead
  TELNET_OPT_ECHO   = 1;

type
  { Result of a socket operation. }
  TLinkResult = (lrOk, lrWouldBlock, lrClosed, lrError);

  { Swappable socket interface. Synapse TTCPBlockSocket implements this for
    real builds; a fake implements it for tests. }
  ISocketLink = interface
    ['{7E3A1C40-0001-4E00-9A00-000000000001}']
    function Connect(const AHost: string; APort: Word): TLinkResult;
    { Send up to Length(Buf) bytes; returns count actually sent in Sent. }
    function Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
    { Receive up to Len bytes into Buf; returns count in Got. Non-blocking:
      lrWouldBlock + Got=0 means "nothing available right now". }
    function Recv(var Buf; Len: Integer; out Got: Integer): TLinkResult;
    procedure Close;
    function IsConnected: Boolean;
  end;

  { Telnet input parser state (for filtering IAC sequences out of the stream). }
  TTelnetState = (tsData, tsIAC, tsWill, tsWont, tsDo, tsDont, tsSB, tsSBIAC);

  { The transport for ONE node/port: binds a UART to a socket link. }
  TNetTransport = class
  private
    FUart : PUart16550;
    FLink : ISocketLink;
    FState: TTelnetState;
    FBinarySent: Boolean;      // we asked for BINARY
    FBinaryOK  : Boolean;      // remote agreed
    procedure SendRaw(const Buf; Len: Integer);
    procedure SendIAC(Cmd, Opt: Byte);
    procedure FeedByteToGuest(B: Byte);   // after Telnet filtering -> RX ring
  public
    constructor Create(AUart: PUart16550; ALink: ISocketLink);
    { Dial: open the socket, send initial Telnet BINARY negotiation, set carrier. }
    function Dial(const AHost: string; APort: Word): Boolean;
    { Pump once: drain UART TX -> socket, and socket -> UART RX (with Telnet
      filtering). Call this from the server's timer/loop. Returns false if the
      link closed (carrier dropped). }
    function Pump: Boolean;
    { Hang up. }
    procedure HangUp;
    { Proactively send Telnet BINARY negotiation (for inbound connections). }
    procedure NegotiateBinary;
    { Send a Telnet BREAK (IAC BRK) to the remote. }
    procedure SendBreak;
    property BinaryMode: Boolean read FBinaryOK;
  end;

implementation

constructor TNetTransport.Create(AUart: PUart16550; ALink: ISocketLink);
begin
  inherited Create;
  FUart := AUart;
  FLink := ALink;
  FState := tsData;
  FBinarySent := False;
  FBinaryOK := False;
end;

procedure TNetTransport.SendRaw(const Buf; Len: Integer);
var
  sent: Integer;
begin
  if (FLink <> nil) and (Len > 0) then
    FLink.Send(Buf, Len, sent);
end;

procedure TNetTransport.SendIAC(Cmd, Opt: Byte);
var
  seq: array[0..2] of Byte;
begin
  seq[0] := TELNET_IAC; seq[1] := Cmd; seq[2] := Opt;
  SendRaw(seq, 3);
end;

function TNetTransport.Dial(const AHost: string; APort: Word): Boolean;
begin
  Result := False;
  if FLink = nil then Exit;
  if FLink.Connect(AHost, APort) <> lrOk then Exit;
  { Request 8-bit clean path: WILL BINARY + DO BINARY + WILL SGA.
    BBS data (CP437, Zmodem) must not be altered — this is essential. }
  SendIAC(TELNET_WILL, TELNET_OPT_BINARY);
  SendIAC(TELNET_DO,   TELNET_OPT_BINARY);
  SendIAC(TELNET_WILL, TELNET_OPT_SGA);
  FBinarySent := True;
  UartSetCarrier(FUart^, True);   // carrier up => MSR DCD set => doors see connect
  Result := True;
end;

procedure TNetTransport.HangUp;
begin
  if FLink <> nil then FLink.Close;
  UartSetCarrier(FUart^, False);
  FBinaryOK := False;
  FState := tsData;
end;

{ A byte that survived Telnet filtering goes to the guest's RX ring. }
procedure TNetTransport.FeedByteToGuest(B: Byte);
begin
  UartNetToGuest(FUart^, B);
end;

function TNetTransport.Pump: Boolean;
var
  b: Byte;
  outbuf: array[0..1023] of Byte;
  n: Integer;
  inbuf: array[0..1023] of Byte;
  got, i: Integer;
  lr: TLinkResult;
  optByte: Byte;
begin
  Result := True;
  if (FLink = nil) or (not FLink.IsConnected) then
  begin
    UartSetCarrier(FUart^, False);
    Exit(False);
  end;

  { 1) guest -> net: drain UART TX ring to the socket.
       In Telnet BINARY, a literal 0xFF byte must be doubled (IAC IAC) so it
       isn't seen as a command. This protects 8-bit data. }
  n := 0;
  { BOUND SAFETY: one iteration can write TWO bytes (doubled IAC), so require room
    for both (n <= High(outbuf)-1) before writing. The old bound n < High(outbuf)
    only avoided overflow incidentally (one slot of slack); this makes it explicit. }
  while (n <= High(outbuf) - 1) and UartGuestToNet(FUart^, b) do
  begin
    outbuf[n] := b; Inc(n);
    if b = TELNET_IAC then
    begin
      { double the IAC — room guaranteed by the loop bound }
      outbuf[n] := TELNET_IAC; Inc(n);
    end;
  end;
  if n > 0 then SendRaw(outbuf, n);

  { 2) net -> guest: read from socket, run Telnet state machine, feed data
       bytes to the guest RX ring. Filter/answer IAC sequences. }
  lr := FLink.Recv(inbuf, SizeOf(inbuf), got);
  if lr = lrClosed then
  begin
    UartSetCarrier(FUart^, False);
    Exit(False);
  end;
  if (lr = lrOk) and (got > 0) then
  begin
    i := 0;
    while i < got do
    begin
      b := inbuf[i]; Inc(i);
      case FState of
        tsData:
          if b = TELNET_IAC then FState := tsIAC
          else FeedByteToGuest(b);
        tsIAC:
          case b of
            TELNET_IAC:  begin FeedByteToGuest(TELNET_IAC); FState := tsData; end; // escaped 0xFF
            TELNET_WILL: FState := tsWill;
            TELNET_WONT: FState := tsWont;
            TELNET_DO:   FState := tsDo;
            TELNET_DONT: FState := tsDont;
            TELNET_SB:   FState := tsSB;
          else
            FState := tsData;   // other 2-byte commands: swallow
          end;
        tsWill:
          begin
            optByte := b;
            if optByte = TELNET_OPT_BINARY then FBinaryOK := True;
            { we already requested; acknowledge DO for binary/sga }
            if (optByte = TELNET_OPT_BINARY) or (optByte = TELNET_OPT_SGA) then
              SendIAC(TELNET_DO, optByte)
            else
              SendIAC(TELNET_DONT, optByte);
            FState := tsData;
          end;
        tsWont:
          begin optByte := b; SendIAC(TELNET_DONT, optByte); FState := tsData; end;
        tsDo:
          begin
            optByte := b;
            if (optByte = TELNET_OPT_BINARY) or (optByte = TELNET_OPT_SGA) then
              SendIAC(TELNET_WILL, optByte)
            else
              SendIAC(TELNET_WONT, optByte);
            FState := tsData;
          end;
        tsDont:
          begin optByte := b; SendIAC(TELNET_WONT, optByte); FState := tsData; end;
        tsSB:
          if b = TELNET_IAC then FState := tsSBIAC;   // wait for IAC SE
        tsSBIAC:
          if b = TELNET_SE then FState := tsData
          else FState := tsSB;
      end;
    end;
  end;
end;

procedure TNetTransport.NegotiateBinary;
begin
  SendIAC(TELNET_WILL, TELNET_OPT_BINARY);
  SendIAC(TELNET_DO,   TELNET_OPT_BINARY);
  SendIAC(TELNET_WILL, TELNET_OPT_SGA);
  FBinarySent := True;
end;

const
  TELNET_BRK = 243;   // Telnet BREAK

procedure TNetTransport.SendBreak;
var seq: array[0..1] of Byte;
begin
  seq[0] := TELNET_IAC; seq[1] := TELNET_BRK;
  SendRaw(seq, 2);
end;

end.
