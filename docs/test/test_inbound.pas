program test_inbound;
{$MODE OBJFPC}{$H+}
{ The original's core purpose: a caller Telnets in, the node RINGs, the BBS
  answers, the session runs. Test that whole inbound lifecycle. }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node, NM_ServerBridge;
type
  TFakeLink = class(TInterfacedObject, ISocketLink)
  public FromWire: array of Byte; RPos: Integer; Conn: Boolean;
    function Connect(const H:string;P:Word):TLinkResult;
    function Send(const B;L:Integer;out S:Integer):TLinkResult;
    function Recv(var B;L:Integer;out G:Integer):TLinkResult;
    procedure Close; function IsConnected:Boolean; procedure WireSends(const D:array of Byte);
  end;
function TFakeLink.Connect(const H:string;P:Word):TLinkResult;begin Conn:=True;Result:=lrOk;end;
function TFakeLink.Send(const B;L:Integer;out S:Integer):TLinkResult;begin S:=L;Result:=lrOk;end;
function TFakeLink.Recv(var B;L:Integer;out G:Integer):TLinkResult;
var p:PByte;n:Integer;begin p:=@B;G:=0;n:=Length(FromWire)-RPos;if n<=0 then Exit(lrWouldBlock);
  if n>L then n:=L;while G<n do begin p[G]:=FromWire[RPos];Inc(RPos);Inc(G);end;Result:=lrOk;end;
procedure TFakeLink.Close;begin Conn:=False;end;
function TFakeLink.IsConnected:Boolean;begin Result:=Conn;end;
procedure TFakeLink.WireSends(const D:array of Byte);
var bb,i:Integer;begin bb:=Length(FromWire);SetLength(FromWire,bb+Length(D));
  for i:=0 to High(D) do FromWire[bb+i]:=D[i];end;

var
  br: TServerBridge; pass,fail:Integer; b:Byte; s:string;
  fake: TFakeLink; ifake: ISocketLink; node: TNetModemNode;
procedure Check(c:Boolean;const n:string);
begin if c then begin Inc(pass);writeln('  PASS: ',n);end else begin Inc(fail);writeln('  FAIL: ',n);end;end;
function DrainGuest: string;
var bb: Byte;
begin Result:=''; while node.GuestRead(bb) do if bb>=32 then Result:=Result+Chr(bb); end;

begin
  pass:=0;fail:=0;
  br := TServerBridge.Create;
  fake := TFakeLink.Create; fake.Conn := True; ifake := fake;

  writeln('== a caller Telnets in: create the node for the inbound connection ==');
  node := br.Nodes.AddNode(3, ifake);
  Check(node <> nil, 'node created for inbound caller');

  writeln('== server RINGs the node (RingNode) -> BBS should see RING ==');
  { put the node in command mode first so RING is visible as a result code }
  br.RingNode(3);
  s := DrainGuest;
  Check(Pos('RING', s) > 0, 'BBS sees RING on incoming call');

  writeln('== BBS answers -> node comes online (ConnectInbound = ATA equivalent) ==');
  node.ConnectInbound;
  Check(br.AnswerCheck(3), 'AnswerCheck true after answer (online)');
  Check(node.Online, 'node online');

  writeln('== session runs: caller sends data, BBS receives it ==');
  fake.WireSends([Ord('h'),Ord('i')]);
  br.PumpAll;
  Check(br.GuestRead(3, b) and (b=Ord('h')), 'BBS receives caller data');

  writeln('== caller hangs up (disconnect) ==');
  br.OnDisconnectNode(3);
  Check(br.Nodes.NodeByIndex(3)=nil, 'node cleaned up after hangup');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('INBOUND CALL LIFECYCLE VERIFIED');
end.
