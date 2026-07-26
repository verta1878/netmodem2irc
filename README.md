# netmodem2irc

Revival of Dedrick Allen's **NetModem/32** (32-bit FOSSIL Telnet server, 1997-2001)
for modern Windows, with a portable, tested Pascal modem-emulation engine.

> *"The virtual COM port is the foundation — without it, DOS BBS software is dead hardware. netmodem2irc makes DOS Mystic work on the modern internet. The FOSSIL driver, the serial code, the modem examples — they're not legacy, they're the bridge."*
>
> — Antonio Rico (verta1878)

## Status

Three independent tracks. DOS doesn't feed i386. The installer packages i386.

### i386 — the server (the core product)

| Milestone | What | Status |
|---|---|---|
| M0 | Recover Dedrick's original source | ✅ |
| M1 | Engine integrated — 38 tests, 0 failures | ✅ |
| M2 | Builds on Windows | ⚠️ cross-compiles, not runtime-tested |
| **M3** | **Live connection — real BBS door, real Telnet, binary-safe** | ⬜ |
| M4 | Virtual COM path (VxD 9x / com0com NT / native UMDF2) | ⬜ |
| M5 | Tagged installable release | ⬜ |

| Binary | Size | Status |
|---|---|---|
| NMServer.exe | 2.0M | ✅ compiles |
| NMConfig.exe | 2.0M | ✅ compiles |
| NETMODEM.CPL | 657K | ✅ original Dedrick Allen binary |

**M3 is the milestone that makes it "NetModem, revived."** Everything it
needs already compiles. What's missing is a live Telnet session through
NMServer with a real BBS door on the other end.

**Debug infrastructure is in place.** `NM_Debug.pas` provides central
logging with Play/Stop, wired into MainForm's init path and every CM_*
handler. The visual debug panel (TMemo in the form) is the remaining
GUI work. `NM_GlobalConfig` has `LogFileDays` / `LogFileMaxSize`
settings for future log rotation.

### DOS — the driver (standalone, not part of netmodem)

| Phase | What | Status |
|---|---|---|
| 6 | **Real 16550 UART** — port I/O, IRQ, rings | ⬜ can start now |
| 7 | FOSSIL set + INT 14h + `Keep` (FTSC) | ⬜ needs 6 |
| 8 | X00/BNU/ADF/NetFoss conformance | ⬜ needs 7 |
| 4 | Strip Watt-32, rewrite relay to port I/O | ⬜ needs 6 |
| 5 | Two builds, `ppcross8086` + msdos RTL only | ⬜ needs 4 |

`netfosdl.exe` — planned, not yet built.

### Installer (Inno Setup 5.6.1 FPC port)

| Phase | What | Status |
|---|---|---|
| 1–8 | ISCC through Compil32 | ✅ |
| 9 | Runtime testing | ⚠️ ISCC verified Win98 SE; Setup.exe + ISCmplr AV at init |
| 10 | ISCmplr DLL-init AV + FPC 3.2.2 portability | ⬜ |

### Blockers (cross-cutting)

- **151 paths uncommitted** — licensing, docs, layout all working-tree only
- **fpc264irc is an empty repository** — build recipes can't run
- **No runtime test anywhere** — Synapse untested live, no BBS door session
- **Debug panel** — `NM_Debug` is wired in; the GUI TMemo panel is next

## Architecture

```
CPL (NETMODEM.CPL, original) or NMConfig.exe
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
    ↓ opens/closes TCP sockets via WinSock (Synapse = the Pascal wrapper)

--- separate platform, no network ---

DOS: netfosdl.exe (standalone FOSSIL driver)
    ↑ BBS calls FOSSIL INT 14h
    ↓ real 16550 UART
    (not part of netmodem — no TCP, no NM_* units)
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
netmodem2irc/
├── engine/                     392K  — emulation core, 22 units
│   │                                   includes the virtual-comport FOSSIL —
│   │                                   answers INT 14h on an EMULATED UART
│   │                                   UART 16550, FOSSIL INT 14h, Telnet transport,
│   │                                   AT commands, multinode, Synapse + named-pipe
│   │                                   links, server bridge, SEAM protocol, TSR
│   │                                   skeleton, per-node + global config
│   └── test/                   39 files — test suite, 38 tests
│                                          `sh engine/test/run-tests.sh`
├── server/                     152K  — NMServer, Lazarus GUI Telnet server
│   │                                   (was Dedrick's NETMODEM.EXE)
│   └── resources/              15 files — server.ico + .rc
├── config/                     236K  — NMConfig, Lazarus config app
│   │                                   all per-node + global settings, 5 tabs
│   └── resources/              49 files — icons + bitmaps from the original CPL
├── common/                      28K  — NMVxD.pas: driver interface
│                                       IOCTL, CM_* messages, ComportStruct
├── driver/
│   └── src/                    14 files — Dedrick's original 9x VxD source
│                                          MASM, experimental
├── dos/                        232K  — DOS FOSSIL driver (netfosdl), i8086
│   │                                   ANSWERS INT 14h, sits on a REAL UART.
│   │                                   Same role as the engine's FOSSIL, but
│   │                                   on hardware instead of emulation —
│   │                                   see docs/netmodem2irc_fossil_separation.md
│   │                                   FTSC FSC-0015/0072; drop-in for
│   │                                   X00 / BNU / ADF / NetFoss
│   │                                   (fossil_dos.pas is the superseded client)
│   └── retired/                superseded attempts
├── cpl/                         68K  — original Control Panel applet
│   ├── original_forms/          6 files — decompiled DFMs, reference only
│   └── resources/               2 files
├── libs/
│   └── synapse/                17 files — Ararat Synapse networking
│                                          modified-BSD, GPLv2-compatible
├── InnoIRC561/                  26M  — Inno Setup 5.6.1 FPC port
│                                       see InnoIRC561/README.md
├── history/                    2.7M  — Dedrick's original distributions
│   ├── net32_b4/               11 files
│   └── netmdb15/                6 files — plus NETMODEM.CPL, 657K, 1997-2001
├── docs/                       340K  — engineering docs, 60 files
│   │                                   index + status: docs/README.md
│   └── original/                3 files — Dedrick's own documentation
├── attic/                       28K  — retired files
│   ├── WIN32COM.PAS                    — old ELECOM Win32 comms unit
│   └── netmodem2irc_CREDITS.md         — early credits, superseded by CREDITS.md
├── out/                              — build output, split by target arch
│   ├── dos/                    netfosdl.exe — i8086 real mode, MZ
│   ├── i386/                   NMServer.exe  NMConfig.exe  NETMODEM.CPL  *.res
├── build.sh                            — tests / win32 / fossil / resources / clean
├── Makefile                            — thin wrapper over build.sh
├── ROADMAP.md                          — master roadmap, order of work, coding standards
├── VERSION  CHANGELOG.md
├── AUTHORS  CREDITS.md  THIRD_PARTY.md
├── LICENSE                             — GPLv3 (the revival)
├── LICENSE-GPLv2                       — GPLv2 (Dedrick's material)
├── LICENSES.md                         — which licence covers what, and why
├── .gitmessage                         — commit template
└── .github/                            — CI workflow
```

## Building

Requires fpc264irc r3.1+ (github.com/verta1878/fpc264irc).

```sh
FPCIRC=/path/to/fpc264irc ./build.sh          # build everything (tests + win32 + fossil)
FPCIRC=/path/to/fpc264irc ./build.sh tests     # engine tests only (38/38)
FPCIRC=/path/to/fpc264irc ./build.sh win32     # cross-compile Win32 binaries
FPCIRC=/path/to/fpc264irc ./build.sh fossil    # DOS FOSSIL binary
./build.sh resources                           # compile icon .rc → .res files
./build.sh clean                               # remove build artifacts
make clean                                     # same via Makefile
```

### Win32 cross-compile

`./build.sh win32` cross-compiles NMServer.exe and NMConfig.exe from Linux
using fpc264irc ppc386 + Win32 LCL. Copies original NETMODEM.CPL to out/i386/.
Output goes to `out/i386/`. Requires `i686-w64-mingw32-windres` for
icon embedding (`apt install binutils-mingw-w64-i686`).

### Icon resources

Original icons extracted from Dedrick's NETMODEM.CPL (14 icons, 36 bitmaps).
Compiled via windres into `.res` files embedded in each binary:

    server/resources/NMServer.rc   → server.ico
    config/resources/NMConfig.rc   → mainicon.ico

### DOS (netfosdl.exe)

**The DOS build is mid-rewrite.** See
`docs/netmodem2irc_watt32_cleanup_phases.md`.

Target: `ppcross8086` plus the msdos RTL only — no OpenWatcom, no
Watt-32, no OMF conversion. The current `build.sh fossil` still builds
the superseded relay and references `stubs.asm` at a path it no longer
occupies, so it is broken until Phase 5.

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
- **NM_GlobalConfig** — server-level settings (logging, network, display files, features)
- **NM_Listserv** — BBS Listserv directory registration
- **NM_AutoNews** — periodic news/announcement broadcast
- **NM_FossilDriver** — INT 14h register-frame dispatch (testable)
- **NM_Debug** — central debug logging (`-dNM_DEBUG`), OutputDebugString + file

## Debug

`engine/NM_Debug.pas` — central debug logging with Play/Stop, inspired
by Carl Gorringe's [RIPtermJS](https://github.com/cgorringe/RIPtermJS)
debug log panel. Compiles clean on all targets. Wired into MainForm.

Three output channels, all active simultaneously:

| Channel | What | Paused? |
|---|---|---|
| `OutputDebugString` (Win32) | kernel debug log, readable with DebugView | never — crash-recovery channel |
| Log file | per-line flush, survives crashes | never |
| Line handler callback | the visual debug panel in the GUI | **yes — Play/Stop controls this** |

API:

| Function | What |
|---|---|
| `DebugLog(subsystem, msg)` | writes to all three channels |
| `DebugLogFmt(subsystem, fmt, args)` | `Format` + `DebugLog` |
| `DebugInitFile(filename)` | opens the log file |
| `DebugShutdown` | flushes and closes |
| `DebugPause` / `DebugResume` | freeze/unfreeze the visual panel — recording continues |
| `DebugIsPaused` / `DebugIsActive` | query state |
| `DebugSetLineHandler(handler)` | GUI registers a callback for the debug panel |

`TDebugLineEvent` receives subsystem and message separately so the GUI
can color-code by subsystem without parsing. HAZARD documented: the
handler runs on whatever thread calls `DebugLog`, so GUI access needs
`TThread.Synchronize` or `Application.QueueAsyncCall`.

Controlled by `-dNM_DEBUG`. Without it, every call compiles to nothing.
Wired into `MainForm.FormCreate` (init + log file), every `CM_*`
handler, `RefreshNodes`, `miSetupClick`, and `FormDestroy`.

## Platforms

All Windows binaries are **i386-win32 (32-bit PE)**. They run natively
on 32-bit Windows and under **WoW64** on 64-bit Windows (XP x64 through
Win11). There is no native x86_64 build — that is a future target, not
a current limitation, since WoW64 handles the 32-bit binaries
transparently.

The Win98 → Win11 range is covered by a single binary: min OS 4.0 with
DEP and ASLR disabled keeps Win9x happy while WoW64 handles the modern
end.

| Platform | Driver | Transport |
|----------|--------|-----------|
| Windows 95/98/ME | NETMODEM.VXD (Dedrick's original) | WinSock via Synapse |
| Windows NT/2K/XP — Win11 (32 and 64-bit) | com0com virtual COM port | WinSock via Synapse |
| DOS (real mode) | netfosdl — FTSC FOSSIL driver on a real UART (X00/BNU/ADF/NetFoss drop-in) | none — standalone, no network |

**Native x86_64 (win64) is not yet supported.** When it is, it will be
a separate build target (`make win64`), not a replacement for win32 —
Win9x and early NT need the 32-bit binary.

## Credits

Original NetModem/32: **Dedrick Allen** (mag69), 1997-2001. Allen Software.
His material remains under GNU General Public License v2.

Revival: **Antonio Rico** (Reapern66 / verta1878).
Built with fpc264irc r3.1+ (github.com/verta1878/fpc264irc).

## License

**Free software. No longer shareware.**

The 1997 distribution was shareware. It isn't any more — Dedrick Allen
handed NetModem/32 forward for release under GPL. Dedrick's original
work is **GPLv2**, respectfully and unchanged. The revival work is
**GPLv3**.

| | |
|---|---|
| `engine/` `server/` `config/` `common/` `dos/` | GPLv3+ — Antonio Rico |
| `driver/src/` `history/` `cpl/original_forms/` | GPLv2 — Dedrick Allen |
| `libs/synapse/` | modified BSD — Lukas Gebauer |

[LICENSE](LICENSE) is GPLv3. [LICENSE-GPLv2](LICENSE-GPLv2) covers
Dedrick's material. See [LICENSES.md](LICENSES.md) for the full
breakdown, the reasoning, and open questions that should be settled
before a public release.

## Roadmap

See [ROADMAP.md](ROADMAP.md) — the single document that says what to do
next, in what order, across all three tracks. It also codifies the
aggressive commenting standard this codebase follows.

Quick view of what's next:

1. **Commit** the 153 uncommitted paths (4 commits)
2. **Wire debug** into MainForm and add the debug panel
3. **Fix the init AVs** — they block everything downstream
4. **Real 16550 UART** for the DOS driver (parallel with #3)
5. **Live connection test** — the milestone that makes it real
6. **Ship**

## Installer

Inno Setup 5.6.1 fully ported to FPC 2.6.4irc. Phases 1-9 complete,
Phase 10 open. 5/5 targets compile (ISCC.exe, ISCmplr.dll, Setup.exe,
SetupLdr.exe, Compil32.exe). ISCC.exe verified working on Windows 98 SE
— produces installer packages. Rebuilt with BUG-029 source-level fix.

Two binaries currently access-violate at initialization: Setup.exe
during form init, ISCmplr.dll during DLL init. Both are open. See
`InnoIRC561/README.md`.

The virtual COM port is the foundation — without it, DOS BBS software
is dead hardware. netmodem2irc makes DOS Mystic work on the modern
internet. The FOSSIL driver, the serial code, the modem examples —
they're not legacy, they're the bridge.

### Phases completed

| Phase | Description | Status |
|-------|-------------|--------|
| 1-3 | ISCC.exe, compression, LCL integration | ✅ Done |
| 4 | LZMA decompression (MinGW .o via {$L}) | ✅ Done |
| 5 | Windows resources ({$R} enabled, LangID fix) | ✅ Done |
| 6 | DFM→LFM forms (7 installer forms via lazres) | ✅ Done |
| 7 | PascalScript [Code] section (35K lines) | ✅ Done |
| 8 | Compil32.exe IDE (Scintilla editor) | ✅ Done |
| 9 | Runtime testing (Win98 + Win11) | ⚠️ ISCC verified; 2 AVs open |
| 10 | ISCmplr — DLL-init AV + FPC 3.2.2 portability | ⬜ Open |

### Key fixes

- `Byte(CurCRC)` in Compress.pas — FPC `Lo()` returns Word, not Byte
- `{$APPTYPE GUI}` for Setup.dpr, SetupLdr.dpr, Compil32.dpr
- Win98 PE flags: OS version 4.0, no DEP/ASLR/TS
- BUG-029: `fpc_AnsiStr_Decr_Ref` sub $12 fix (source-level, all targets)
- fpcres BUG-032: LangID fallback for Borland Dutch icon .res files

See `InnoIRC561/INNO_FPC_PORT.md` for detailed build instructions.

