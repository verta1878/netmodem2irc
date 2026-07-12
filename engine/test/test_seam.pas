program test_seam;
{$MODE OBJFPC}{$H+}
uses SysUtils, NM_SeamProtocol;
var
  parser: TSeamParser; f: TSeamFrame;
  buf: array[0..1023] of Byte;
  payload: array[0..511] of Byte;
  n, i, got: Integer;
  pass, fail: Integer;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;

begin
  pass:=0;fail:=0;
  parser := TSeamParser.Create;

  writeln('== build + parse a simple data frame ==');
  payload[0]:=Ord('H'); payload[1]:=Ord('i');
  n := BuildFrame(smData, 3, payload[0], 2, buf[0]);
  Check(n = FrameSize(2), 'frame size correct');
  parser.Feed(buf[0], n);
  Check(parser.NextFrame(f), 'frame parsed');
  Check((f.Msg = smData) and (f.NodeIndex = 3) and (Length(f.Payload)=2), 'header correct');
  Check((f.Payload[0]=Ord('H')) and (f.Payload[1]=Ord('i')), 'payload correct');

  writeln('== BINARY SAFETY: payload with all 256 byte values incl SYNC ($A5) ==');
  for i:=0 to 255 do payload[i]:=Byte(i);
  n := BuildFrame(smData, 5, payload[0], 256, buf[0]);
  parser.Feed(buf[0], n);
  Check(parser.NextFrame(f), '256-byte binary frame parsed');
  Check(Length(f.Payload)=256, 'all 256 bytes present');
  got:=0; for i:=0 to 255 do if f.Payload[i]=Byte(i) then Inc(got);
  Check(got=256, 'all 256 byte values round-trip clean (incl $A5 SYNC in payload)');

  writeln('== SPLIT READS: feed a frame one byte at a time ==');
  payload[0]:=$A5; payload[1]:=$A5; payload[2]:=$00; payload[3]:=$FF; // nasty payload
  n := BuildFrame(smData, 7, payload[0], 4, buf[0]);
  for i:=0 to n-1 do parser.Feed(buf[i], 1);   // one byte at a time
  Check(parser.NextFrame(f), 'frame reassembled from single-byte feeds');
  Check((Length(f.Payload)=4) and (f.Payload[0]=$A5) and (f.Payload[3]=$FF),
        'split-read payload correct (SYNC bytes in payload survived)');

  writeln('== TWO frames back-to-back in one feed ==');
  n := BuildFrame(smConnect, 1, payload[0], 0, buf[0]);
  n := n + BuildFrame(smData, 2, payload[0], 3, buf[n]);
  parser.Feed(buf[0], n);
  Check(parser.NextFrame(f) and (f.Msg=smConnect) and (f.NodeIndex=1), 'first frame (connect)');
  Check(parser.NextFrame(f) and (f.Msg=smData) and (f.NodeIndex=2), 'second frame (data)');
  Check(not parser.NextFrame(f), 'no third frame');

  writeln('== RESYNC: garbage before a valid frame ==');
  parser.Reset;
  buf[0]:=$11; buf[1]:=$22; buf[2]:=$33;   // garbage
  parser.Feed(buf[0], 3);
  n := BuildFrame(smData, 9, payload[0], 2, buf[0]);
  parser.Feed(buf[0], n);
  Check(parser.NextFrame(f) and (f.NodeIndex=9), 'resynced past garbage to valid frame');

  writeln('== control frames (carrier/hangup/break) ==');
  n := BuildFrame(smCarrierUp, 4, payload[0], 0, buf[0]);
  parser.Feed(buf[0], n);
  Check(parser.NextFrame(f) and (f.Msg=smCarrierUp) and (Length(f.Payload)=0),
        'zero-payload control frame parses');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('SEAM PROTOCOL VERIFIED');
end.
