program test_seam_boundary_roundtrip;
{$MODE OBJFPC}{$H+}
{ Applying the Mystic maintainer's testing ladder to the seam LEN field:
  L1 boundary sizes, L3 INDEPENDENT oracle, L5 write->read->assert-equal.
  We test the NUMBER (the length at its 16-bit boundary), not "the megabytes". }
uses SysUtils, NM_SeamProtocol;
var pass,fail: Integer;
    d2, s2: array of Byte;

{ L3: an INDEPENDENT oracle for frame size — derived a DIFFERENT way than the
  unit's FrameSize(), so a shared bug can't hide. Frame = SYNC+TYPE+NODE+LEN(2)
  +payload+CHECK = payload + 6. Written here as (payload + 6) directly, and we do
  NOT call the unit's FrameSize to get it. }
function OracleFrameSize(payloadLen: Integer): Integer;
begin
  OracleFrameSize := payloadLen + 6;
end;

procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;

{ L5: write a payload of size N, parse it back, assert byte-for-byte equal and
  correct frame size (vs the independent oracle). Returns True if the round trip
  is perfect. sizeN is the payload length to exercise. }
function RoundTrip(sizeN: Integer): Boolean;
var
  src, dest: array of Byte;
  parser: TSeamParser;
  fr: TSeamFrame;
  n, i: Integer;
  ok: Boolean;
begin
  RoundTrip := False;
  SetLength(src, sizeN);
  for i := 0 to sizeN-1 do src[i] := Byte((i * 7 + 13) and $FF);  { varied pattern }
  SetLength(dest, sizeN + 16);
  if sizeN = 0 then
    n := BuildFrame(smData, 3, src, 0, dest[0])
  else
    n := BuildFrame(smData, 3, src[0], sizeN, dest[0]);
  { L3: assert size against the INDEPENDENT oracle }
  if n <> OracleFrameSize(sizeN) then Exit;
  parser := TSeamParser.Create;
  try
    parser.Feed(dest[0], n);
    if not parser.NextFrame(fr) then Exit;
    if Length(fr.Payload) <> sizeN then Exit;
    ok := True;
    for i := 0 to sizeN-1 do
      if fr.Payload[i] <> src[i] then begin ok := False; Break; end;
    RoundTrip := ok;
  finally
    parser.Free;
  end;
end;

begin
  pass:=0;fail:=0;
  writeln('== L1+L5: round-trip at sizes BELOW / AT / of the 16-bit LEN boundary ==');
  Check(RoundTrip(0),      'empty payload round-trips (byte-exact, size ok)');
  Check(RoundTrip(1),      '1 byte');
  Check(RoundTrip(127),    '127 (just under a block)');
  Check(RoundTrip(128),    '128 (one block)');
  Check(RoundTrip(255),    '255 (Byte boundary - old ghost hiding spot)');
  Check(RoundTrip(256),    '256 (just past Byte)');
  Check(RoundTrip(65408),  '65408 (just below Word max)');
  Check(RoundTrip(65535),  '65535 (AT the 16-bit LEN max - the boundary!)');

  writeln('== L3 sanity: the oracle and the unit agree at a normal size ==');
  Check(OracleFrameSize(100) = FrameSize(100), 'independent oracle matches unit FrameSize (both right)');

  writeln('== past the boundary is refused (no silent truncation) ==');
  SetLength(s2, 65536); SetLength(d2, 65536+16);
  Check(BuildFrame(smData, 3, s2[0], 65536, d2[0]) = 0, '65536 refused (guard holds under round-trip harness)');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('SEAM BOUNDARY ROUND-TRIP - VERIFIED');
end.
