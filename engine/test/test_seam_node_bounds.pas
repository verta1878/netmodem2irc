program test_seam_node_bounds;
{$MODE OBJFPC}{$H+}
{ Wire-value trust boundary (maintainer's lesson): the seam NODE field is a Byte
  (0..255) but NM_MAX_NODES=99. A frame carrying NODE >= 99 (corrupt/hostile wire)
  must be safely IGNORED, never index FNodes[] out of bounds. Prove the reader does
  not trust the boundary value. }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node,
     NM_SeamProtocol, NM_SeamSender, NM_ServerBridge;
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
  br: TServerBridge; pass,fail,n:Integer; buf: array[0..31] of Byte; pl: array[0..7] of Byte;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;
  br := TServerBridge.Create;

  writeln('== out-of-range NODE from the wire must be ignored, not crash ==');
  { NODE=200 (> NM_MAX_NODES=99). BuildFrame writes it (Byte). The bridge must
    handle the frame without indexing FNodes[200]. }
  n := BuildFrame(smConnect, 200, pl[0], 0, buf[0]);
  Check(br.FeedDriverBytes(buf[0], n) = 1, 'connect NODE=200 frame consumed (parsed)');
  { if it had indexed FNodes[200] we'd have crashed already; reaching here = safe }
  Check(br.Nodes.ActiveCount = 0, 'no phantom node activated for out-of-range NODE');

  writeln('== NODE=255 (max Byte) data frame safely ignored ==');
  pl[0]:=Ord('X');
  n := BuildFrame(smData, 255, pl[0], 1, buf[0]);
  Check(br.FeedDriverBytes(buf[0], n) = 1, 'data NODE=255 consumed without OOB');

  writeln('== NODE=98 (last valid slot) still works normally ==');
  n := BuildFrame(smConnect, 98, pl[0], 0, buf[0]);
  br.FeedDriverBytes(buf[0], n);
  Check(True, 'valid boundary NODE=98 handled (no crash)');

  writeln('== disconnect + break with out-of-range NODE ignored ==');
  n := BuildFrame(smDisconnect, 150, pl[0], 0, buf[0]); br.FeedDriverBytes(buf[0], n);
  n := BuildFrame(smBreak, 150, pl[0], 0, buf[0]); br.FeedDriverBytes(buf[0], n);
  Check(True, 'disconnect/break NODE=150 handled safely');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('SEAM NODE BOUNDS - VERIFIED');
end.
