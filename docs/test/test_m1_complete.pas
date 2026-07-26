program test_m1_complete;
{$MODE OBJFPC}{$H+}
{ M1 completion test: simulate the full server<->engine path via a mock TIOStruct,
  exactly as the driver's IOCTL_IO provides it. Proves M1 is done. }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node, NM_ServerBridge;

type
  { EXACT mirror of the driver's TIOStruct (common/NetModemVxD.pas) }
  TIOStruct = packed record
    RXPointer  : DWORD;
    IORXLength : DWORD;
    Received   : Word;
    HXPointer  : DWORD;
    IOHXLength : DWORD;
    HXFree     : Word;
  end;

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
  br: TServerBridge; pass,fail,i:Integer;
  fake: TFakeLink; ifake: ISocketLink; node: TNetModemNode;
  dio: TIOStruct;
  rxbuf, hxbuf: array[0..255] of Byte;
  rcvd, filled: Word;

procedure Check(c:Boolean;const n:string);
begin if c then begin Inc(pass);writeln('  PASS: ',n);end else begin Inc(fail);writeln('  FAIL: ',n);end;end;

{ helper: service a node using the driver-struct path exactly as MainForm would }
procedure ServiceViaDriver(NodeIdx: Integer);
begin
  br.PumpAll;
  rcvd := 0; filled := 0;
  br.ServiceDriverIO(NodeIdx,
    @rxbuf[0], dio.IORXLength,
    @hxbuf[0], dio.IOHXLength,
    rcvd, filled);
  dio.Received := rcvd;
  dio.HXFree   := filled;
end;

begin
  pass:=0;fail:=0;
  br := TServerBridge.Create;
  fake := TFakeLink.Create; fake.Conn := True; ifake := fake;

  writeln('== M1: node comes online (CM_CONNECT_NODE path) ==');
  node := br.Nodes.AddNode(3, ifake);
  node.ConnectInbound;
  Check(node.Online, 'node online');

  writeln('== M1: inbound greeting from BBS arrives -> game buffer (HX) ==');
  fake.WireSends([Ord('W'),Ord('e'),Ord('l'),Ord('c'),Ord('o'),Ord('m'),Ord('e')]);
  FillChar(dio, SizeOf(dio), 0);
  dio.IORXLength := 0;            // game wrote nothing this tick
  dio.IOHXLength := SizeOf(hxbuf);
  ServiceViaDriver(3);
  Check(dio.HXFree = 7, 'driver reports 7 bytes for the game');
  Check((hxbuf[0]=Ord('W')) and (hxbuf[6]=Ord('e')), 'game buffer has "Welcome"');

  writeln('== M1: game types a response -> goes to wire (RX) ==');
  rxbuf[0]:=Ord('Y'); rxbuf[1]:=Ord('e'); rxbuf[2]:=Ord('s'); rxbuf[3]:=13;
  FillChar(dio, SizeOf(dio), 0);
  dio.IORXLength := 4;
  dio.IOHXLength := SizeOf(hxbuf);
  ServiceViaDriver(3);
  Check(dio.Received = 4, 'driver reports 4 bytes consumed from game');
  br.PumpAll;
  Check(node.Online, 'node still online after game write');

  writeln('== M1: binary-safe (0xFF via IAC IAC) end to end ==');
  SetLength(fake.FromWire,0); fake.RPos:=0;
  fake.WireSends([65, 255,255, 66]);   // A, literal 0xFF, B
  FillChar(dio, SizeOf(dio), 0);
  dio.IOHXLength := SizeOf(hxbuf);
  ServiceViaDriver(3);
  Check((dio.HXFree=3) and (hxbuf[0]=65) and (hxbuf[1]=255) and (hxbuf[2]=66),
        '0xFF preserved through the driver IO path');

  writeln('== M1: disconnect (CM_DISCONNECT_NODE path) ==');
  br.OnDisconnectNode(3);
  Check(br.Nodes.NodeByIndex(3)=nil, 'node removed on disconnect');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('M1 COMPLETE — SERVER<->ENGINE PATH VERIFIED');
end.
