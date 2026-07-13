program test_serverlink;
{$MODE OBJFPC}{$H+}
{ Concrete TServerLink: run the TSR against a REAL TLoopbackServerLink (not a fake).
  Proves the whole driver<->server loop works with a concrete link object, and that
  the byte queue is correct (order preserved, partial reads, drain/compact). }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node,
     NM_SeamProtocol, NM_SeamSender, NM_TSR, NM_ServerLink;
var
  link: TLoopbackServerLink; tsr: TNetModemTSR; pass,fail,i,n: Integer;
  buf: array[0..255] of Byte; parser: TSeamParser; fr: TSeamFrame;
  sawConnect, sawData: Boolean;
  pl: array[0..1] of Byte;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;

  writeln('== TByteQueue: order preserved, partial read, drain ==');
  { indirectly via a standalone link }
  link := TLoopbackServerLink.Create;
  for i:=0 to 9 do buf[i]:=Ord('0')+i;
  link.OutQueue.Push(buf[0], 10);
  Check(link.OutQueue.Available=10, '10 bytes queued');
  n := link.OutQueue.Pull(buf[0], 4);
  Check((n=4) and (buf[0]=Ord('0')) and (buf[3]=Ord('3')), 'partial pull 4 in order');
  Check(link.OutQueue.Available=6, '6 remain after partial pull');
  n := link.OutQueue.Pull(buf[0], 100);
  Check((n=6) and (buf[0]=Ord('4')) and (buf[5]=Ord('9')), 'pull rest in order');
  Check(link.OutQueue.Available=0, 'queue drained');
  link.Free;

  writeln('== TSR runs against the REAL loopback link ==');
  link := TLoopbackServerLink.Create;
  tsr := TNetModemTSR.Create(link, 7);
  tsr.Startup;
  { Startup sends smConnect -> should be readable from what the link Sent }
  n := link.ReadSent(buf[0], SizeOf(buf));
  parser := TSeamParser.Create;
  if n>0 then parser.Feed(buf[0], n);
  sawConnect := False;
  while parser.NextFrame(fr) do
    if (fr.Msg=smConnect) and (fr.NodeIndex=7) then sawConnect := True;
  Check(sawConnect, 'smConnect for node 7 went out through the real link');
  parser.Free;

  writeln('== guest -> link: bytes flow out via Pump ==');
  RingPut(tsr.UartPtr^.TX, Ord('H')); RingPut(tsr.UartPtr^.TX, Ord('i'));
  tsr.Pump;
  n := link.ReadSent(buf[0], SizeOf(buf));
  parser := TSeamParser.Create;
  if n>0 then parser.Feed(buf[0], n);
  sawData := False;
  while parser.NextFrame(fr) do
    if (fr.Msg=smData) and (fr.NodeIndex=7) and (Length(fr.Payload)=2)
       and (fr.Payload[0]=Ord('H')) and (fr.Payload[1]=Ord('i')) then sawData := True;
  Check(sawData, 'guest "Hi" went out through the real link as smData');
  parser.Free;

  writeln('== link -> guest: deliver a data frame, Pump feeds the UART RX ==');
  { build an smData frame "OK" for node 7 and deliver it to the link's Poll side }
  pl[0]:=Ord('O'); pl[1]:=Ord('K');
  n := BuildFrame(smData, 7, pl[0], 2, buf[0]);
  link.DeliverToPoll(buf[0], n);
  tsr.Pump;
  Check(UartReadReg(tsr.UartPtr^,0)=Ord('O'), 'guest reads O from real-link data');
  Check(UartReadReg(tsr.UartPtr^,0)=Ord('K'), 'guest reads K from real-link data');

  tsr.Free; link.Free;

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('CONCRETE SERVER LINK - VERIFIED');
end.
