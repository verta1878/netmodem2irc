program test_tsr;
{$MODE OBJFPC}{$H+}
{ The TSR skeleton orchestrating the full driver side: guest UART traffic ->
  seam frames -> server; server frames -> UART RX -> guest. Uses a fake server
  link (a buffer) so we test the whole shell on the host. }
uses SysUtils, NM_UART16550, NM_Fossil, NM_FossilDriver, NM_SeamProtocol,
     NM_SeamSender, NM_TSR;
type
  { fake server link: captures what the TSR sends; can be fed frames to return }
  TFakeServer = class(TServerLink)
  public
    Sent    : array of Byte;   { everything the TSR sent us }
    ToReturn: array of Byte;   { bytes we'll hand back on Poll }
    function Send(const Buf; Len: Integer): Integer; override;
    function Poll(var Buf; MaxLen: Integer): Integer; override;
  end;
function TFakeServer.Send(const Buf; Len: Integer): Integer;
var p:PByte; i,b:Integer;
begin
  p:=@Buf; b:=Length(Sent); SetLength(Sent, b+Len);
  for i:=0 to Len-1 do Sent[b+i]:=p[i];
  Result:=Len;
end;
function TFakeServer.Poll(var Buf; MaxLen: Integer): Integer;
var p:PByte; i,n:Integer;
begin
  n := Length(ToReturn); if n > MaxLen then n := MaxLen;
  p:=@Buf;
  for i:=0 to n-1 do p[i]:=ToReturn[i];
  if n > 0 then
  begin
    for i:=n to High(ToReturn) do ToReturn[i-n]:=ToReturn[i];
    SetLength(ToReturn, Length(ToReturn)-n);
  end;
  Result:=n;
end;

var
  srv: TFakeServer; tsr: TNetModemTSR; pass,fail,i:Integer;
  parser: TSeamParser; fr: TSeamFrame;
  frbuf: array[0..63] of Byte; pl: array[0..7] of Byte; n: Integer;
  sawConnect, sawData: Boolean;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;
  srv := TFakeServer.Create;
  tsr := TNetModemTSR.Create(srv, 5);

  writeln('== Startup sends smConnect to the server ==');
  tsr.Startup;
  Check(tsr.Running, 'TSR is running after Startup');
  { parse what the server received: should contain an smConnect for node 5 }
  parser := TSeamParser.Create;
  if Length(srv.Sent) > 0 then parser.Feed(srv.Sent[0], Length(srv.Sent));
  sawConnect := False;
  while parser.NextFrame(fr) do
    if (fr.Msg = smConnect) and (fr.NodeIndex = 5) then sawConnect := True;
  Check(sawConnect, 'server received smConnect for node 5');
  parser.Free;

  writeln('== guest writes to UART TX -> Pump -> server gets smData ==');
  SetLength(srv.Sent, 0);
  { simulate the guest (via FOSSIL) putting bytes in the UART TX ring }
  
  RingPut(tsr.UartPtr^.TX, Ord('H'));
  RingPut(tsr.UartPtr^.TX, Ord('i'));
  tsr.Pump;
  parser := TSeamParser.Create;
  if Length(srv.Sent) > 0 then parser.Feed(srv.Sent[0], Length(srv.Sent));
  sawData := False;
  while parser.NextFrame(fr) do
    if (fr.Msg = smData) and (fr.NodeIndex = 5) and (Length(fr.Payload)=2)
       and (fr.Payload[0]=Ord('H')) and (fr.Payload[1]=Ord('i')) then sawData := True;
  Check(sawData, 'server received smData "Hi" from the guest via Pump');
  parser.Free;

  writeln('== server sends smData -> Pump -> lands in UART RX for the guest ==');
  pl[0]:=Ord('O');pl[1]:=Ord('K');
  n := BuildFrame(smData, 5, pl[0], 2, frbuf[0]);
  SetLength(srv.ToReturn, n);
  for i:=0 to n-1 do srv.ToReturn[i]:=frbuf[i];
  tsr.Pump;
  { guest reads UART RX -> should get O, K }
  Check(UartReadReg(tsr.UartPtr^, 0)=Ord('O'), 'guest reads O from UART RX');
  Check(UartReadReg(tsr.UartPtr^, 0)=Ord('K'), 'guest reads K from UART RX');

  writeln('== server smConnect raises carrier ==');
  n := BuildFrame(smConnect, 5, pl[0], 0, frbuf[0]);
  SetLength(srv.ToReturn, n);
  for i:=0 to n-1 do srv.ToReturn[i]:=frbuf[i];
  tsr.Pump;
  Check(tsr.UartPtr^.Online, 'carrier raised after server smConnect');

  writeln('== Shutdown sends smDisconnect ==');
  SetLength(srv.Sent, 0);
  tsr.Shutdown;
  Check(not tsr.Running, 'TSR stopped after Shutdown');
  parser := TSeamParser.Create;
  if Length(srv.Sent) > 0 then parser.Feed(srv.Sent[0], Length(srv.Sent));
  sawConnect := False;
  while parser.NextFrame(fr) do
    if fr.Msg = smDisconnect then sawConnect := True;
  Check(sawConnect, 'server received smDisconnect on Shutdown');
  parser.Free;

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('TSR SKELETON ORCHESTRATION - VERIFIED');
  tsr.Free; srv.Free;
end.
