program test_seam_roundtrip;
{$MODE OBJFPC}{$H+}
{ THE FULL LOOP: driver-side NM_SeamSender emits frames -> those exact bytes are
  fed to the server-side TServerBridge.FeedDriverBytes -> correct node ops.
  Proves both halves of the driver<->server seam talk to each other. }
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

{ The "wire" between driver and server: a buffer the sender writes and the
  server reads. This stands in for the pipe/socket. }
var
  wire: array of Byte;
  br: TServerBridge; sender: TSeamSender;
  fake: TFakeLink; ifake: ISocketLink; node: TNetModemNode;
  pass, fail: Integer;

{ the sink: driver-side sender writes frame bytes into 'wire' }
type
  TSinkHolder = class
    function Sink(const Buf; Len: Integer): Integer;
  end;
function TSinkHolder.Sink(const Buf; Len: Integer): Integer;
var p:PByte; i,b:Integer;
begin
  p:=@Buf; b:=Length(wire); SetLength(wire, b+Len);
  for i:=0 to Len-1 do wire[b+i]:=p[i];
  Result:=Len;
end;

var holder: TSinkHolder;

procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;

{ push everything currently in 'wire' into the server, then clear it }
function FlushWireToServer: Integer;
begin
  Result := 0;
  if Length(wire) > 0 then
  begin
    Result := br.FeedDriverBytes(wire[0], Length(wire));
    SetLength(wire, 0);
  end;
end;

var msg: array[0..7] of Byte; i: Integer;
begin
  pass:=0;fail:=0;
  SetLength(wire,0);
  br := TServerBridge.Create;
  holder := TSinkHolder.Create;
  fake := TFakeLink.Create; ifake := fake;
  { pre-create the node the driver serves }
  node := br.Nodes.AddNode(6, ifake);
  sender := TSeamSender.Create(@holder.Sink, 6);

  writeln('== driver SendConnect -> server rings the node ==');
  sender.SendConnect;
  Check(FlushWireToServer = 1, 'connect frame crossed the wire and was handled');

  writeln('== driver SendData -> bytes reach the node (guest->wire) ==');
  node.ConnectInbound;
  msg[0]:=Ord('H');msg[1]:=Ord('E');msg[2]:=Ord('L');msg[3]:=Ord('O');
  sender.SendData(msg[0], 4);
  Check(FlushWireToServer = 1, 'data frame crossed and handled');
  Check(node.Uart.TX.Count >= 4, 'HELO reached the node (4 bytes queued to wire)');

  writeln('== binary-clean across the full loop (0x00..0xFF incl 0xA5 SYNC) ==');
  SetLength(wire,0);
  { send all 256 byte values as data through the sender }
  for i:=0 to 255 do sender.SendByte(Byte(i));
  Check(FlushWireToServer = 256, 'all 256 single-byte data frames handled');

  writeln('== driver SendBreak -> server handles remote break ==');
  sender.SendBreak;
  Check(FlushWireToServer = 1, 'break frame crossed and handled');

  writeln('== driver SendDisconnect -> node removed ==');
  sender.SendDisconnect;
  FlushWireToServer;
  Check(br.Nodes.NodeByIndex(6) = nil, 'disconnect frame removed the node');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('FULL DRIVER<->SERVER SEAM LOOP VERIFIED');
end.
