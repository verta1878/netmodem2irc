program test_listserv;
{$MODE OBJFPC}{$H+}
uses SysUtils, NM_Listserv;
var ls: TNMListserv; info: TListservInfo; pass,fail: Integer;
procedure Check(cc:Boolean;const nm:string);
begin if cc then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0; fail:=0;

  writeln('== defaults ==');
  ls := TNMListserv.Create;
  Check(ls.Enabled = False, 'disabled by default');
  Check(ls.Info.InternetPort = 23, 'port 23 default');
  Check(ls.IsValid = False, 'not valid without required fields');
  ls.Free;

  writeln('== validation ==');
  ls := TNMListserv.Create;
  info := ls.Info;
  info.BBSName := 'My BBS';
  info.Hostname := 'mybbs.example.com';
  info.IPAddress := '192.168.1.1';
  ls.Info := info;
  Check(ls.IsValid, 'valid with required fields');
  ls.Free;

  writeln('== file roundtrip ==');
  ls := TNMListserv.Create;
  info.BBSName := 'Test BBS';
  info.Software := 'Mystic';
  info.Speed := '56K';
  info.Hostname := 'test.bbs.org';
  info.IPAddress := '10.0.0.1';
  info.InternetPort := 2323;
  info.Comment := 'Running NetModem/32';
  ls.Info := info;
  ls.SaveToFile('/tmp/test_listserv.cnf');
  ls.Free;

  ls := TNMListserv.Create;
  ls.LoadFromFile('/tmp/test_listserv.cnf');
  Check(ls.Info.BBSName = 'Test BBS', 'roundtrip BBSName');
  Check(ls.Info.Software = 'Mystic', 'roundtrip Software');
  Check(ls.Info.Hostname = 'test.bbs.org', 'roundtrip Hostname');
  Check(ls.Info.IPAddress = '10.0.0.1', 'roundtrip IPAddress');
  Check(ls.Info.InternetPort = 2323, 'roundtrip Port');
  Check(ls.Info.Comment = 'Running NetModem/32', 'roundtrip Comment');
  Check(ls.IsValid, 'valid after load');
  ls.Free;

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('LISTSERV - VERIFIED');
end.
