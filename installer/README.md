# NetModem/32 Installer

Inno Setup script for creating a Windows installer.

## Requirements

- Inno Setup 5.5+ (for Win98/ME support) or 6.x (Win7+)
- Download: https://jrsoftware.org/isinfo.php

## Building the installer

1. Build Win32 binaries first: `FPCIRC=/path/to/fpc264irc ./build.sh win32`
2. Open `installer/netmodem2irc.iss` in Inno Setup Compiler
3. Press Compile — produces `netmodem2irc-setup.exe`

## What it installs

- `NMServer.exe` — Telnet server GUI → Program Files\NetModem32
- `NMConfig.exe` — Config app → Program Files\NetModem32
- `NETMODEM.CPL` — Control Panel applet → System32
- `netfossl.exe` — DOS FOSSIL bridge → Program Files\NetModem32\dos
- Start Menu shortcuts + optional desktop icon
- Registry defaults (HKLM\Software\Allen Software\NetModem)

## Uninstall

Removes all files, Start Menu shortcuts, desktop icon, and NETMODEM.CPL
from System32. Registry key is removed if empty.
