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

The VxD reads config from the Windows registry (`HKLM\Software\Allen Software\NetModem`).
The CPL and NMConfig write the same keys. Text config is also supported:

    ; netmodem2irc config — matches original CPL 1:1
    node 1 comport 3 baud 38400 mode fossil port 23
    node 2 comport 4 baud 57600 mode uart port 6667 buffer 4096

Per-node fields (all optional except comport, defaults in parentheses):

    comport <1-99>          virtual COM port number
    baud <rate>             300/1200/2400/9600/14400/16800/19200/21600/
                            28800/33600/38400/57600/64000/115200 (38400)
    mode <fossil|uart>      emulation mode (fossil)
    port <1-65535>          TCP listen port (23)
    base <hex>              I/O base address ($03E8)
    buffer <1024-8192>      RX/TX buffer size in bytes (2048)
    alwaysactive <0|1>      keep node active without connection (0)
    lockedbaud <0|1>        lock baud rate (1)
    timeslice <0|1>         yield CPU when idle (1)
    enabled <0|1>           node active (1)

Factory defaults (from NetModem v1): Node 1, COM3, 38400 baud, FOSSIL mode,
telnet port 23, 2048 byte buffers. Written to registry on first run.

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

Requires fpc264irc r6.0+ (github.com/verta1878/fpc264irc).

```sh
./build.sh                    # build everything
./build.sh tests              # engine tests only (35/35)
./build.sh resources          # compile icon .rc → .res files
./build.sh server             # NMServer (builds resources first)
./build.sh config             # NMConfig (builds resources first)
./build.sh cpl                # Control Panel applet (builds resources first)
./build.sh fossil             # DOS netfossl.exe
make clean                    # remove all build artifacts
```

### Icon resources

Original icons extracted from Dedrick's NETMODEM.CPL (14 icons, 36 bitmaps).
Compiled via `i686-w64-mingw32-windres` into `.res` files embedded in binaries:

    server/resources/NMServer.rc   → server/NMServer.res   (server.ico)
    config/resources/NMConfig.rc   → config/NMConfig.res   (mainicon.ico)
    cpl/resources/NetModemCPL.rc   → cpl/NetModemCPL.res   (mainicon.ico)

Install windres: `apt install binutils-mingw-w64-i686`

### Windows (NMServer + NMConfig + CPL)

Requires fpc264irc r6.0+ with LCL PPUs for win32:
```
ppc386 -Mobjfpc -Fu<engine> -Fu<common> -Fu<synapse> -Fu<lcl-win32> -Fu<lazutils> server\NMServer.lpr
ppc386 -Mobjfpc -Fu<engine> -Fu<common> -Fu<lcl-win32> -Fu<lazutils> config\NMConfig.lpr
ppc386 -WD -Fu<engine> -Fu<common> cpl\NetModemCPL.pas
ren NetModemCPL.dll NetModemCPL.cpl
copy NetModemCPL.cpl %SystemRoot%\system32\
```

### DOS (netfossl.exe)

Requires fpc264irc r6.0+ with i8086 cross-compiler + OpenWatcom wlink:
```
FPCIRC=/path/to/fpc264irc dos/build.sh
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
| DOS (real mode) | FOSSIL INT 14h (fossil_dos.pas) | fpcirc TCP/IP (Watt-32) |

## Credits

Original NetModem/32: **Dedrick Allen** (mag69), 1997-2001. Allen Software.
Released under GNU General Public License v2.

Revival: **Antonio Rico** (Reapern66 / verta1878).
Built with fpc264irc r6.0+ (github.com/verta1878/fpc264irc).

## License

GNU General Public License v2 — see [LICENSE](LICENSE).
