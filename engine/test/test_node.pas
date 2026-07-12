program test_node;
{$MODE OBJFPC}{$H+}
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node;

type
  { fake link with independent per-instance queues (proves node isolation) }
  TFakeLink = class(TInterfacedObject, ISocketLink)
  public
    ToRemote, FromRemote: array of Byte; RPos: Integer; Connected: Boolean;
    function Connect(const AHost:string;APort:Word):TLinkResult;
    function Send(const Buf;Len:Integer;out Sent:Integer):TLinkResult;
    function Recv(var Buf;Len:Integer;out Got:Integer):TLinkResult;
    procedure Close; function IsConnected:Boolean;
    procedure Arrive(const B: array of Byte);
  end;
function TFakeLink.Connect(const AHost:string;APort:Word):TLinkResult;begin Connected:=True;Result:=lrOk;end;
function TFakeLink.Send(const Buf;Len:Integer;out Sent:Integer):TLinkResult;
var p:PByte;i,b:Integer;begin p:=@Buf;b:=Length(ToRemote);SetLength(ToRemote,b+Len);
  for i:=0 to Len-1 do ToRemote[b+i]:=p[i];Sent:=Len;Result:=lrOk;end;
function TFakeLink.Recv(var Buf;Len:Integer;out Got:Integer):TLinkResult;
var p:PByte;n:Integer;begin p:=@Buf;Got:=0;n:=Length(FromRemote)-RPos;
  if n<=0 then Exit(lrWouldBlock); if n>Len then n:=Len;
  while Got<n do begin p[Got]:=FromRemote[RPos];Inc(RPos);Inc(Got);end;Result:=lrOk;end;
procedure TFakeLink.Close;begin Connected:=False;end;
function TFakeLink.IsConnected:Boolean;begin Result:=Connected;end;
procedure TFakeLink.Arrive(const B:array of Byte);
var b0,i:Integer;begin b0:=Length(FromRemote);SetLength(FromRemote,b0+Length(B));
  for i:=0 to High(B) do FromRemote[b0+i]:=B[i];end;

var
  mgr: TNodeManager;
  linkA, linkB: TFakeLink;
  ilinkA, ilinkB: ISocketLink;   // hold interface refs (lifetime)
  nodeA, nodeB: TNetModemNode;
  pass, fail: Integer; b: Byte;
  R: TFossilRegs;

procedure Check(cond: Boolean; const name: string);
begin
  if cond then begin Inc(pass); writeln('  PASS: ',name); end
  else begin Inc(fail); writeln('  FAIL: ',name); end;
end;

begin
  pass:=0; fail:=0;
  mgr := TNodeManager.Create;

  writeln('== create two independent nodes (multinode) ==');
  linkA := TFakeLink.Create;  linkB := TFakeLink.Create;
  linkA.Connected := True;  linkB.Connected := True;  // inbound: already accepted
  ilinkA := linkA;  ilinkB := linkB;   // keep interface refs alive
  nodeA := mgr.AddNode(3, ilinkA);  // comport 3
  nodeB := mgr.AddNode(4, ilinkB);  // comport 4
  Check((nodeA <> nil) and (nodeB <> nil), 'two nodes created');
  Check(mgr.Count = 2, 'manager reports 2 nodes');
  Check(mgr.NodeByIndex(3) = nodeA, 'node 3 lookup');
  Check(mgr.NodeByIndex(4) = nodeB, 'node 4 lookup');

  writeln('== both go online independently ==');
  nodeA.ConnectInbound;  nodeB.ConnectInbound;
  Check(nodeA.Online and nodeB.Online, 'both carriers up');

  writeln('== isolation: data to node A does not appear on node B ==');
  linkA.Arrive([Ord('H'), Ord('i'), Ord('A')]);
  linkB.Arrive([Ord('B'), Ord('B')]);
  mgr.PumpAll;
  // node A should have "HiA", node B should have "BB"
  Check(nodeA.GuestRead(b) and (b=Ord('H')), 'node A got H');
  Check(nodeA.GuestRead(b) and (b=Ord('i')), 'node A got i');
  Check(nodeA.GuestRead(b) and (b=Ord('A')), 'node A got A');
  Check(not nodeA.GuestRead(b), 'node A drained (no B data leaked in)');
  Check(nodeB.GuestRead(b) and (b=Ord('B')), 'node B got B');
  Check(nodeB.GuestRead(b) and (b=Ord('B')), 'node B got second B');
  Check(not nodeB.GuestRead(b), 'node B drained (no A data leaked in)');

  writeln('== guest write online -> goes to that node''s wire only ==');
  nodeA.GuestWrite(Ord('X'));   // online mode, should hit linkA.ToRemote
  mgr.PumpAll;
  Check((Length(linkA.ToRemote) > 0) and (linkA.ToRemote[High(linkA.ToRemote)] = Ord('X')),
        'node A guest byte X reached node A socket');

  writeln('== disconnect one node, other stays up ==');
  nodeA.Disconnect;
  Check(not nodeA.Online, 'node A carrier dropped');
  Check(nodeB.Online, 'node B still online (isolated)');

  writeln('== FOSSIL init works per node ==');
  FillChar(R, SizeOf(R), 0); R.AH := FN_INIT;
  nodeB.Fossil(R);
  Check((R.AH=$19) and (R.AL=$54), 'node B FOSSIL init returns 1954h');

  writeln('== remove node frees slot ==');
  mgr.RemoveNode(3);
  Check(mgr.NodeByIndex(3) = nil, 'node 3 removed');
  Check(mgr.Count = 1, 'manager now 1 node');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('MULTINODE VERIFIED');
end.
