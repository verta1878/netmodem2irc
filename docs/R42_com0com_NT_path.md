# R4.2 — NT com0com Virtual COM Port Path

## What com0com Does

com0com creates **paired virtual COM ports** on Windows NT/2000/XP/Vista/7/10/11.
A BBS door opens COM3 (virtual); com0com routes bytes to COM4 (virtual);
NMServer reads COM4 and bridges to TCP/Telnet. No physical serial hardware needed.

```
BBS Door           com0com            NMServer
(COM3) ──write──> COM3<->COM4 ──read──> (COM4)
       <──read──  COM3<->COM4 <──write──
                                  │
                                  ▼
                            TCP/Telnet
                              caller
```

## Installation

1. Download com0com from https://sourceforge.net/projects/com0com/
2. Run `setup.exe` — installs the driver + management console
3. Open "Setup for com0com" from Start Menu
4. Click "Add Pair" — creates e.g. COM3 <-> COM4
5. Enable "Use Ports Class" checkbox for each port (so BBS software sees them)

## NMServer Integration

NMServer opens the B-side of the pair (COM4) using standard Win32 serial API:

```pascal
FHandle := CreateFile('\\.\COM4', GENERIC_READ or GENERIC_WRITE,
  0, nil, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, 0);
```

Then reads/writes bytes and bridges them to the Telnet socket.
The BBS door opens COM3 normally — it thinks it's a real modem.

## Configuration

In `NMConfig.exe` (or registry):

```
[HKLM\SOFTWARE\NetModem32]
COMPort=COM4           ; the B-side of the com0com pair
TelnetPort=23          ; port NMServer listens on
Nodes=4                ; max simultaneous connections
```

For multinode: create multiple pairs (COM3<->COM4, COM5<->COM6, etc.)
and configure each node in NMServer to use a different B-side port.

## Testing

1. Install com0com, create COM3<->COM4 pair
2. Run NMServer.exe (opens COM4, listens on port 23)
3. Open a terminal on COM3 (e.g. HyperTerminal, PuTTY serial)
4. Type text — it should appear in NMServer's debug panel
5. Connect a Telnet client to localhost:23
6. Data should flow: Telnet client <-> NMServer <-> COM4 <-> COM3 <-> terminal

## Known Issues

- com0com driver is unsigned on 64-bit Windows 10/11. Requires:
  - Test signing mode (`bcdedit /set testsigning on`), or
  - Disable driver signature enforcement in Advanced Boot Options
- com0com project is no longer actively maintained (last release ~2012)
- Alternative: com2tcp (simpler, no virtual COM — just TCP<->COM bridge)

## Advantages Over VxD Path

- Works on all NT-based Windows (2000 through 11)
- No ring-0 driver development needed on our side
- Standard Win32 serial API — same code as real hardware
- Well-understood by BBS sysops (many already use com0com)

## Limitations

- Requires third-party driver installation
- Unsigned driver is a hassle on modern Windows
- One COM pair per node (not elegant for 10+ nodes)
- For high node counts, R4.3 (UMDF2) is the better path
