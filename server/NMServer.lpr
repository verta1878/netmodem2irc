program NMServer;
{ NetModem/32 Telnet Server — Lazarus revival (netmodem2irc).
  GPLv2. Original driver (c) 1997-2001 Dedrick Allen / Allen Software.
  Engine integrated: see docs/netmodem2irc_M1_COMPLETE.md for MainForm wiring. }
{$MODE OBJFPC}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms,
  { --- netmodem2irc engine (../engine) --- }
  NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node,
  NM_NamedPipeLink, NM_SeamProtocol, NM_ServerBridge,
  {$IFDEF HAS_SYNAPSE}NM_SynapseLink,{$ENDIF}
  { --- driver interface (../common) --- }
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
