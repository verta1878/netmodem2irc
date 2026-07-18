program test_atcommand;
{$MODE OBJFPC}{$H+}
uses SysUtils, NM_UART16550, NetTransport, NM_ATCommand;

type
  TFakeLink = class(TInterfacedObject, ISocketLink)
  public
    Connected: Boolean; ConnectHost: string; ConnectPort: Word;
    function Connect(const AHost: string; APort: Word): TLinkResult;
    function Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
    function Recv(var Buf; Len: Integer; out Got: Integer): TLinkResult;
    procedure Close; function IsConnected: Boolean;
  end;
function TFakeLink.Connect(const AHost:string;APort:Word):TLinkResult;
begin ConnectHost:=AHost; ConnectPort:=APort; Connected:=True; Result:=lrOk; end;
function TFakeLink.Send(const Buf;Len:Integer;out Sent:Integer):TLinkResult;
begin Sent:=Len; Result:=lrOk; end;
function TFakeLink.Recv(var Buf;Len:Integer;out Got:Integer):TLinkResult;
begin Got:=0; Result:=lrWouldBlock; end;
procedure TFakeLink.Close; begin Connected:=False; end;
function TFakeLink.IsConnected:Boolean; begin Result:=Connected; end;

var
  U: TUart16550; link: TFakeLink; T: TNetTransport; M: TATModem;
  pass, fail: Integer;

procedure Check(cond: Boolean; const name: string);
begin
  if cond then begin Inc(pass); writeln('  PASS: ',name); end
  else begin Inc(fail); writeln('  FAIL: ',name); end;
end;

{ feed a full AT line (adds CR) }
procedure Type_(const s: string);
var i: Integer;
begin
  for i:=1 to Length(s) do M.ATFeed(Byte(s[i]));
  M.ATFeed(13);
end;

{ read everything currently in the guest RX ring as a string }
function GuestSees: string;
begin
  Result := '';
  while UartReadReg(U, UART_RBR) <> 0 do ; // can't distinguish; use ring directly
end;

function DrainRX: string;
var b: Byte;
begin
  Result := '';
  while U.RX.Count > 0 do begin RingGet(U.RX, b); Result := Result + Chr(b); end;
end;

begin
  pass:=0; fail:=0;
  UartReset(U);
  link := TFakeLink.Create;
  T := TNetTransport.Create(@U, link);
  M := TATModem.Create(@U, T);

  writeln('== bare AT -> OK ==');
  Type_('AT');
  Check(Pos('OK', DrainRX) > 0, 'AT returns OK');

  writeln('== ATDT host:port dials via transport -> CONNECT + online ==');
  Type_('ATDT bbs.example.com:2323');
  Check(link.Connected, 'transport opened a connection');
  Check(link.ConnectHost = 'bbs.example.com', 'dialed correct host');
  Check(link.ConnectPort = 2323, 'dialed correct port');
  Check(Pos('CONNECT', DrainRX) > 0, 'emitted CONNECT');
  Check(M.Mode = mmOnline, 'switched to online mode');
  Check(U.Online, 'carrier up (DCD)');

  writeln('== online mode: ATFeed does not parse (bytes belong to transport) ==');
  M.ATFeed(Byte('A'));  // in online mode this should be ignored by AT layer
  Check(U.RX.Count = 0, 'no echo/parse in online mode');

  writeln('== hang up via HangUp -> carrier drops ==');
  T.HangUp;
  Check(not U.Online, 'carrier dropped after hangup');

  writeln('== default port (no :port) uses 23 ==');
  UartReset(U); DrainRX;
  link.Connected := False;
  T := TNetTransport.Create(@U, link);
  M := TATModem.Create(@U, T);
  Type_('ATDT my.bbs.org');
  Check(link.ConnectPort = 23, 'default telnet port 23 used');

  writeln('== empty dial (ATD) -> NO DIAL TONE ==');
  UartReset(U); DrainRX;
  T := TNetTransport.Create(@U, link);
  M := TATModem.Create(@U, T);
  Type_('ATD');
  Check(Pos('NO DIAL TONE', DrainRX) > 0, 'empty dial -> NO DIAL TONE');

  writeln('== non-AT line -> ERROR ==');
  UartReset(U); DrainRX;
  M := TATModem.Create(@U, T);
  Type_('XYZ');
  Check(Pos('ERROR', DrainRX) > 0, 'garbage -> ERROR');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('AT COMMAND LAYER VERIFIED');
end.
