program test_seam_overflow;
{$MODE OBJFPC}{$H+}
{ qwkpoll lesson applied: test the seam LEN field PAST its 16-bit boundary, not
  just the sizes that work today. Prove the writer can't silently truncate LEN and
  desync the reader. }
uses SysUtils, NM_SeamProtocol;
var
  pass,fail: Integer;
  big: array of Byte;
  small: array[0..9] of Byte;
  dest: array of Byte;
  n, i: Integer;
  parser: TSeamParser;
  fr: TSeamFrame;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;

  writeln('== at the boundary: exactly 65535 payload encodes OK ==');
  SetLength(big, 65535);
  for i:=0 to High(big) do big[i] := Byte(i and $FF);
  SetLength(dest, 6 + 65535);
  n := BuildFrame(smData, 5, big[0], 65535, dest[0]);
  Check(n = 6 + 65535, '65535-byte payload builds a full frame');

  writeln('== PAST the boundary: 65536 payload is REFUSED, not truncated ==');
  SetLength(big, 65536);
  SetLength(dest, 6 + 65536);
  n := BuildFrame(smData, 5, big[0], 65536, dest[0]);
  Check(n = 0, '65536-byte payload refused (returns 0, no silent truncation)');

  writeln('== PAST the boundary: 100000 payload also refused ==');
  SetLength(big, 100000);
  SetLength(dest, 6 + 100000);
  n := BuildFrame(smData, 5, big[0], 100000, dest[0]);
  Check(n = 0, '100000-byte payload refused');

  writeln('== negative length refused (defensive) ==');
  n := BuildFrame(smData, 5, small[0], -1, dest[0]);
  Check(n = 0, 'negative PayloadLen refused');

  writeln('== round-trip still correct for a normal frame (no regression) ==');
  small[0]:=$A5; small[1]:=$00; small[2]:=$FF; small[3]:=Ord('Z');
  SetLength(dest, 32);
  n := BuildFrame(smData, 7, small[0], 4, dest[0]);
  parser := TSeamParser.Create;
  parser.Feed(dest[0], n);
  Check(parser.NextFrame(fr), 'normal frame parses back');
  Check((fr.NodeIndex=7) and (Length(fr.Payload)=4) and (fr.Payload[0]=$A5), 'payload intact incl $A5');
  parser.Free;

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('SEAM LEN OVERFLOW GUARDED - VERIFIED');
end.
