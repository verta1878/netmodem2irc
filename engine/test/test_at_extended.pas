program test_at_extended;
{$MODE OBJFPC}{$H+}
{ Test the extended &-commands the original NetModem documented (ATCOMNDS.TXT). }
uses SysUtils, NM_UART16550, NetTransport, NM_ATCommand;
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
  U: TUart16550; T: TNetTransport; M: TATModem; link: ISocketLink;
  pass, fail: Integer;

procedure Check(c:Boolean;const n:string);
begin if c then begin Inc(pass);writeln('  PASS: ',n);end else begin Inc(fail);writeln('  FAIL: ',n);end;end;

{ feed an AT line + CR, then read what the modem emitted back to the guest }
function SendAT(const cmd: string): string;
var i: Integer; b: Byte;
begin
  for i := 1 to Length(cmd) do M.ATFeed(Ord(cmd[i]));
  M.ATFeed(13);
  Result := '';
  while RingGet(U.RX, b) do
    if b >= 32 then Result := Result + Chr(b);
end;

begin
  pass:=0; fail:=0;
  UartReset(U);
  link := TFakeLink.Create;
  T := TNetTransport.Create(@U, link);
  M := TATModem.Create(@U, T);
  M.DefaultPort := 23;

  writeln('== a realistic BBS init string must return OK ==');
  Check(Pos('OK', SendAT('AT&C1&D2')) > 0, 'AT&C1&D2 -> OK');
  Check(Pos('OK', SendAT('ATE0&C1&D2&K1')) > 0, 'ATE0&C1&D2&K1 -> OK');
  Check(Pos('OK', SendAT('AT&F')) > 0, 'AT&F (factory) -> OK');

  writeln('== individual & commands accepted ==');
  Check(Pos('OK', SendAT('AT&C0')) > 0, 'AT&C0 -> OK');
  Check(Pos('OK', SendAT('AT&D2')) > 0, 'AT&D2 -> OK');
  Check(Pos('OK', SendAT('AT&I1')) > 0, 'AT&I1 -> OK');
  Check(Pos('OK', SendAT('AT&R2')) > 0, 'AT&R2 -> OK');
  Check(Pos('OK', SendAT('AT&S0')) > 0, 'AT&S0 -> OK');
  Check(Pos('OK', SendAT('AT&Y1')) > 0, 'AT&Y1 -> OK');

  writeln('== combined with standard commands ==');
  Check(Pos('OK', SendAT('ATZ')) > 0, 'ATZ -> OK');
  Check(Pos('OK', SendAT('ATE1Q0V1&C1')) > 0, 'ATE1Q0V1&C1 -> OK');

  writeln('== bad command still errors ==');
  Check(Pos('ERROR', SendAT('XYZ')) > 0, 'non-AT line -> ERROR');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('EXTENDED AT COMMANDS VERIFIED');
end.
