# netmodem2irc / netfosdl — Driver Installer Layout

> **License:** mixed — revival work (server/config/CPL/netfosdl) is GPLv3+;
> Dedrick Allen's original NetModem/32 material (FOSSIL.VXD) stays GPLv2.
> The installer shows both; see docs/LICENSES.md for the per-component split.

This document maps every driver file to its destination per platform, for
use by the Inno Setup installer (`installer/netfosdl.iss`). It is the
source of truth for "which file goes where."

## Platform matrix

| Platform            | Driver file        | Kind                     | Installs to (default)                    |
|---------------------|--------------------|--------------------------|------------------------------------------|
| DOS / PCBoard       | `NETFOSDL.EXE`     | Real-mode FOSSIL TSR     | `{app}\DOS\NETFOSDL.EXE`                 |
| DOS (tests)         | `FOSTEST.EXE` etc. | FOSSIL self-tests        | `{app}\DOS\` (optional component)        |
| Windows 9x/ME       | `FOSSIL.VXD`       | Ring-0 virtual FOSSIL    | `%WINDIR%\SYSTEM\FOSSIL.VXD`             |
| Windows NT/2K/XP+   | `NETMODEM.CPL`     | Control-panel applet     | `%WINDIR%\SYSTEM32\NETMODEM.CPL`         |
| Windows NT/2K/XP+   | `NMServer.exe`     | COM<->TCP server         | `{app}\NMServer.exe`                     |
| Windows NT/2K/XP+   | `NMConfig.exe`     | Configuration UI         | `{app}\NMConfig.exe`                     |

## DOS driver — usage (PCBoard target)

`NETFOSDL.EXE` is a TSR that hooks INT 14h and installs a UART receive
ISR. It MUST load before PCBoard and before any door/mailer that opens
the FOSSIL.

```
netfosdl /port:N        load on COM port N (1-4)
netfosdl /baud:RATE     initial baud rate (default 9600)
netfosdl /irq:N         override IRQ (default: COM1/3=IRQ4, COM2/4=IRQ3)
netfosdl /u             unload from memory
```
X00-compatible short forms: `/P:N` = `/port:N`, `/B:N` = `/baud:N`.

Typical PCBoard load line (AUTOEXEC.BAT or the BBS start batch), placed
BEFORE the line that launches PCBoard:
```
C:\PCB\DOS\NETFOSDL.EXE /port:1 /baud:38400
```
On shutdown, unload with `NETFOSDL /u` after PCBoard exits.

### Load order (important)
1. `NETFOSDL.EXE /port:...`   (this driver — hooks INT 14h)
2. PCBoard / door / mailer     (opens the FOSSIL on top of it)
NETFOSDL must be resident first, or callers fall through to the BIOS
INT 14h and lose the ring buffer + flow control.

## Windows 9x/ME — FOSSIL.VXD

`FOSSIL.VXD` is NOT in this repo — it ships from the separate
`fossil98vxd.zip` package (the recovered ring-0 driver). When bundling the
Win9x component, copy `FOSSIL.VXD` from that package into the installer's
`Win9x\` source folder before compiling the `.iss`. It loads via a
`device=` line the installer adds to SYSTEM.INI `[386Enh]`:
```
device=FOSSIL.VXD
```

## Windows NT/2K/XP+ — CPL + server

`NETMODEM.CPL` is the Control Panel applet; `NMServer.exe` /
`NMConfig.exe` are the COM<->TCP bridge and its config UI. These are the
ring-3 path and do not require the VxD.

## Integrity
After install, users can verify the shipped files against the repo
manifests:
```
md5sum -c MD5SUMS.txt        (or)   sha256sum -c SHA256SUMS.txt
```

## Building the installer

Prebuilt: `installer/Output/netfosdl-setup.exe` (Inno Setup 5.6.1).

To rebuild from `netfosdl.iss` you need the Inno Setup command-line
compiler `ISCC.exe` (5.6.1+). On Windows, install Inno Setup and run:
```
iscc netfosdl.iss
```
On Linux this project builds it under Wine (32-bit): install `wine32:i386`
+ `libwine:i386`, unpack Inno with `innoextract`, and run
`wine ISCC.exe netfosdl.iss`. Stage the platform source folders (DOS\,
Win9x\, Win32\) next to the .iss first, as listed at the top of the
script. Output lands in `Output\netfosdl-setup.exe`.
