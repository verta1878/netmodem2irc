program test_bridge_io;
{$MODE OBJFPC}{$H+}
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node, NM_ServerBridge;
type
  TFakeLink = class(TInterfacedObject, ISocketLink)
  public
    ToWire: array of Byte; FromWire: array of Byte; RPos: Integer; Conn: Boolean;
    function Connect(const H:string;P:Word):TLinkResult;
    function Send(const B;L:Integer;out S:Integer):TLinkResult;
    function Recv(var B;L:Integer;out G:Integer):TLinkResult;
    procedure Close; function IsConnected:Boolean;
    procedure WireSends(const D:array of Byte);
  end;
function TFakeLink.Connect(const H:string;P:Word):TLinkResult;begin Conn:=True;Result:=lrOk;end;
function TFakeLink.Send(const B;L:Integer;out S:Integer):TLinkResult;
var p:PByte;i,bb:Integer;begin p:=@B;bb:=Length(ToWire);SetLength(ToWire,bb+L);
  for i:=0 to L-1 do ToWire[bb+i]:=p[i];S:=L;Result:=lrOk;end;
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
  io: TBridgeIO;
  rxbuf, hxbuf: array[0..63] of Byte;
  got, distinct: Integer;
  seen: array[0..255] of Boolean;
procedure Check(c:Boolean;const n:string);
begin if c then begin Inc(pass);writeln('  PASS: ',n);end else begin Inc(fail);writeln('  FAIL: ',n);end;end;
begin
  pass:=0;fail:=0;
  br := TServerBridge.Create;
  fake := TFakeLink.Create; fake.Conn := True; ifake := fake;
  node := br.Nodes.AddNode(5, ifake);
  node.ConnectInbound;

  writeln('== ServiceNodeIO RX: game-written bytes go to the wire ==');
  rxbuf[0]:=Ord('A'); rxbuf[1]:=Ord('T'); rxbuf[2]:=Ord('Z'); rxbuf[3]:=13;
  FillChar(io, SizeOf(io), 0);
  io.RXData := @rxbuf[0]; io.RXLength := 4;
  io.HXData := @hxbuf[0]; io.HXLength := SizeOf(hxbuf);
  Check(br.ServiceNodeIO(5, io), 'ServiceNodeIO returns true for node 5');
  Check(io.Received = 4, 'consumed 4 RX bytes');
  br.PumpAll;  // push node TX to the wire
  Check(Length(fake.ToWire) >= 4, 'RX bytes reached the wire');

  writeln('== ServiceNodeIO HX: wire bytes fill the game buffer ==');
  fake.WireSends([Ord('C'),Ord('O'),Ord('N'),Ord('N'),Ord('E'),Ord('C'),Ord('T')]);
  br.PumpAll;  // pull wire -> node RX ring
  FillChar(io, SizeOf(io), 0);
  io.RXData := nil; io.RXLength := 0;
  io.HXData := @hxbuf[0]; io.HXLength := SizeOf(hxbuf);
  br.ServiceNodeIO(5, io);
  Check(io.HXFilled = 7, 'filled 7 HX bytes from wire');
  Check((hxbuf[0]=Ord('C')) and (hxbuf[6]=Ord('T')), 'HX buffer contains CONNECT');

  writeln('== binary safety through ServiceNodeIO (all 256 values, wire->game) ==');
  { A Telnet stream must escape 0xFF as IAC IAC. Send all 256 distinct values,
    doubling 0xFF, and confirm every distinct value arrives (order not asserted). }
  SetLength(fake.FromWire,0); fake.RPos:=0;
  for i:=0 to 255 do
    if i = 255 then fake.WireSends([255,255])   // IAC IAC = literal 0xFF
    else fake.WireSends([Byte(i)]);
  for i:=0 to 255 do seen[i]:=False;
  got:=0;
  repeat
    br.PumpAll;
    FillChar(io, SizeOf(io), 0);
    io.HXData := @hxbuf[0]; io.HXLength := SizeOf(hxbuf);
    br.ServiceNodeIO(5, io);
    for i:=0 to io.HXFilled-1 do begin seen[hxbuf[i]]:=True; Inc(got); end;
  until (io.HXFilled = 0);
  distinct:=0; for i:=0 to 255 do if seen[i] then Inc(distinct);
  Check(distinct = 256, 'all 256 distinct byte values arrived (0xFF via IAC IAC)');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('BRIDGE IO (TIOStruct PATH) VERIFIED');
end.
