; ===========================================================================
; netmodem2irc — Inno Setup installer script
; Packages NMServer.exe + NMConfig.exe + NETMODEM.CPL + docs
; ===========================================================================

[Setup]
AppName=NetModem/32
AppVersion=2.0
AppPublisher=netmodem2irc project
AppPublisherURL=https://github.com/verta1878/netmodem2irc
AppSupportURL=https://github.com/verta1878/netmodem2irc/issues
DefaultDirName={pf}\NetModem
DefaultGroupName=NetModem/32
OutputBaseFilename=netmodem32_setup
OutputDir=..\out\i386
Compression=lzma
SolidCompression=yes
DisableWelcomePage=no
LicenseFile=..\LICENSE
ArchitecturesAllowed=x86 x64
MinVersion=5.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Server
Source: "..\out\i386\NMServer.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\out\i386\NMConfig.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\out\i386\NETMODEM.CPL"; DestDir: "{app}"; Flags: ignoreversion

; Documentation
Source: "..\README.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "..\ROADMAP.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\docs\DEBUGGER_GUIDE.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "..\docs\R42_com0com_NT_path.md"; DestDir: "{app}\docs"; Flags: ignoreversion

; DOS FOSSIL driver (optional component)
Source: "..\dos\driver\*.pas"; DestDir: "{app}\dos"; Flags: ignoreversion; Components: dos
Source: "..\dos\driver\SERIAL_README.md"; DestDir: "{app}\dos"; Flags: ignoreversion; Components: dos

[Components]
Name: "main"; Description: "NetModem/32 Server"; Types: full compact custom; Flags: fixed
Name: "docs"; Description: "Documentation"; Types: full
Name: "dos"; Description: "DOS FOSSIL driver source"; Types: full
Name: "cpl"; Description: "Control Panel applet"; Types: full compact

[Icons]
Name: "{group}\NetModem Server"; Filename: "{app}\NMServer.exe"
Name: "{group}\NetModem Config"; Filename: "{app}\NMConfig.exe"
Name: "{group}\Documentation"; Filename: "{app}\docs"
Name: "{group}\Uninstall NetModem"; Filename: "{uninstallexe}"
Name: "{commondesktop}\NetModem Server"; Filename: "{app}\NMServer.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"

[Registry]
Root: HKLM; Subkey: "SOFTWARE\NetModem32"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\NetModem32"; ValueType: string; ValueName: "Version"; ValueData: "2.0"
Root: HKLM; Subkey: "SOFTWARE\NetModem32"; ValueType: dword; ValueName: "TelnetPort"; ValueData: "23"
Root: HKLM; Subkey: "SOFTWARE\NetModem32"; ValueType: dword; ValueName: "Nodes"; ValueData: "4"

[Run]
Filename: "{app}\NMServer.exe"; Description: "Launch NetModem Server"; Flags: nowait postinstall skipifsilent

