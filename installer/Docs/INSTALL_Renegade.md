# Renegade BBS + NetModem/32 — Setup Guide

## Overview

Run Renegade BBS v1.40 as a Telnet BBS using NetModem/32 as
the virtual modem. Renegade is a DOS BBS written in Turbo Pascal
by Cott Lang (1991), actively developed through 2026.

```
Caller (Telnet)
  → NMServer.exe (TCP port 23)
    → FOSSIL driver (ADF)
      → RENEGADE.EXE (COM1, 115200 baud)
```

## Requirements

- Renegade BBS v1.40 (or v1.35+) — from rgbbs.info
- NetModem/32 (netmodem2irc) — NMServer.exe
- DOSBox 0.74+ (to run Renegade on modern OS)
- ADF FOSSIL driver (recommended for DOSBox)

## Directory Structure

```
C:\RG\                      ← Renegade root
├── RENEGADE.EXE               main BBS binary
├── RENEGADE.DAT               system configuration
├── DATA\                      user/message data
├── MENUS\                     menu files (.MNU)
├── TEXT\                      display files (.ANS/.ASC)
├── MSGS\                      message bases
├── TEMP\                      temporary files
├── XFER\                      file transfer area
└── NODE1\                     node 1 work directory

C:\ADF\                     ← FOSSIL driver
└── ADF.COM                    ADF FOSSIL driver
```

## Step-by-Step Setup

### 1. Install Renegade

Download from rgbbs.info and extract to `C:\RG\`.
Run `RENEGADE.EXE` once in local mode to create the
initial configuration files.

### 2. Configure Renegade for FOSSIL

In Renegade's System Configuration (run without -Q flag):

```
System Config → Modem Configuration:
  Modem type:          FOSSIL
  COM port:            1 (COM1)
  Baud rate:           115200
  Init string:         ATZ|
  Answer string:       ATA|~~
  Hangup string:       ATH0|
  Offhook string:      ATH1|
```

The `ATA|~~` answer string is important — Renegade needs the
delay (`~~`) after ATA to properly establish the connection.

### 3. Set Up DOSBox

Create `renegade.conf`:
```ini
[sdl]
output=surface
fullscreen=false

[cpu]
cycles=max

[serial]
# DOSBox virtual modem — listens for Telnet directly
serial1=modem listenport:23

# Or connect to NMServer:
# serial1=nullmodem server:localhost port:2323

[autoexec]
mount C C:\
C:
cd ADF
LH ADF COM1 3F8 4 115200 8192 8192 8
cd \RG
RENEGADE -N1 -Q -B115200
```

Command line flags:
- `-N1` — node number 1
- `-Q` — quiet mode (wait for call, no local console)
- `-B115200` — baud rate

### 4. Start NMServer

```
NMServer.exe
```

Or under Linux:
```bash
xvfb-run -a wine NMServer.exe
```

### 5. Start Renegade in DOSBox

```
dosbox -conf renegade.conf
```

Or under Linux:
```bash
xvfb-run -a dosbox -conf renegade.conf
```

### 6. Test

```
telnet your-server-ip 23
```

You should see Renegade's ANSI login screen.

## Multinode Setup

Renegade supports multiple nodes. Each node needs its own
DOSBox instance and work directory.

### Create Node Directories
```
mkdir C:\RG\NODE1
mkdir C:\RG\NODE2
mkdir C:\RG\NODE3
mkdir C:\RG\NODE4
```

### DOSBox Config Per Node

`renegade-node1.conf`:
```ini
[serial]
serial1=modem listenport:23001

[autoexec]
mount C C:\
C:
cd ADF
LH ADF COM1 3F8 4 115200 8192 8192 8
cd \RG
RENEGADE -N1 -Q -B115200
```

`renegade-node2.conf`:
```ini
[serial]
serial1=modem listenport:23002

[autoexec]
mount C C:\
C:
cd ADF
LH ADF COM1 3F8 4 115200 8192 8192 8
cd \RG
RENEGADE -N2 -Q -B115200
```

### With NMServer (All Nodes on One Port)

NMServer handles multinode on a single Telnet port (port 23)
and routes each caller to an available node automatically.
This is cleaner than separate ports per node.

```
NMServer port 23 → Node 1 (COM1) → DOSBox → Renegade -N1
                  → Node 2 (COM2) → DOSBox → Renegade -N2
                  → Node 3 (COM3) → DOSBox → Renegade -N3
```

## Renegade + NetModem/32 Under Linux (Docker Style)

Based on jgoerzen/docker-bbs-renegade, adapted for NetModem/32:

```bash
#!/bin/bash
# start-renegade.sh — run Renegade BBS on Linux

# Start virtual display
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99

# Start NMServer (virtual modem)
wine /opt/netmodem/NMServer.exe &

# Start Renegade in DOSBox (per node)
for NODE in 1 2 3 4; do
  dosbox -conf /opt/renegade/node${NODE}.conf &
done

echo "Renegade BBS running on port 23"
echo "Connect: telnet $(hostname) 23"
wait
```

## Renegade-Specific Notes

### Answer String
Renegade v1.35+ needs `ATA|~~` as the answer string.
The `~~` adds a 1-second delay after ATA. Without it,
Renegade drops the connection immediately.

### WFC Screen
In `-Q` (quiet) mode, Renegade skips the Waiting For Call
screen and goes straight to listening. This is correct for
a virtual modem setup — there's no local console to watch.

To access the local console for configuration, run without `-Q`:
```
RENEGADE -N1 -B115200
```

### Lightbar Menus (v1.40)
Renegade v1.40 added lightbar file listings, message reading,
and node viewer. These work through the virtual modem — the
ANSI codes pass through NetModem/32 unchanged.

### File Transfers
Zmodem works through NetModem/32. Renegade's built-in Zmodem
(or external DSZ/FDSZ) transfers files through the virtual
modem just like a real serial connection.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "No FOSSIL detected" | Load ADF before starting Renegade |
| Drops on answer | Use answer string `ATA\|~~` (with delay) |
| No login screen | Check `-Q` flag and COM port config |
| Garbled ANSI | Caller needs ANSI-capable terminal (SyncTERM, mterm) |
| Multi-node conflict | Each node needs its own TEMP/NODE directory |
| Hangs at "Waiting" | Check DOSBox serial config |
| Old menus don't work | v1.40: use Menu Import to convert old .MNU files |

## Credits

- Cott Lang — original Renegade BBS (1991)
- T.J. McMillen — Renegade v1.25-v1.40 (2020-2026)
- Lee Woodridge — Renegade v1.30-v1.33 contributions
- verta1878 — netmodem2irc (virtual modem)
- jgoerzen — docker-bbs-renegade (Docker reference)
