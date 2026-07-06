program NetModemServer;
{ NetModem/32 Telnet Server — Lazarus revival.
  GPLv2. Original driver (c) 1997-2001 Dedrick Allen / Allen Software. }
{$MODE OBJFPC}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms,
  MainForm, SplashForm;
begin
  RequireDerivedFormResource := True;
  Application.Title := 'NetModem/32 Server';
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
