program NetModemConfig;
{ NetModem/32 Configuration — Lazarus revival.
  Rebuilt from NETMODEM.CPL (6 Delphi forms). GPLv2.
  Reads/writes HKLM\Software\Allen Software\NetModem (ComportConfig, IRQ),
  then calls IOCTL 03 (reload config) so no reboot is needed. }
{$MODE OBJFPC}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms,
  ConfigMain;
begin
  RequireDerivedFormResource := True;
  Application.Title := 'NetModem/32 Configuration';
  Application.Initialize;
  Application.CreateForm(TfrmConfig, frmConfig);
  Application.Run;
end.
