unit NM_SeamSender;
{ ===========================================================================
  netmodem2irc — driver-side seam SENDER (the TSR's outbound half)
  ---------------------------------------------------------------------------
  The symmetric partner of the server's TServerBridge.FeedDriverBytes.

  The server RECEIVES seam frames (parses raw bytes -> frames -> node ops).
  This unit is the DRIVER side that SENDS them: it wraps the FOSSIL TSR's
  activity (data the DOS program wrote, plus control events like connect /
  hangup / break) into NM_SeamProtocol frames and hands them to a byte sink
  (the pipe/socket to the server).

  DESIGN: target-independent. The framing/sink logic is identical whether the
  DOS side is a real 16-bit TSR or a host test. It emits bytes through a
  callback sink, so it has NO dependency on any particular transport — the real
  TSR plugs in its pipe/socket write; a test plugs in a buffer. So it is built
  and TESTED on the host now; the i8086 TSR reuses it unchanged.

  Pairing (the full driver<->server loop):
    DRIVER:  NM_SeamSender  -- frames -->  (pipe/socket)  -->  SERVER: FeedDriverBytes
    SERVER:  (node output)  -- frames -->  (pipe/socket)  -->  DRIVER: (RX to guest)
  This unit is the driver's outbound direction.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  NM_SeamProtocol;

type
  { A byte sink: where outbound frame bytes go. The real TSR points this at its
    pipe/socket write; a test points it at a buffer. Returns bytes actually
    accepted (for flow control / partial writes). }
  TByteSink = function(const Buf; Len: Integer): Integer of object;

  { Wraps driver activity into seam frames and pushes them to a sink. One per
    driver instance; NodeIndex identifies which comport/node this driver serves. }
  TSeamSender = class
  private
    FSink : TByteSink;
    FNode : Byte;
    function EmitFrame(Msg: TSeamMsg; const Payload; PayloadLen: Integer): Boolean;
  public
    constructor Create(ASink: TByteSink; ANodeIndex: Byte);

    { data the DOS program wrote (guest -> wire): send as an smData frame. }
    function SendData(const Buf; Len: Integer): Boolean;
    { a single byte convenience. }
    function SendByte(B: Byte): Boolean;

    { control events the driver reports to the server: }
    function SendConnect: Boolean;      { a caller connected / driver opened }
    function SendDisconnect: Boolean;   { hangup / DTR dropped }
    function SendBreak: Boolean;        { BREAK signaled }
    function SendKeepAlive: Boolean;    { heartbeat }

    property NodeIndex: Byte read FNode write FNode;
  end;

implementation

constructor TSeamSender.Create(ASink: TByteSink; ANodeIndex: Byte);
begin
  inherited Create;
  FSink := ASink;
  FNode := ANodeIndex;
end;

function TSeamSender.EmitFrame(Msg: TSeamMsg; const Payload; PayloadLen: Integer): Boolean;
var
  buf: array[0..2047] of Byte;   { max frame = 6 + payload; cap payload chunks }
  n, sent: Integer;
begin
  Result := False;
  if PayloadLen > 2040 then PayloadLen := 2040;   { chunk guard; caller re-sends rest }
  n := BuildFrame(Msg, FNode, Payload, PayloadLen, buf[0]);
  if not Assigned(FSink) then Exit;
  sent := FSink(buf[0], n);
  Result := (sent = n);   { True only if the whole frame went out }
end;

function TSeamSender.SendData(const Buf; Len: Integer): Boolean;
var
  p: PByte;
  chunk: Integer;
begin
  Result := True;
  if Len <= 0 then Exit;
  p := @Buf;
  { split large writes into frame-sized chunks (each a valid smData frame) }
  while Len > 0 do
  begin
    chunk := Len;
    if chunk > 2040 then chunk := 2040;
    if not EmitFrame(smData, p^, chunk) then
    begin
      Result := False;
      Exit;
    end;
    Inc(p, chunk);
    Dec(Len, chunk);
  end;
end;

function TSeamSender.SendByte(B: Byte): Boolean;
begin
  Result := EmitFrame(smData, B, 1);
end;

function TSeamSender.SendConnect: Boolean;
var dummy: Byte;
begin
  dummy := 0;
  Result := EmitFrame(smConnect, dummy, 0);
end;

function TSeamSender.SendDisconnect: Boolean;
var dummy: Byte;
begin
  dummy := 0;
  Result := EmitFrame(smDisconnect, dummy, 0);
end;

function TSeamSender.SendBreak: Boolean;
var dummy: Byte;
begin
  dummy := 0;
  Result := EmitFrame(smBreak, dummy, 0);
end;

function TSeamSender.SendKeepAlive: Boolean;
var dummy: Byte;
begin
  dummy := 0;
  Result := EmitFrame(smKeepAlive, dummy, 0);
end;

end.
