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
  TSeamMsg = (
    smData      = 0,   // payload = data bytes for/from the node's wire
    smConnect   = 1,   // control: a caller connected (server->driver: RING)
    smDisconnect= 2,   // control: hang up / carrier lost
    smCarrierUp = 3,   // control: carrier raised
    smCarrierDn = 4,   // control: carrier dropped
    smBreak     = 5,   // control: send/received BREAK
    smKeepAlive = 6    // no-op heartbeat
  );

  { A parsed frame. }
  TSeamFrame = record
    Msg     : TSeamMsg;
    Node    : Byte;
    Payload : array of Byte;
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
    function NextFrame(out F: TSeamFrame): Boolean;
    procedure Reset;
  end;

{ Build a frame into a byte buffer (returns the total length written).
  Dest must have room for 6 + PayloadLen bytes. }
function BuildFrame(Msg: TSeamMsg; Node: Byte;
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

function BuildFrame(Msg: TSeamMsg; Node: Byte;
                    const Payload; PayloadLen: Integer;
                    var Dest): Integer;
var
  d: PByte;
  p: PByte;
  i: Integer;
  chk: Byte;
begin
  d := @Dest;
  p := @Payload;
  d[0] := SEAM_SYNC;
  d[1] := Byte(Ord(Msg));
  d[2] := Node;
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

function TSeamParser.NextFrame(out F: TSeamFrame): Boolean;
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
    Result := NextFrame(F);
    Exit;
  end;

  { good frame — build the result }
  F.Msg  := TSeamMsg(FBuf[1]);
  F.Node := FBuf[2];
  SetLength(F.Payload, len);
  for i := 0 to len - 1 do
    F.Payload[i] := FBuf[5 + i];

  Drop(need);
  Result := True;
end;

end.
