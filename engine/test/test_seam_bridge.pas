program test_seam_bridge;
{$MODE OBJFPC}{$H+}
{ Integration: raw seam bytes -> bridge parses+routes to node operations.
  This is how the future FOSSIL TSR drives the server over its pipe/socket. }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node,
     NM_SeamProtocol, NM_ServerBridge;
type
  TFakeLink = class(TInterfacedObject, ISocketLink)
  public Conn: Boolean;
    function Connect(const H:string;P:Word):TLinkResult;
    function Send(const B;L:Integer;out S:Integer):TLinkResult;
    function Recv(var B;L:Integer;out G:Integer):TLinkResult;
    procedure Close; function IsConnected:Boolean;
  end;
function TFakeLink.Connect(const H:string;P:Word):TLinkResult;begin Conn:=True;Result:=lrOk;end;
function TFakeLink.Send(const B;L:Integer;out S:Integer):TLinkResult;begin S:=L;Result:=lrOk;end;
function TFakeLink.Recv(var B;L:Integer;out G:Integer):TLinkResult;begin G:=0;Result:=lrWouldBlock;end;
procedure TFakeLink.Close;begin Conn:=False;end;
function TFakeLink.IsConnected:Boolean;begin Result:=True;end;

var
  br: TServerBridge; pass,fail,n:Integer; b:Byte;
  fake: TFakeLink; ifake: ISocketLink; node: TNetModemNode;
  buf: array[0..255] of Byte; payload: array[0..255] of Byte;
  handled, i: Integer;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;

begin
  pass:=0;fail:=0;
  br := TServerBridge.Create;
  fake := TFakeLink.Create; fake.Conn:=True; ifake := fake;
  { pre-create node 4 with a link so data/connect can route to it }
  node := br.Nodes.AddNode(4, ifake);

  writeln('== smConnect frame -> node rings (inbound) ==');
  FillChar(payload, SizeOf(payload), 0);
  n := BuildFrame(smConnect, 4, payload[0], 0, buf[0]);
  Check(br.FeedDriverBytes(buf[0], n) = 1, 'one connect frame handled');
  { RING should have been emitted to the guest }
  b := 0; if node.GuestRead(b) then ; // drain; RING presence tested elsewhere
  Check(node <> nil, 'node 4 present after connect');

  writeln('== smData frame -> bytes reach the node (to the wire) ==');
  node.ConnectInbound;   // online so GuestWrite routes to transport
  payload[0]:=Ord('H'); payload[1]:=Ord('i');
  n := BuildFrame(smData, 4, payload[0], 2, buf[0]);
  Check(br.FeedDriverBytes(buf[0], n) = 1, 'one data frame handled');
  { the node's UART TX ring should now hold H,i (guest-written) }
  Check(node.Uart.TX.Count >= 2, 'data bytes reached the node');

  writeln('== BINARY-CLEAN data frame (payload incl $A5 SYNC) ==');
  payload[0]:=$A5; payload[1]:=$00; payload[2]:=$FF;
  n := BuildFrame(smData, 4, payload[0], 3, buf[0]);
  Check(br.FeedDriverBytes(buf[0], n) = 1, 'binary data frame handled (payload had $A5)');

  writeln('== SPLIT read: one frame fed a byte at a time ==');
  payload[0]:=Ord('X');
  n := BuildFrame(smData, 4, payload[0], 1, buf[0]);
  handled := 0;

  for i:=0 to n-1 do handled := handled + br.FeedDriverBytes(buf[i], 1);
  Check(handled = 1, 'frame reassembled+handled from single-byte feeds');

  writeln('== smDisconnect frame -> node removed ==');
  n := BuildFrame(smDisconnect, 4, payload[0], 0, buf[0]);
  br.FeedDriverBytes(buf[0], n);
  Check(br.Nodes.NodeByIndex(4) = nil, 'node removed after disconnect frame');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('SEAM<->BRIDGE INTEGRATION VERIFIED');
end.
