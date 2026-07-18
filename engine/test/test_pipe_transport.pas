program test_pipe_transport;
{$MODE OBJFPC}{$H+}
uses SysUtils, NM_UART16550, NetTransport, NM_NamedPipeLink;
type
  TFakePipe = class(TInterfacedObject, IPipeBackend)
  public
    Opened: Boolean; ToDriver: array of Byte; FromDriver: array of Byte; FDPos: Integer;
    function Open(const APipeName: string): Boolean;
    function WriteBytes(const Buf; Len: Integer; out Written: Integer): Boolean;
    function ReadBytes(var Buf; Len: Integer; out ReadCount: Integer): Boolean;
    procedure CloseBackend; function IsOpen: Boolean;
    procedure DriverSends(const B: array of Byte);
  end;
function TFakePipe.Open(const APipeName:string):Boolean;begin Opened:=True;Result:=True;end;
function TFakePipe.WriteBytes(const Buf;Len:Integer;out Written:Integer):Boolean;
var p:PByte;i,b:Integer;begin p:=@Buf;b:=Length(ToDriver);SetLength(ToDriver,b+Len);
  for i:=0 to Len-1 do ToDriver[b+i]:=p[i];Written:=Len;Result:=True;end;
function TFakePipe.ReadBytes(var Buf;Len:Integer;out ReadCount:Integer):Boolean;
var p:PByte;n:Integer;begin p:=@Buf;ReadCount:=0;n:=Length(FromDriver)-FDPos;
  if n<=0 then Exit(True);if n>Len then n:=Len;
  while ReadCount<n do begin p[ReadCount]:=FromDriver[FDPos];Inc(FDPos);Inc(ReadCount);end;Result:=True;end;
procedure TFakePipe.CloseBackend;begin Opened:=False;end;
function TFakePipe.IsOpen:Boolean;begin Result:=Opened;end;
procedure TFakePipe.DriverSends(const B:array of Byte);
var b0,i:Integer;begin b0:=Length(FromDriver);SetLength(FromDriver,b0+Length(B));
  for i:=0 to High(B) do FromDriver[b0+i]:=B[i];end;
var
  U: TUart16550; fake: TFakePipe; ifake: IPipeBackend;
  link: ISocketLink; T: TNetTransport; pass,fail:Integer;
procedure Check(c:Boolean;const n:string);
begin if c then begin Inc(pass);writeln('  PASS: ',n);end else begin Inc(fail);writeln('  FAIL: ',n);end;end;
begin
  pass:=0;fail:=0;
  UartReset(U);
  fake:=TFakePipe.Create; ifake:=fake;
  link := TNamedPipeLink.Create(ifake, '\\.\pipe\netmodem-node3');
  // the SAME transport that drove the Synapse socket now drives the pipe link
  T := TNetTransport.Create(@U, link);
  link.Connect('',0);

  writeln('== the tested transport drives the pipe link unchanged ==');
  // guest writes to UART TX; transport pumps to the pipe (toward the driver)
  UartWriteReg(U, UART_THR, Ord('H'));
  UartWriteReg(U, UART_THR, Ord('i'));
  T.Pump;
  Check((Length(fake.ToDriver)>=2), 'guest bytes flowed through transport to pipe');

  // driver sends bytes up the pipe; transport pumps them to the guest RX
  fake.DriverSends([Ord('B'),Ord('B'),Ord('S')]);
  T.Pump;
  Check(UartReadReg(U, UART_RBR)=Ord('B'), 'driver byte B reached guest via transport');
  Check(UartReadReg(U, UART_RBR)=Ord('B'), 'driver byte B (2) reached guest');
  Check(UartReadReg(U, UART_RBR)=Ord('S'), 'driver byte S reached guest');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('PIPE+TRANSPORT INTEGRATION VERIFIED');
end.
