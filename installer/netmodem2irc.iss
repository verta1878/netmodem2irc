[Setup]
AppName=NetModem/32
AppVersion=2.0-dev
AppPublisher=Allen Software
DefaultDirName={pf}\NetModem
DefaultGroupName=NetModem/32
OutputBaseFilename=net32_20setup
OutputDir=.
Compression=zip
DisableWelcomePage=no
DEPCompatible=no
ASLRCompatible=no
TerminalServicesAware=no

[Files]
Source: "ISCC.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "Default.isl"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\NetModem Server"; Filename: "{app}\ISCC.exe"
Name: "{group}\Uninstall NetModem"; Filename: "{uninstallexe}"
