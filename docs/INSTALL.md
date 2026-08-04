# NetModem/32 — Installation Guide

## What Is NetModem/32?

NetModem/32 is a virtual modem. It lets DOS BBS software (PCBoard,
Renegade, Mystic, etc.) accept Telnet callers over TCP/IP — no
physical modem or serial port needed.

Your BBS software talks FOSSIL (the standard DOS modem API).
NetModem/32 translates that to TCP/IP. Callers connect with any
Telnet client and the BBS thinks they're calling on a real modem.

```
Caller (Telnet client)
  │
  ▼
NetModem/32 — NMServer.exe (listens on TCP port)
  │
  ▼
FOSSIL driver (virtual COM port)
  │
  ▼
Your BBS software (PCBoard, Renegade, Mystic, etc.)
```

## Requirements

- Windows XP/Vista/7/10/11 (or Linux via Wine + xvfb-run)
- Your BBS software (DOS or Win32)
- DOSBox (if running DOS BBS software on modern Windows/Linux)
- A Telnet port open on your firewall (default: port 23)

## Installation

### Option A: Run the Installer

```
netmodem32_setup.exe
```

Installs to `C:\Program Files\NetModem\`:
- NMServer.exe — the virtual modem server
- NMConfig.exe — configuration tool
- NETMODEM.CPL — control panel applet

### Option B: Manual Install

Copy these files to any directory:
- `NMServer.exe`
- `NMConfig.exe`

No registry entries required for basic operation.

## Configuration

### 1. Set the Telnet Port

Default: port 23 (standard Telnet).
Change in NMConfig.exe or registry:

```
HKLM\SOFTWARE\NetModem32
  TelnetPort = 23     (DWORD)
  Nodes = 4           (DWORD — max simultaneous callers)
```

### 2. Set Up the Virtual COM Port

NetModem/32 needs a virtual COM port to talk to your BBS.
Three options:

**com0com (recommended for now):**
1. Download com0com from https://sourceforge.net/projects/com0com/
2. Install and create a COM pair (e.g. COM3 ↔ COM4)
3. Configure NMServer to use COM4
4. Configure your BBS to use COM3
5. See `docs/R42_com0com_NT_path.md` for detailed setup

**UMDF2 driver (future):**
Native virtual COM port driver — no third-party software needed.
See `docs/R43_UMDF2_virtual_COM.md` for the specification.

**DOSBox (for DOS BBS software):**
DOSBox provides its own virtual serial port. Configure DOSBox's
`[serial]` section to connect to NMServer. See the BBS-specific
guides below.

### 3. Start NMServer

```
NMServer.exe
```

The server window shows:
- Node list (connected callers)
- Status bar (driver status)
- Debug panel (toggle with File > Debug Panel)

The USR Courier-style LED panel shows modem status:
```
AA  CD  OH  RD  SD  TR  MR  CS  HS  ARQ
```

### 4. Test the Connection

From another machine (or localhost):
```
telnet your-server-ip 23
```

You should see your BBS login screen.

## Debug Mode

Toggle the debug panel: **File > Debug Panel**

The debugger shows everything in plain English:
```
[CALL]    Caller connected from 192.168.1.5
[SETUP]   8-bit clean data path ready
[LOGIN]   BBS asking for login: "Enter your name:"
[TYPING]  User typed: "verta1878"
[FILE]    Zmodem transfer detected
[BYE]     BBS saying goodbye
[HANGUP]  Caller disconnected
```

Export a session trace: the debug log is saved to
`netmodem_debug.log` in the NMServer directory.

See `docs/DEBUGGER_GUIDE.md` for the full reference.

## Running Under Linux (Wine)

```bash
# Install Wine and Xvfb
sudo apt install wine xvfb

# Run NMServer
xvfb-run -a wine NMServer.exe
```

NMServer runs headless under Wine with a virtual display.
The debug log still writes to `netmodem_debug.log`.

## Firewall

Open your Telnet port (default 23) for incoming TCP connections:

```bash
# Linux
sudo ufw allow 23/tcp

# Windows
netsh advfirewall firewall add rule name="NetModem" dir=in action=allow protocol=TCP localport=23
```

## Multinode

NetModem/32 supports up to 99 simultaneous callers.
Each node gets its own virtual COM port and UART emulation.
Configure the node count in NMConfig.exe or registry:

```
HKLM\SOFTWARE\NetModem32\Nodes = 4
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No callers can connect | Check firewall, verify port is open |
| BBS doesn't see the modem | Check virtual COM port pairing |
| Caller connects but BBS doesn't answer | Check FOSSIL driver is loaded |
| File transfers fail | Verify binary mode (Telnet BINARY negotiation) |
| Garbled text | Check BBS is set to 8-N-1 |

## Credits

- Dedrick Allen — original NetModem/32 (1997-2001)
- verta1878 — project lead, netmodem2irc revival
- sysop/0 — compiler (fpc264irc)
- kiddo — serial IRQ, protocols
- wrench — engine, debugger
- evga — display, RIPView
- hexadecimal — PCBoard 15.4

## License

GPLv3. See LICENSE.
