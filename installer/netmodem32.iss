; ===========================================================================
;  NetModem/32 — complete product installer  (Inno Setup 5.6.1+)
;
;  Installs the full NetModem/32 virtual-modem product:
;    - Win32 app:  NMServer.exe, NMConfig.exe, NETMODEM.CPL
;    - DOS FOSSIL driver:  NETFOSDL.EXE (+ self-tests)
;    - Win9x ring-0 driver:  FOSSIL.VXD
;    - User documentation
;
;  Layout / per-file destinations are documented in DRIVER_INSTALL.md.
;
;  Before compiling, stage the source files next to this .iss:
;    Win32\NMServer.exe  Win32\NMConfig.exe  Win32\NETMODEM.CPL
;    DOS\NETFOSDL.EXE  DOS\FOSTEST.EXE  DOS\FOSFULL.EXE  DOS\FOSTEST2.EXE
;    Win9x\FOSSIL.VXD                        (from fossil98vxd.zip)
;    Docs\*.md  Docs\*.txt
;    mainicon.ico
;  Then:  iscc netmodem32.iss
; ===========================================================================

#define AppName    "NetModem/32"
#define AppVersion "2.0"
#define AppPub     "FPC264IRC Contributors"
#define AppURL     "https://github.com/verta1878/netmodem2irc"
#define SrvExe     "NMServer.exe"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPub}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
DefaultDirName={pf}\NetModem
DefaultGroupName=NetModem32
OutputBaseFilename=netmodem32_setup
Compression=lzma2/max
SolidCompression=yes
MinVersion=0,5.0
LicenseFile=Docs\LICENSE.TXT
SetupIconFile=mainicon.ico
UninstallDisplayIcon={app}\{#SrvExe}
UninstallDisplayName={#AppName} {#AppVersion}

[Types]
Name: "full";    Description: "Full installation (Win32 app + drivers + docs)"
Name: "app";     Description: "Win32 application only (NT/2000/XP+)"
Name: "dosdrv";  Description: "DOS FOSSIL driver only (for a DOS BBS box)"
Name: "custom";  Description: "Custom"; Flags: iscustom

[Components]
Name: "app";     Description: "NetModem/32 server, config, and control panel"; Types: full app custom; Check: IsWinNT
Name: "dos";     Description: "DOS FOSSIL driver (NETFOSDL.EXE)";               Types: full dosdrv custom
Name: "dos/test";Description: "DOS FOSSIL self-tests";                          Types: full
Name: "win9x";   Description: "Windows 9x/ME ring-0 driver (FOSSIL.VXD)";       Types: full; Check: IsWin9x
Name: "docs";    Description: "Documentation and BBS setup guides";             Types: full app custom

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon for NMServer"; Components: app; Flags: unchecked
Name: "openport";    Description: "Reminder: open Telnet port 23 on your firewall"; Components: app; Flags: unchecked

[Files]
; --- Win32 application (NT-family) ---
Source: "Win32\NMServer.exe";  DestDir: "{app}"; Components: app; Flags: ignoreversion; Check: IsWinNT
Source: "Win32\NMConfig.exe";  DestDir: "{app}"; Components: app; Flags: ignoreversion; Check: IsWinNT
Source: "Win32\NETMODEM.CPL";  DestDir: "{sys}"; Components: app; Flags: restartreplace uninsrestartdelete; Check: IsWinNT

; --- DOS FOSSIL driver (staged under {app}\DOS for transfer to the BBS box) ---
Source: "DOS\NETFOSDL.EXE";    DestDir: "{app}\DOS"; Components: dos;      Flags: ignoreversion
Source: "DOS\FOSTEST.EXE";     DestDir: "{app}\DOS"; Components: dos/test; Flags: ignoreversion
Source: "DOS\FOSFULL.EXE";     DestDir: "{app}\DOS"; Components: dos/test; Flags: ignoreversion
Source: "DOS\FOSTEST2.EXE";    DestDir: "{app}\DOS"; Components: dos/test; Flags: ignoreversion

; --- Windows 9x/ME VxD (only on 9x) ---
Source: "Win9x\FOSSIL.VXD";    DestDir: "{win}\SYSTEM"; Components: win9x; Flags: ignoreversion restartreplace; Check: IsWin9x

; --- Documentation ---
Source: "Docs\INSTALL.md";          DestDir: "{app}\Docs"; Components: docs; Flags: ignoreversion isreadme
Source: "Docs\INSTALL_PCBoard.md";  DestDir: "{app}\Docs"; Components: docs; Flags: ignoreversion
Source: "Docs\INSTALL_Renegade.md"; DestDir: "{app}\Docs"; Components: docs; Flags: ignoreversion
Source: "Docs\DEBUGGER_GUIDE.md";   DestDir: "{app}\Docs"; Components: docs; Flags: ignoreversion
Source: "Docs\FOSSIL_FSC0015_Reference.txt"; DestDir: "{app}\Docs"; Components: docs; Flags: ignoreversion
Source: "Docs\README.md";           DestDir: "{app}\Docs"; Components: docs; Flags: ignoreversion
Source: "Docs\LICENSES.md";         DestDir: "{app}\Docs"; Components: docs; Flags: ignoreversion
Source: "DRIVER_INSTALL.md";        DestDir: "{app}\DOS";  Components: dos;  DestName: "DRIVER_INSTALL.txt"; Flags: ignoreversion

[Registry]
; Product defaults per docs/INSTALL.md (Telnet port + node count).
Root: HKLM; Subkey: "SOFTWARE\NetModem32"; ValueType: dword; ValueName: "TelnetPort"; ValueData: "23"; Components: app; Flags: createvalueifdoesntexist uninsdeletevalue
Root: HKLM; Subkey: "SOFTWARE\NetModem32"; ValueType: dword; ValueName: "Nodes";      ValueData: "4";  Components: app; Flags: createvalueifdoesntexist uninsdeletevalue
Root: HKLM; Subkey: "SOFTWARE\NetModem32"; ValueType: string; ValueName: "InstallDir"; ValueData: "{app}"; Components: app; Flags: uninsdeletekey

[INI]
; Register the VxD in SYSTEM.INI [386Enh] on Win9x.
Filename: "{win}\SYSTEM.INI"; Section: "386Enh"; Key: "device"; String: "FOSSIL.VXD"; Components: win9x; Check: IsWin9x

[Icons]
Name: "{group}\NetModem Server";      Filename: "{app}\{#SrvExe}";    Components: app
Name: "{group}\NetModem Config";      Filename: "{app}\NMConfig.exe"; Components: app
Name: "{group}\Installation Guide";   Filename: "{app}\Docs\INSTALL.md"; Components: docs
Name: "{group}\DOS Driver Guide";     Filename: "{app}\DOS\DRIVER_INSTALL.txt"; Components: dos
Name: "{group}\Uninstall NetModem32"; Filename: "{uninstallexe}"
Name: "{commondesktop}\NetModem Server"; Filename: "{app}\{#SrvExe}"; Components: app; Tasks: desktopicon

[Run]
Filename: "{app}\{#SrvExe}"; Description: "Launch NetModem Server now"; Components: app; Flags: nowait postinstall skipifsilent

[Code]
function IsWin9x: Boolean;
var V: TWindowsVersion;
begin
  GetWindowsVersionEx(V);
  Result := not V.NTPlatform;   { True on 95/98/ME }
end;

function IsWinNT: Boolean;
var V: TWindowsVersion;
begin
  GetWindowsVersionEx(V);
  Result := V.NTPlatform;       { True on NT/2K/XP+ }
end;
