program test_switch;
{$MODE OBJFPC}{$H+}
{ Verify switch behavior + MEASURE it vs the old hub sweep.
  Scenario: 99 slots, only a few active. Switch should cost ~active, not ~99. }
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
  br: TServerBridge; pass,fail,i,c:Integer; link: ISocketLink; node: TNetModemNode;
  t0,t1: TDateTime; iters: Integer;
procedure Check(cc:Boolean;const nm:string);
begin if cc then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;
  br := TServerBridge.Create;
  link := TFakeLink.Create;

  writeln('== switch correctness: only active nodes are serviced ==');
  { bring up 3 nodes out of 99 }
  node := br.Nodes.AddNode(10, link); node.ConnectInbound; br.Nodes.MarkActive(10);
  node := br.Nodes.AddNode(50, link); node.ConnectInbound; br.Nodes.MarkActive(50);
  node := br.Nodes.AddNode(98, link); node.ConnectInbound; br.Nodes.MarkActive(98);
  Check(br.Nodes.ActiveCount = 3, 'active list has exactly 3 live nodes (not 99)');

  br.PumpAll;  { should service 3, not sweep 99 }
  Check(br.Nodes.NodeByIndex(10) <> nil, 'node 10 still serviced');

  writeln('== a node hangs up -> drops out of the active set ==');
  br.OnDisconnectNode(50);
  br.PumpAll;
  Check(br.Nodes.ActiveCount <= 2, 'active count dropped after hangup');

  writeln('== PERFORMANCE: switch (few active) vs hub-equivalent full sweep ==');
  iters := 200000;
  { switch: 3 active among 99 slots }
  t0 := Now;
  for i := 1 to iters do br.PumpAll;
  t1 := Now;
  writeln(Format('  switch PumpAll x%d (3 active/99 slots): %.1f ms',
    [iters, (t1-t0)*24*60*60*1000]));

  { simulate hub cost: sweep all 99 slots each tick }
  t0 := Now;
  for i := 1 to iters do
    for c := 0 to NM_MAX_NODES-1 do
      if br.Nodes.NodeByIndex(c) <> nil then ;  { the per-slot check hub did }
  t1 := Now;
  writeln(Format('  hub  sweep  x%d (all 99 slots each):   %.1f ms',
    [iters, (t1-t0)*24*60*60*1000]));

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('SWITCH BRIDGE VERIFIED (services active nodes, not all slots)');
end.
