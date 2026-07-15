program test_synapse_tail;
{$MODE OBJFPC}{$H+}
{ The partial-send tail buffer LOGIC (the fix for the silent-byte-loss bug),
  tested WITHOUT Synapse via the NM_SOCKET_TEST accessors. Proves: order
  preserved across queue+drain, the cap enforces back-pressure (no unbounded
  growth), and no bytes are lost or reordered. }
uses SysUtils, NetTransport, NM_SynapseLink;
var
  link: TSynapseLink; pass,fail,i,n: Integer;
  data: array[0..9] of Byte;
  big: array[0..70000] of Byte;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;
  link := TSynapseLink.Create;

  writeln('== queue a partial-send remainder, order preserved ==');
  for i:=0 to 9 do data[i]:=Ord('A')+i;   // A..J
  n := link.TestTailQueue(data[0], 10);
  Check(n=10, 'queued all 10 bytes');
  Check(link.PendingTail=10, 'PendingTail = 10');
  Check((link.TestTailByte(0)=Ord('A')) and (link.TestTailByte(9)=Ord('J')), 'bytes in order A..J');

  writeln('== simulate socket accepting 4 bytes on flush -> front dropped, rest kept in order ==');
  link.TestTailDrainFront(4);   // A B C D leave
  Check(link.PendingTail=6, '6 bytes remain');
  Check(link.TestTailByte(0)=Ord('E'), 'front is now E (order preserved)');
  Check(link.TestTailByte(5)=Ord('J'), 'tail is still J');

  writeln('== drain the rest -> empty ==');
  link.TestTailDrainFront(6);
  Check(link.PendingTail=0, 'tail fully drained, empty');

  writeln('== CAP / back-pressure: cannot queue beyond NM_SEND_TAIL_MAX ==');
  for i:=0 to High(big) do big[i]:=Byte(i and $FF);
  n := link.TestTailQueue(big[0], Length(big));   // 70001 bytes, cap is 65536
  Check(n=65536, 'queued exactly the cap (65536), not all 70001');
  Check(link.PendingTail=65536, 'tail held at the cap');
  { queue more -> should accept 0 (full) }
  n := link.TestTailQueue(data[0], 10);
  Check(n=0, 'further queue rejected (0) — back-pressure, no unbounded growth');

  writeln('== drained data integrity at the cap boundary ==');
  Check(link.TestTailByte(0)=Byte(0), 'first capped byte correct');
  Check(link.TestTailByte(65535)=Byte(65535 and $FF), 'last capped byte correct');

  link.Free;
  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('SYNAPSE TAIL BUFFER LOGIC - VERIFIED');
end.
