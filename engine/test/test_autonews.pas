program test_autonews;
{$MODE OBJFPC}{$H+}
uses SysUtils, NM_AutoNews;
var
  an: TNMAutoNews;
  pass, fail: Integer;
  F: TextFile;
procedure Check(cc:Boolean;const nm:string);
begin if cc then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0; fail:=0;

  writeln('== defaults ==');
  an := TNMAutoNews.Create;
  Check(an.Enabled = False, 'disabled by default');
  Check(an.IntervalMin = 60, 'interval 60 min');
  Check(an.NewsFile = 'NETMODEM.NEWS', 'default news file');
  Check(an.ShouldSend = False, 'should not send when disabled');
  an.Free;

  writeln('== should send logic ==');
  an := TNMAutoNews.Create;
  an.Enabled := True;
  an.IntervalMin := 1;
  Check(an.ShouldSend, 'should send on first check');
  an.MarkSent;
  Check(not an.ShouldSend, 'should not send immediately after');
  an.Free;

  writeln('== load news text ==');
  AssignFile(F, '/tmp/test_news.txt');
  Rewrite(F);
  WriteLn(F, 'Welcome to NetModem/32!');
  WriteLn(F, 'Server is online.');
  CloseFile(F);

  an := TNMAutoNews.Create;
  an.NewsFile := '/tmp/test_news.txt';
  Check(an.LoadNewsText <> '', 'loaded news text');
  Check(Pos('Welcome', an.LoadNewsText) > 0, 'news contains welcome');
  an.Free;

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('AUTONEWS - VERIFIED');
end.
