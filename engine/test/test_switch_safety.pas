program test_switch_safety;
{$MODE OBJFPC}{$H+}
{ Hammer the failure modes flagged by the maintainer:
  1. folding  - churn that could re-add/double-service or degrade to O(n^2)
  2. trapping - a dead node left in the active list, pumped forever
  3. dangling - active list pointing at freed memory (reuse a slot) }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node, NM_SeamProtocol, NM_ServerBridge;
type
  TFakeLink = class(TInterfacedObject, ISocketLink)
    function Connect(const H:string;P:Word):TLinkResult;
    function Send(const B;L:Integer;out S:Integer):TLinkResult;
    function Recv(var B;L:Integer;out G:Integer):TLinkResult;
    procedure Close; function IsConnected:Boolean;
  end;
function TFakeLink.Connect(const H:string;P:Word):TLinkResult;begin Result:=lrOk;end;
function TFakeLink.Send(const B;L:Integer;out S:Integer):TLinkResult;begin S:=L;Result:=lrOk;end;
function TFakeLink.Recv(var B;L:Integer;out G:Integer):TLinkResult;begin G:=0;Result:=lrWouldBlock;end;
procedure TFakeLink.Close;begin end;
function TFakeLink.IsConnected:Boolean;begin Result:=True;end;
var
  br: TServerBridge; pass,fail,i:Integer; link: ISocketLink; node: TNetModemNode;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;
  br := TServerBridge.Create;
  link := TFakeLink.Create;

  writeln('== DANGLING: reuse a slot (free old node) — active list must not dangle ==');
  node := br.Nodes.AddNode(7, link); node.ConnectInbound;
  Check(br.Nodes.ActiveCount = 1, 'node 7 active');
  { reuse slot 7 — old node is freed; AddNode must purge it from FActive first }
  node := br.Nodes.AddNode(7, link); node.ConnectInbound;
  br.PumpAll;   { if the old freed node were still in FActive, this would crash/corrupt }
  Check(br.Nodes.ActiveCount = 1, 'slot reuse did not leave a dangling/duplicate active entry');

  writeln('== TRAPPING: disconnect must remove node from active servicing ==');
  br.OnDisconnectNode(7);
  br.PumpAll;
  Check(br.Nodes.ActiveCount = 0, 'disconnected node not trapped in active list');

  writeln('== FOLDING: heavy connect/disconnect churn stays bounded (no growth) ==');
  for i := 1 to 5000 do
  begin
    node := br.Nodes.AddNode(3, link); node.ConnectInbound;
    br.PumpAll;
    br.OnDisconnectNode(3);
    br.PumpAll;
  end;
  Check(br.Nodes.ActiveCount = 0, 'after 5000 connect/disconnect cycles, active list is clean (no fold/leak)');

  writeln('== FOLDING: repeated MarkActive of same node cannot duplicate ==');
  node := br.Nodes.AddNode(9, link); node.ConnectInbound;
  for i := 1 to 100 do br.Nodes.MarkActive(9);   { spam activate }
  Check(br.Nodes.ActiveCount = 1, '100x MarkActive -> still exactly 1 active (no fold)');

  writeln('== many nodes up then all down — active list returns to zero ==');
  for i := 10 to 60 do begin node := br.Nodes.AddNode(i, link); node.ConnectInbound; end;
  Check(br.Nodes.ActiveCount = 52, 'expected 52 active after bulk connect (node9 + 10..60)');
  for i := 10 to 60 do br.OnDisconnectNode(i);
  br.OnDisconnectNode(9);
  br.PumpAll;
  Check(br.Nodes.ActiveCount = 0, 'all disconnected -> active list empty (no trapped nodes)');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('SWITCH SAFETY VERIFIED (no fold / no trap / no dangling)');
end.
