unit NM_SeamProtocol;
{ ===========================================================================
  netmodem2irc — driver <-> server seam protocol
  ---------------------------------------------------------------------------
  The tiny framed protocol the DOS FOSSIL TSR and the Windows server speak over
  their pipe/socket link. It carries three things per frame:
     1. node identity  (which comport/node the frame is for)
     2. data bytes     (both directions — MUST be binary-clean, 0x00..0xFF)
     3. control        (carrier up/down, hangup, break)

  This sits ABOVE the transport (ISocketLink / NamedPipeLink) and is completely
  target-independent — the framing/parse logic is identical whether the DOS side
  is a 16-bit TSR or a test harness. So it is built and TESTED on the host now;
  when the i8086 TSR exists, it uses this exact framing unchanged.

  FRAME FORMAT (length-prefixed, binary-clean — no escaping needed):
     byte 0      : SYNC  = $A5           (frame start marker)
     byte 1      : TYPE  (TSeamMsg)
     byte 2      : NODE  (0..NM_MAX_NODES-1)
     byte 3..4   : LEN   (payload length, little-endian Word)
     byte 5..    : PAYLOAD (LEN bytes, arbitrary/binary)
     last byte   : CHECK = XOR of bytes 1..(5+LEN-1)   (integrity)

  Length-prefixing (not delimiter-based) is what makes it binary-clean: the
  payload can contain ANY byte value including $A5, because we read exactly LEN
  bytes rather than scanning for a terminator. This is the seam equivalent of the
  transport's IAC-doubling: 8-bit-clean by construction.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

const
  SEAM_SYNC = $A5;

type
  { message types on the seam }
  { TSeamMsg — the TYPE of a seam frame (what the frame means).
    A seam frame is one message between the FOSSIL driver and the server. Exactly
    ONE type below is a DATA frame (carries a payload); the rest are CONTROL
    signals (no payload, they just report an event on the line).

      smData      DATA. Payload = actual bytes flowing to/from the node's wire —
                  characters the DOS program wrote, or bytes arriving from the
                  remote. This is the ONLY type with a payload. All traffic rides
                  in smData frames.
      smConnect   CONTROL. A caller connected on this node. Server->driver this
                  becomes a RING the BBS answers; driver->server it starts the
                  node's inbound lifecycle.
      smDisconnect CONTROL. Hang up / carrier lost on this node -> close it.
      smCarrierUp  CONTROL. Carrier detect raised (line went online).
      smCarrierDn  CONTROL. Carrier detect dropped (line went offline).
      smBreak      CONTROL. A serial BREAK was sent/received on this node.
      smKeepAlive  CONTROL. Heartbeat / no-op — keeps an idle link alive. }
  TSeamMsg = (
    smData      = 0,   // DATA: payload = bytes for/from the node's wire
    smConnect   = 1,   // control: a caller connected (server->driver: RING)
    smDisconnect= 2,   // control: hang up / carrier lost
    smCarrierUp = 3,   // control: carrier raised
    smCarrierDn = 4,   // control: carrier dropped
    smBreak     = 5,   // control: send/received BREAK
    smKeepAlive = 6    // no-op heartbeat
  );

  { A parsed seam frame — one decoded message.
      Msg     : which kind of message (see TSeamMsg). Tells you whether Payload
                is meaningful (smData) or the frame is a control signal.
      NodeIndex : WHICH comport/node this frame is addressed to — the address.
                Valid range
                is 0 .. NM_MAX_NODES-1 (0..98). A multinode server runs up to 99
                lines; every frame names its line here so the server knows which
                node's wire to route to (switch-style addressing: the frame
                carries its own destination).
                NOTE: NodeIndex is a Byte (0..255), which can exceed NM_MAX_NODES,
                so
                consumers MUST range-check it before using it as an index (the
                value came off the wire and is not trusted). See NodeByIndex.
      Payload : the data bytes, only meaningful when Msg = smData; empty otherwise.
                Length is carried by the frame's LEN field (16-bit, 0..65535). }
  TSeamFrame = record
    Msg       : TSeamMsg;   // which kind of message (data or a control signal)
    NodeIndex : Byte;       // WHICH comport/node this message is addressed to (0..98)
    Payload   : array of Byte;  // the bytes, meaningful only when Msg = smData
  end;

  { Incremental parser — feed it bytes as they arrive; it emits complete frames.
    Handles partial/split reads (pipe/socket data arrives in arbitrary chunks). }
  TSeamParser = class
  private
    FBuf   : array of Byte;   // accumulation buffer
    procedure Drop(n: Integer);
  public
    { Feed raw bytes from the link. }
    procedure Feed(const Buf; Len: Integer);
    { Try to extract one complete frame. Returns True + fills F if one is ready. }
    function NextFrame(out Frame: TSeamFrame): Boolean;
    procedure Reset;
  end;

{ Build a frame into a byte buffer (returns the total length written).
  Dest must have room for 6 + PayloadLen bytes. }
function BuildFrame(Msg: TSeamMsg; NodeIndex: Byte;
                    const Payload; PayloadLen: Integer;
                    var Dest): Integer;

{ Convenience: compute the frame size for a given payload length. }
function FrameSize(PayloadLen: Integer): Integer;

implementation

function FrameSize(PayloadLen: Integer): Integer;
begin
  { SYNC + TYPE + NODE + LEN(2) + payload + CHECK }
  Result := 6 + PayloadLen;
end;

function BuildFrame(Msg: TSeamMsg; NodeIndex: Byte;
                    const Payload; PayloadLen: Integer;
                    var Dest): Integer;
var
  d: PByte;
  p: PByte;
  i: Integer;
  chk: Byte;
begin
  { GUARD (qwkpoll lesson): LEN is a 16-bit field on the wire. If PayloadLen
    exceeds what 16 bits can hold, encoding it would truncate LEN while copying
    the full payload -> writer/reader desync (silent corruption past the boundary).
    Refuse instead of corrupting. Callers chunk large data (see NM_SeamSender). }
  if (PayloadLen < 0) or (PayloadLen > $FFFF) then
  begin
    Result := 0;      { invalid: caller must chunk to <= 65535 }
    Exit;
  end;
  d := @Dest;
  p := @Payload;
  d[0] := SEAM_SYNC;
  d[1] := Byte(Ord(Msg));
  d[2] := NodeIndex;   // address: which node this frame is for
  d[3] := Byte(PayloadLen and $FF);
  d[4] := Byte((PayloadLen shr 8) and $FF);
  for i := 0 to PayloadLen - 1 do
    d[5 + i] := p[i];
  { checksum = XOR of TYPE..last payload byte }
  chk := 0;
  for i := 1 to 4 + PayloadLen do
    chk := chk xor d[i];
  d[5 + PayloadLen] := chk;
  Result := 6 + PayloadLen;
end;

{ ---------------- TSeamParser ---------------- }

procedure TSeamParser.Reset;
begin
  SetLength(FBuf, 0);
end;

procedure TSeamParser.Feed(const Buf; Len: Integer);
var
  p: PByte;
  i, base: Integer;
begin
  if Len <= 0 then Exit;
  p := @Buf;
  base := Length(FBuf);
  SetLength(FBuf, base + Len);
  for i := 0 to Len - 1 do
    FBuf[base + i] := p[i];
end;

procedure TSeamParser.Drop(n: Integer);
var
  i, remain: Integer;
begin
  remain := Length(FBuf) - n;
  if remain <= 0 then
  begin
    SetLength(FBuf, 0);
    Exit;
  end;
  for i := 0 to remain - 1 do
    FBuf[i] := FBuf[i + n];
  SetLength(FBuf, remain);
end;

function TSeamParser.NextFrame(out Frame: TSeamFrame): Boolean;
var
  len, need, i: Integer;
  chk: Byte;
begin
  Result := False;

  { discard bytes until a SYNC (resync on garbage) }
  while (Length(FBuf) > 0) and (FBuf[0] <> SEAM_SYNC) do
    Drop(1);

  { need at least the header (SYNC+TYPE+NODE+LEN2) = 5 bytes }
  if Length(FBuf) < 5 then Exit;

  len  := FBuf[3] or (FBuf[4] shl 8);
  need := 6 + len;                 // full frame incl checksum
  if Length(FBuf) < need then Exit; // wait for more bytes (partial frame)

  { verify checksum }
  chk := 0;
  for i := 1 to 4 + len do
    chk := chk xor FBuf[i];
  if chk <> FBuf[5 + len] then
  begin
    { bad frame — drop the SYNC and resync }
    Drop(1);
    { try again recursively on the remaining buffer }
    Result := NextFrame(Frame);
    Exit;
  end;

  { good frame — build the result }
  Frame.Msg       := TSeamMsg(FBuf[1]);
  Frame.NodeIndex := FBuf[2];               // the address that came off the wire
  SetLength(Frame.Payload, len);
  for i := 0 to len - 1 do
    Frame.Payload[i] := FBuf[5 + i];

  Drop(need);
  Result := True;
end;

end.
