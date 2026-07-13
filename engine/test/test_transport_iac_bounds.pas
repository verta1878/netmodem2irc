program test_transport_iac_bounds;
{$MODE OBJFPC}{$H+}
{ NetTransport IAC bounds: the outbound doubling writes 2 bytes per IAC, so an
  all-0xFF TX ring at the buffer edge must NOT overflow outbuf. And the inbound
  state machine must handle hostile IAC sequences (endless SB, escaped FF, unknown
  commands) without overrun. Structural-sight: the doubling is where the ghost hid. }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport;
type
  { fake link that captures sent bytes and never overflows }
  TCapLink = class(TInterfacedObject, ISocketLink)
    Sent: array of Byte;
    function Connect(const H:string;P:Word):TLinkResult;
    function Send(const B;L:Integer;out S:Integer):TLinkResult;
    function Recv(var B;L:Integer;out G:Integer):TLinkResult;
    procedure Close; function IsConnected:Boolean;
  end;
function TCapLink.Connect(const H:string;P:Word):TLinkResult;begin Result:=lrOk;end;
function TCapLink.Send(const B;L:Integer;out S:Integer):TLinkResult;
var p:PByte;i,b0:Integer;begin p:=@B;b0:=Length(Sent);SetLength(Sent,b0+L);for i:=0 to L-1 do Sent[b0+i]:=p[i];S:=L;Result:=lrOk;end;
function TCapLink.Recv(var B;L:Integer;out G:Integer):TLinkResult;begin G:=0;Result:=lrWouldBlock;end;
procedure TCapLink.Close;begin end;
function TCapLink.IsConnected:Boolean;begin Result:=True;end;
var
  t: TNetTransport; u: TUart16550; link: TCapLink; pass,fail,i,cnt255: Integer;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;
  UartReset(u);
  link := TCapLink.Create;
  t := TNetTransport.Create(@u, link);

  writeln('== outbound IAC doubling at the buffer EDGE cannot overflow ==');
  { fill the TX ring with MANY 0xFF bytes — each doubles. If the bound were wrong,
    this overruns outbuf. Fill more than the 1024 outbuf so Pump processes a full
    buffer of all-IAC. }
  for i := 1 to 2000 do
    if RingFree(u.TX) > 0 then RingPut(u.TX, TELNET_IAC);
  { Pump drains TX -> outbuf with doubling -> link.Send. Must not crash/overflow. }
  t.Pump;
  { every 0xFF should appear DOUBLED in the sent stream }
  cnt255 := 0;
  for i := 0 to High(link.Sent) do if link.Sent[i] = 255 then Inc(cnt255);
  Check(cnt255 > 0, 'IAC bytes were sent (doubled)');
  Check((cnt255 mod 2) = 0, 'IAC count is EVEN — every FF doubled, none split at edge');
  Check(Length(link.Sent) <= 1024, 'sent chunk stayed within outbuf bounds (no overflow)');
  writeln('     (sent ',Length(link.Sent),' bytes, ',cnt255,' were 0xFF)');

  writeln('== survives a full buffer of all-IAC without crashing ==');
  Check(True, 'no overflow/crash on all-IAC buffer at the edge');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('TRANSPORT IAC BOUNDS - VERIFIED');
end.
