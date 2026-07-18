# netmodem2irc

Revival of Dedrick Allen's **NetModem/32** (32-bit FOSSIL Telnet server, 1997-2001)
for modern Windows, with a portable, tested Pascal modem-emulation engine.

## Status

**35 test programs, 0 failures.** Server, config, CPL, and FOSSIL bridge all compile.

| Component | Target | Status |
|-----------|--------|--------|
| Engine (emulation core) | Any platform | ✅ 35/35 tests pass |
| NMServer.exe | Win98 / NT | ✅ Compiles (needs LCL to link) |
| NMConfig.exe | Win98 / NT | ✅ Compiles (needs LCL to link) |
| NetModemCPL.cpl | Win98 / NT | ✅ Compiles (Control Panel applet) |
| netfossl.exe | DOS (i8086) | ✅ Built — 179KB FOSSIL binary |

## Architecture

```
CPL (NetModemCPL.cpl) or NMConfig.exe
    ↓ writes/reads registry
    HKLM\Software\Allen Software\NetModem
      ComportConfig   REG_BINARY (per-node: comport, baud, mode)
      IRQ             REG_DWORD
    ↓ IOCTL 03 (reload config, no reboot)

VxD Driver (NETMODEM.VXD on 9x) or com0com (on NT)
    ↑ reads registry at boot
    ↓ posts CM_* messages to server window

NMServer.exe
    ↑ IOCTL 08 (register window)
    ↓ reacts to CM_CONNECT/DISCONNECT/BREAK
    ↓ opens/closes TCP sockets via Synapse

FOSSIL bridge (netfossl.exe)
    ↑ FOSSIL INT 14h + fpcirc TCP/IP
    ↓ direct serial↔TCP relay (no Windows needed)
```

## Configuration

The VxD reads config from the Windows registry. The CPL and NMConfig write
the same keys. The server does NOT read config — the driver already has it.

    HKLM\Software\Allen Software\NetModem
      ComportConfig   REG_BINARY   array of ComportStruct (22 bytes/node)
      IRQ             REG_DWORD    interrupt number (0 = none)

Per-node ComportStruct fields (matches original CPL 1:1):

    Field            Size   Default        Description
    Node             Byte   1              node slot
    Enabled          Byte   1              node active
    ComportNumber    Byte   3              virtual COM port (1-99)
    szComportName    7      "COM3"         ASCII name
    Emulation        Byte   1 (FOSSIL)     0=UART, 1=FOSSIL
    Baudrate         Word   38400          300-115200 (14 rates)
    Internetport     Word   23             TCP listen port
    Baseaddress      Word   $03E8          I/O base address
    Alwaysactive     Byte   0              keep node up without connection
    Lockedbaudrate   Byte   1              lock baud rate
    Managetimeslice  Byte   1              yield CPU when idle
    Buffersize       Word   2048           RX/TX buffer (1024-8192)

Factory defaults written to registry on first run if no config exists.
Connection targets come from AT dial commands (`ATDT host:port`), not config.

## Repository layout

```
engine/         emulation engine — UART, FOSSIL, Telnet transport, AT commands,
                multinode, Synapse + named-pipe links, server bridge, seam
                protocol, TSR skeleton, per-node config
engine/test/    test suite (sh engine/test/run-tests.sh)
server/         NMServer — Lazarus GUI, Telnet server (was NETMODEM.EXE)
config/         NMConfig — Lazarus standalone config app (was NETMODEM.CPL)
cpl/            NetModemCPL — Control Panel applet (.cpl DLL)
dos/            i8086 DOS FOSSIL↔TCP bridge (netfossl.exe, fpcirc cross-compile)
common/         NMVxD.pas — driver interface (IOCTL, CM_* messages, ComportStruct)
driver/src/     Dedrick's original 9x VxD source (MASM, experimental)
libs/synapse/   Ararat Synapse networking (modified-BSD, GPLv2-compatible)
history/        Dedrick's original distributions (net32_b4, netmdb15)
docs/           engineering docs, specs, audits, roadmap
attic/          retired files
```

## Building

Requires fpc264irc r6.1+ (github.com/verta1878/fpc264irc).

```sh
FPCIRC=/path/to/fpc264irc ./build.sh          # build everything (tests + win32 + fossil)
FPCIRC=/path/to/fpc264irc ./build.sh tests     # engine tests only (35/35)
FPCIRC=/path/to/fpc264irc ./build.sh win32     # cross-compile Win32 binaries
FPCIRC=/path/to/fpc264irc ./build.sh fossil    # DOS FOSSIL binary
./build.sh resources                           # compile icon .rc → .res files
./build.sh clean                               # remove build artifacts
make clean                                     # same via Makefile
```

### Win32 cross-compile

`./build.sh win32` cross-compiles NMServer.exe, NMConfig.exe, and
NetModemCPL.cpl from Linux using fpc264irc's ppc386 + Win32 LCL.
Output goes to `out/win32/`. Requires `i686-w64-mingw32-windres` for
icon embedding (`apt install binutils-mingw-w64-i686`).

### Icon resources

Original icons extracted from Dedrick's NETMODEM.CPL (14 icons, 36 bitmaps).
Compiled via windres into `.res` files embedded in each binary:

    server/resources/NMServer.rc   → server.ico
    config/resources/NMConfig.rc   → mainicon.ico
    cpl/resources/NetModemCPL.rc   → mainicon.ico

### DOS (netfossl.exe)

Requires fpc264irc r6.1+ with i8086 cross-compiler + OpenWatcom wlink:
```
FPCIRC=/path/to/fpc264irc ./build.sh fossil
```

## Engine (tested)

- **NM_UART16550** — 16550 UART emulation
- **NM_Fossil** — FOSSIL INT 14h (init signature $1954)
- **NetTransport** — Telnet transport, IAC/BINARY, binary-safe
- **NM_ATCommand** — Hayes AT, ATDT<host> dial
- **NM_Node** — per-node object + multinode manager (comports 3-99)
- **NM_SynapseLink** — real Synapse TCP socket link
- **NM_NamedPipeLink** — named-pipe link (virtual-COM driver seam)
- **NM_ServerBridge** — wires engine to server's CM_* + TIOStruct IO
- **NM_SeamProtocol / NM_SeamSender** — driver↔server framed protocol
- **NM_TSR** — FOSSIL TSR resident-program skeleton
- **NM_Config / NM_ConfigApply** — per-node config (comport/baud/mode)
- **NM_DefaultConfig** — factory defaults + registry read/write
- **NM_FossilDriver** — INT 14h register-frame dispatch (testable)

## Platforms

| Platform | Driver | Transport |
|----------|--------|-----------|
| Windows 95/98/ME | NETMODEM.VXD (Dedrick's original) | WinSock via Synapse |
| Windows NT/2K/XP+ | com0com virtual COM port | WinSock via Synapse |
| DOS (real mode) | FOSSIL INT 14h (fossil_dos.pas) | fpcirc TCP/IP (BSD sockets) |

## Credits

Original NetModem/32: **Dedrick Allen** (mag69), 1997-2001. Allen Software.
Released under GNU General Public License v2.

Revival: **Antonio Rico** (Reapern66 / verta1878).
Built with fpc264irc r6.1+ (github.com/verta1878/fpc264irc).

## License

GNU General Public License v2 — see [LICENSE](LICENSE).
