program test_at_dial_port;
{$MODE OBJFPC}{$H+}
{ ParseDial port range: a port past 65535 must NOT silently wrap (Word(70000)=4464
  would connect to the wrong port). Out-of-range -> default. The qwkpoll class of
  bug applied to an untrusted dial string. }
uses SysUtils, NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand;
var
  m: TATModem; u: TUart16550; pass,fail: Integer;
  host: string; port: Word;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;
  UartReset(u);
  m := TATModem.Create(@u, nil);
  m.DefaultPort := 23;   // known default to detect fallback

  writeln('== valid ports parse correctly ==');
  Check(m.TestParseDial('bbs.example.com:6667', host, port) and (port=6667) and (host='bbs.example.com'), 'host:6667 -> 6667');
  Check(m.TestParseDial('host:1', host, port) and (port=1), 'port 1 (min) ok');
  Check(m.TestParseDial('host:65535', host, port) and (port=65535), 'port 65535 (max) ok');
  Check(m.TestParseDial('host', host, port) and (port=23), 'no port -> default 23');

  writeln('== GHOST: port > 65535 must NOT wrap silently ==');
  m.TestParseDial('host:70000', host, port);
  Check(port <> 4464, 'port 70000 did NOT wrap to 4464 (the ghost)');
  Check(port = 23, 'port 70000 -> default 23 (rejected, not wrapped)');

  writeln('== other out-of-range / garbage -> default, never wrapped ==');
  m.TestParseDial('host:0', host, port);
  Check(port = 23, 'port 0 -> default (0 is invalid)');
  m.TestParseDial('host:99999', host, port);
  Check(port = 23, 'port 99999 -> default');
  m.TestParseDial('host:abc', host, port);
  Check(port = 23, 'non-numeric port -> default');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('AT DIAL PORT RANGE - VERIFIED');
  m.Free;
end.
