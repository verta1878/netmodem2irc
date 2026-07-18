program NMServer;
{ NetModem/32 Telnet Server — Lazarus revival (netmodem2irc).
  GPLv2. Original driver (c) 1997-2001 Dedrick Allen / Allen Software.
  The server does NOT read config — the VxD driver reads the registry.
  The server opens the driver, registers its window, and reacts to CM_*
  messages (connect/disconnect/break). The CPL writes the registry. }
{$MODE OBJFPC}{$H+}
{$R NMServer.res}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms,
  { --- netmodem2irc engine --- }
  NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node,
  NM_NamedPipeLink, NM_SeamProtocol, NM_ServerBridge,
  {$IFDEF HAS_SYNAPSE}NM_SynapseLink,{$ENDIF}
  { --- driver interface --- }
  NMVxD,
  { --- GUI --- }
  MainForm, SplashForm;
begin
  RequireDerivedFormResource := True;
  Application.Title := 'NetModem/32 Server';
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
