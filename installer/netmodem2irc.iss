; NetModem/32 — Inno Setup installer script
; Requires: Inno Setup 5.5+ (for Win98 support) or 6.x (Win7+)
; Build: Open this file in Inno Setup Compiler, press Compile

[Setup]
AppName=NetModem/32
AppVersion=2.0
AppVerName=NetModem/32 v2.0
AppPublisher=Allen Software / netmodem2irc
AppPublisherURL=https://github.com/verta1878/netmodem2irc
DefaultDirName={pf}\NetModem32
DefaultGroupName=NetModem/32
OutputBaseFilename=netmodem2irc-setup
OutputDir=.
Compression=lzma2
SolidCompression=yes
LicenseFile=..\LICENSE
MinVersion=4.0
; Win95/98/ME/NT4/2000/XP/Vista/7/8/10/11

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Server
Source: "..\out\win32\NMServer.exe"; DestDir: "{app}"; Flags: ignoreversion
; Config
Source: "..\out\win32\NMConfig.exe"; DestDir: "{app}"; Flags: ignoreversion
; Original CPL
Source: "..\history\NETMODEM.CPL"; DestDir: "{sys}"; Flags: ignoreversion
; DOS FOSSIL bridge
Source: "..\dos\bin\netfossl.exe"; DestDir: "{app}\dos"; Flags: ignoreversion
; Documentation
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\docs\netmodem2irc_registry.md"; DestDir: "{app}\docs"; Flags: ignoreversion

[Icons]
Name: "{group}\NetModem/32 Server"; Filename: "{app}\NMServer.exe"
Name: "{group}\NetModem/32 Config"; Filename: "{app}\NMConfig.exe"
Name: "{group}\Control Panel Config"; Filename: "control.exe"; Parameters: "{sys}\NETMODEM.CPL"
Name: "{group}\Uninstall NetModem/32"; Filename: "{uninstallexe}"
Name: "{commondesktop}\NetModem/32 Server"; Filename: "{app}\NMServer.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Registry]
; Write factory defaults if no config exists
Root: HKLM; Subkey: "Software\Allen Software\NetModem"; Flags: uninsdeletekeyifempty
Root: HKLM; Subkey: "Software\Allen Software\NetModem"; ValueType: dword; ValueName: "IRQ"; ValueData: "0"; Flags: createvalueifdoesntexist

[Run]
Filename: "{app}\NMServer.exe"; Description: "Launch NetModem/32 Server"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: files; Name: "{sys}\NETMODEM.CPL"

[Code]
// Write default ComportConfig on first install if not present
procedure CurStepChanged(CurStep: TSetupStep);
var
  Exists: Boolean;
begin
  if CurStep = ssPostInstall then
  begin
    Exists := RegValueExists(HKEY_LOCAL_MACHINE,
      'Software\Allen Software\NetModem', 'ComportConfig');
    if not Exists then
    begin
      // NMConfig will write defaults on first run
      Log('No ComportConfig found — defaults will be written on first run.');
    end;
  end;
end;
