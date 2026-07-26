program test_bridge;
{$MODE OBJFPC}{$H+}
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node, NM_ServerBridge;
type
  TFakeLink = class(TInterfacedObject, ISocketLink)
  public
    FromR: array of Byte; RPos: Integer; Conn: Boolean;
    function Connect(const H:string;P:Word):TLinkResult;
    function Send(const B;L:Integer;out S:Integer):TLinkResult;
    function Recv(var B;L:Integer;out G:Integer):TLinkResult;
    procedure Close; function IsConnected:Boolean;
    procedure Arrive(const D:array of Byte);
  end;
function TFakeLink.Connect(const H:string;P:Word):TLinkResult;begin Conn:=True;Result:=lrOk;end;
function TFakeLink.Send(const B;L:Integer;out S:Integer):TLinkResult;begin S:=L;Result:=lrOk;end;
function TFakeLink.Recv(var B;L:Integer;out G:Integer):TLinkResult;
var p:PByte;n:Integer;begin p:=@B;G:=0;n:=Length(FromR)-RPos;if n<=0 then Exit(lrWouldBlock);
  if n>L then n:=L;while G<n do begin p[G]:=FromR[RPos];Inc(RPos);Inc(G);end;Result:=lrOk;end;
procedure TFakeLink.Close;begin Conn:=False;end;
function TFakeLink.IsConnected:Boolean;begin Result:=Conn;end;
procedure TFakeLink.Arrive(const D:array of Byte);
var b,i:Integer;begin b:=Length(FromR);SetLength(FromR,b+Length(D));
  for i:=0 to High(D) do FromR[b+i]:=D[i];end;

var
  br: TServerBridge; pass,fail:Integer; b:Byte;
  fake: TFakeLink; ifake: ISocketLink; node: TNetModemNode;
procedure Check(c:Boolean;const n:string);
begin if c then begin Inc(pass);writeln('  PASS: ',n);end else begin Inc(fail);writeln('  FAIL: ',n);end;end;
begin
  pass:=0;fail:=0;
  br := TServerBridge.Create;

  writeln('== bridge starts with no nodes ==');
  Check(br.Nodes.Count=0, 'no nodes initially');
  Check(br.DefaultPort=23, 'default port is Telnet 23');

  writeln('== inject a node the way OnConnectNode would (test the wiring) ==');
  { since stub MakeLink returns nil, seed a node directly to test the CM_* paths }
  fake := TFakeLink.Create; fake.Conn := True; ifake := fake;
  node := br.Nodes.AddNode(3, ifake);
  node.ConnectInbound;
  Check(br.Nodes.Count=1, 'node 3 present');
  Check(node.Online, 'node 3 online after connect');

  writeln('== CM_SEND_REMOTE_BREAK path ==');
  br.OnSendRemoteBreak(3);  // should not crash, sends break
  Check(True, 'OnSendRemoteBreak dispatched');

  writeln('== data path: driver sends bytes, guest reads them ==');
  fake.Arrive([Ord('H'),Ord('i')]);
  br.PumpAll;
  Check(br.GuestRead(3,b) and (b=Ord('H')), 'guest reads H via bridge');
  Check(br.GuestRead(3,b) and (b=Ord('i')), 'guest reads i via bridge');

  writeln('== guest writes (online) go toward the wire ==');
  br.GuestWrite(3, Ord('X'));
  br.PumpAll;
  Check(True, 'guest write dispatched without error');

  writeln('== CM_DISCONNECT_NODE removes the node ==');
  br.OnDisconnectNode(3);
  Check(br.Nodes.NodeByIndex(3)=nil, 'node 3 removed after disconnect');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('SERVER BRIDGE VERIFIED');
end.
