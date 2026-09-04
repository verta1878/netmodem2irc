; ===========================================================================
;  netmodem2irc / netfosdl driver installer  (Inno Setup 5.6.1+)
;  Layout is documented in installer/DRIVER_INSTALL.md — keep the two in sync.
;
;  Before compiling, stage the source files next to this .iss:
;    DOS\NETFOSDL.EXE  DOS\FOSTEST.EXE  DOS\FOSFULL.EXE  DOS\FOSTEST2.EXE
;    Win9x\FOSSIL.VXD                       (from fossil98vxd.zip)
;    Win32\NETMODEM.CPL  Win32\NMServer.exe  Win32\NMConfig.exe
;  Then:  iscc netfosdl.iss
; ===========================================================================

#define AppName    "netmodem2irc FOSSIL Drivers"
#define AppVersion "1.0"
#define AppPub     "FPC264IRC Contributors"

[Setup]
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPub}
DefaultDirName={pf}\netmodem2irc
DefaultGroupName=netmodem2irc
OutputBaseFilename=netfosdl-setup
Compression=lzma2
SolidCompression=yes
; NT-family only for the Windows components; DOS driver is copied for the
; sysop to move to the DOS/PCBoard machine.
MinVersion=0,5.0
LicenseFile=..\docs\LICENSE.TXT

[Types]
Name: "full";   Description: "Full installation"
Name: "dos";    Description: "DOS FOSSIL driver only (for PCBoard)"
Name: "custom"; Description: "Custom"; Flags: iscustom

[Components]
Name: "dos";    Description: "DOS FOSSIL driver (NETFOSDL.EXE)";        Types: full dos custom; Flags: fixed
Name: "dostest";Description: "DOS FOSSIL self-tests";                   Types: full
Name: "win9x";  Description: "Windows 9x/ME ring-0 driver (FOSSIL.VXD)";Types: full;   Check: IsWin9x
Name: "win32";  Description: "Windows NT/2K/XP+ CPL + server";          Types: full;   Check: IsWinNT

[Files]
; --- DOS FOSSIL driver (staged to {app}\DOS for transfer to the BBS box) ---
Source: "DOS\NETFOSDL.EXE";  DestDir: "{app}\DOS"; Components: dos;     Flags: ignoreversion
Source: "DOS\FOSTEST.EXE";   DestDir: "{app}\DOS"; Components: dostest; Flags: ignoreversion
Source: "DOS\FOSFULL.EXE";   DestDir: "{app}\DOS"; Components: dostest; Flags: ignoreversion
Source: "DOS\FOSTEST2.EXE";  DestDir: "{app}\DOS"; Components: dostest; Flags: ignoreversion
Source: "..\installer\DRIVER_INSTALL.md"; DestDir: "{app}\DOS"; DestName: "INSTALL.txt"; Components: dos; Flags: ignoreversion isreadme

; --- Windows 9x/ME VxD (only on 9x; staged from fossil98vxd.zip) ---
Source: "Win9x\FOSSIL.VXD";  DestDir: "{win}\SYSTEM"; Components: win9x; Flags: ignoreversion restartreplace; Check: IsWin9x

; --- Windows NT-family ring-3 components ---
Source: "Win32\NETMODEM.CPL"; DestDir: "{sys}";  Components: win32; Flags: restartreplace uninsrestartdelete; Check: IsWinNT
Source: "Win32\NMServer.exe"; DestDir: "{app}";  Components: win32; Flags: ignoreversion; Check: IsWinNT
Source: "Win32\NMConfig.exe"; DestDir: "{app}";  Components: win32; Flags: ignoreversion; Check: IsWinNT

[INI]
; Register the VxD in SYSTEM.INI [386Enh] on Win9x so Windows loads it.
Filename: "{win}\SYSTEM.INI"; Section: "386Enh"; Key: "device"; String: "FOSSIL.VXD"; Components: win9x; Check: IsWin9x

[Icons]
Name: "{group}\NetModem Config";  Filename: "{app}\NMConfig.exe"; Components: win32
Name: "{group}\Driver Install Guide"; Filename: "{app}\DOS\INSTALL.txt"; Components: dos

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
