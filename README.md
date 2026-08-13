# netmodem2irc

Revival of Dedrick Allen's **NetModem/32** (32-bit FOSSIL Telnet server, 1997-2001)
for modern Windows, with a portable, tested Pascal modem-emulation engine.

> *"The virtual COM port is the foundation — without it, DOS BBS software is dead hardware. netmodem2irc makes DOS Mystic work on the modern internet. The FOSSIL driver, the serial code, the modem examples — they're not legacy, they're the bridge."*
>
> — Antonio Rico (verta1878)

## Repository

See **Directory Map** below for the full annotated tree.

Key directories: `engine/` (core), `server/` (GUI), `fossil/` (4 platforms),
`driver/pascal-port/` (VxD port), `tests/`, `docs/`, `InnoIRC561/` (installer).

## Status

Three independent tracks. DOS doesn't feed i386. The installer packages i386.

### i386 — the server (the core product)

| Milestone | What | Status |
|---|---|---|
| M0 | Recover Dedrick's original source | ✅ |
| M1 | Engine integrated — 38 tests, 0 failures | ✅ |
| M2 | Builds on Windows — dual compiler verified | ✅ |
| M3 | Live connection — 6 tests pass | ✅ |
| M4 | Virtual COM path (com0com NT + UMDF2 named pipe) | ✅ code written, needs hardware to test |
| M5 | Tagged installable release | ⬜ after final testing |

| Binary | Size | Compiler | Status |
|---|---|---|---|
| NMServer.exe | 2.6M | FPC 2.6.4irc | ✅ Win32 PE32 |
| NMServer.exe | 2.0M | FPC 3.2.2 | ✅ Win32 PE32 |
| NMServer | 5.1M | FPC 3.2.2 | ✅ Linux ELF |
| NMConfig.exe | 2.0M | FPC 3.2.2 | ✅ compiles |
| NETMODEM.CPL | 657K | Dedrick Allen | ✅ original binary |

### DOS — the FOSSIL driver

| Phase | What | Status |
|---|---|---|
| D1 | Real 16550 UART — serial.pas (sysop/0) | ✅ |
| D2 | FOSSIL function set — fossil.pas | ✅ |
| D3 | INT 14h + Keep — netfosdl.pas | ✅ |
| D4 | Conformance testing — test suite ready | ✅ (needs 386 to run) |
| D5 | Direct UART relay — 50 tests pass | ✅ |

### Installer — Inno Setup

| Phase | What | Status |
|---|---|---|
| Inno 1-8 | ISCC through Compil32 | ✅ |
| Inno 9-10 | Setup.exe + ISCmplr runtime AV | ✅ |

### Release milestones

| Phase | What | Status |
|---|---|---|
| R1.1-R1.7 | Debug infrastructure (NM_Debug + panel + SynapseLink) | ✅ |
| R2.1-R2.5 | Setup.exe + ISCmplr AV fix | ✅ DEP fix + Wine deadlock fix |
| R3.3 | Binary safety — 37 tests pass | ✅ |
| R3.4 | Multinode — 25 tests pass (3 simultaneous nodes) | ✅ |
| R4.1 | Win9x VxD test | ✅ mock passes 39/39, needs Win98 VM for real |
| R4.2 | NT com0com path — documented | ✅ |
| R4.3 | NT UMDF2 driver — specified | ✅ |
| R5.1 | Inno installer packaging | ✅ wine ISCC.exe builds installer |

## Test Results

| Suite | Tests | Pass |
|---|---|---|
| M0-M1 Engine | 38 | 38 |
| R3.3 Binary safety | 37 | 37 |
| M3 Live connection | 6 | 6 |
| R3.4 Multinode | 25 | 25 |
| D5 Direct relay | 50 | 50 |
| **Total** | **156** | **156** |

## Engine Units

| Unit | Lines | What |
|---|---|---|
| NM_UART16550 | — | 16550 UART emulation (registers, RX/TX ring buffers) |
| NM_Debug | — | Three-channel debug (OutputDebugString, log file, callback) |
| NM_DebugView | 1,455 | Protocol analyzer — USR Courier LED panel, hex stream, event log, ANSI/AT/Zmodem decoders, session lifecycle, throughput, export |
| NM_DirectRelay | 299 | TCP↔UART bypass — no FOSSIL dispatch overhead |
| NM_Config | — | Registry configuration |
| NM_ATCommand | — | AT modem command parser |
| NM_Fossil | — | FOSSIL function emulation |
| NM_FossilDriver | — | FOSSIL driver interface |
| NM_Node | — | Node/connection manager (99 nodes) |
| NM_SeamProtocol | — | SEAM length-prefixed binary framing |
| NM_ServerBridge | — | Server bridge (listen, accept, pump) |
| NM_SynapseLink | — | Socket link with debug logging (R1.7) |
| NetTransport | — | Telnet BINARY negotiation, IAC doubling |
| NMVxD | — | VxD interface (cross-platform) |
| NetModemVxD | — | VxD interface (Windows-only) |

## DOS FOSSIL Driver

```
dos/driver/
├── serial.pas        203 lines — real 16550 UART (sysop/0)
├── serial_irq.pas    195 lines — ISR + 4KB ring buffer (kiddo)
├── fossil.pas        398 lines — FOSSIL dispatch FSC-0015/0072
└── netfosdl.pas      323 lines — INT 14h hook, Keep, X00 params
```

## Debugger (NM_DebugView)

Real-time protocol analyzer. Three panels:

**USR Courier LED Panel** — AA CD OH RD SD TR MR CS HS ARQ.
LEDs flicker on data flow, map to UART MSR/MCR register bits.

**Event Log** — full session lifecycle in plain English:
connect, Telnet negotiation, FOSSIL init, login/password detection,
menu detection, Zmodem transfer detection, goodbye, disconnect.
Session summary with duration, bytes, username, transfer count.

**Data Stream** — human-readable byte dump. Auto-detects ANSI sequences,
AT commands, Zmodem headers, IAC escapes. Throughput counter with
peak rate. File transfer progress. Export to file.

See docs/DEBUGGER_GUIDE.md for the plain English reference.

## Docs

| Doc | What |
|---|---|
| ROADMAP.md | 3 tracks, all phases, coding standards |
| docs/index.htm | Color-coded doc index with phase status |
| docs/DEBUGGER_GUIDE.md | Plain English debugger reference |
| docs/R42_com0com_NT_path.md | NT virtual COM port setup guide |
| docs/R43_UMDF2_virtual_COM.md | UMDF2 driver specification |
| docs/serial_irq_plan.md | ISR + ring buffer plan (implemented) |

74 docs total. See docs/index.htm for the full categorized index.

## Build

### FPC 3.2.2 + Lazarus 3.0 (Linux cross-compile)

```bash
# Engine only (no GUI)
fpc -Mobjfpc -Fuengine -Fucommon -Fulibs/synapse -dHAS_SYNAPSE server/NMServer.lpr

# Win32 cross-compile (needs upstream FPC source + LCL)
# Trick: compile forms.pp first, then interfaces.pp, exclude FV
ppcross386 -Twin32 ... server/NMServer.lpr
```

### FPC 2.6.4irc (the shipping compiler)

```bash
# Uses verta1878/fpc264irc toolchain
ppc386 -Twin32 ... server/NMServer.lpr
```

### Tests

```bash
fpc -Mobjfpc -dHAS_SYNAPSE tests/test_binary_safety.pas && ./test_binary_safety
fpc -Mobjfpc -dHAS_SYNAPSE tests/test_r34_multinode.pas && ./test_r34_multinode
fpc -Mobjfpc -dHAS_SYNAPSE tests/test_d5_relay.pas      && ./test_d5_relay
# D4 FOSSIL conformance: DOS only (ppcross386 -Tgo32v2 -Mtp)
```

## The Stack

```
caller (telnet)
  → netmodem2irc (transport)      wrench + verta1878
    → FOSSIL (virtual COM)         sysop/0 + kiddo
      → PCBoard 15.4 (BBS)         hexadecimal
      → Mystic BBS (BBS)           evga + kiddo
        → RIPscrip (graphics)      kiddo
        → OpenOLMS (offline mail)  verta1878 + wrench
```

## Credits

| Who | What |
|---|---|
| verta1878 | Project lead, architect |
| sysop/0 | Compiler (fpc264irc), terminal, serial UART |
| kiddo | Serial IRQ ring buffer, protocols, RIPscrip engine |
| wrench | Engine, debugger, network architecture |
| evga | Display, RIPView, Mystic monitor |
| hexadecimal | PCBoard 15.4 (pcbrevival) |
| g00r00 | Mystic BBS (GPLv3 upstream) |
| Dedrick Allen | Original NetModem/32 (1997-2001) |

## License

GPLv3. See LICENSE.
# netmodem2irc — Directory Map

878 files. Annotated guide to every directory and key file.

```
netmodem2irc/
│
├── README.md                   Project overview, status, build instructions
├── ROADMAP.md                  3 tracks, all phases, coding standards
├── LICENSE                     GPLv3
├── LICENSE-GPLv2               Original Dedrick Allen license
├── LICENSES.md                 License summary for all components
├── THIRD_PARTY.md              Third-party code attributions
├── AUTHORS                     Team members + credits
├── CREDITS.md                  Detailed credits
├── CHANGELOG.md                Version history
├── Makefile                    Build: make, make tests, make win32, make dos
├── build.sh                    Build helper script
├── DEFERRED-20260725.md        Deferred items from session 2
│
├── engine/                     ── THE CORE ENGINE (18 units) ──
│   ├── NM_UART16550.pas        16550 UART emulation (registers, RX/TX rings)
│   ├── NM_Debug.pas            3-channel debug (OutputDebugString, log, callback)
│   ├── NM_DebugView.pas        Protocol analyzer — 1,455 lines
│   │                             USR Courier LED panel (AA CD OH RD SD TR MR CS HS ARQ)
│   │                             Hex stream + human-readable data viewer
│   │                             Event log with session lifecycle tracing
│   │                             FOSSIL decoder, Telnet decoder, AT command scanner
│   │                             ANSI sequence decoder, throughput counter
│   │                             File transfer progress, session export
│   ├── NM_DirectRelay.pas      TCP↔UART bypass (no FOSSIL overhead) — 299 lines
│   ├── NM_Config.pas           Registry configuration
│   ├── NM_ConfigApply.pas      Apply config changes at runtime
│   ├── NM_DefaultConfig.pas    Default configuration values
│   ├── NM_GlobalConfig.pas     Global config singleton
│   ├── NM_ATCommand.pas        AT modem command parser (ATDT, ATH, ATA, ATZ)
│   ├── NM_Fossil.pas           FOSSIL function emulation (INT 14h)
│   ├── NM_FossilDriver.pas     FOSSIL driver interface
│   ├── NM_Int14ISR.pas         INT 14h ISR hook (211 lines)
│   ├── NM_Node.pas             Node/connection manager (99 nodes max)
│   ├── NM_SeamProtocol.pas     SEAM length-prefixed binary framing
│   ├── NM_SeamSender.pas       SEAM frame sender
│   ├── NM_ServerBridge.pas     Server bridge (listen, accept, pump)
│   ├── NM_ServerLink.pas       Server link interface
│   ├── NM_SynapseLink.pas      Socket link + debug logging (R1.7)
│   ├── NM_Listserv.pas         Future mailing list server
│   ├── NM_AutoNews.pas         Auto-news feature
│   ├── NM_TSR.pas              TSR support (DOS)
│   ├── NM_TSRResident.pas      TSR resident code (DOS)
│   ├── NM_NamedPipeLink.pas    Named pipe transport
│   ├── NetTransport.pas        Telnet BINARY negotiation, IAC doubling
│   └── test/                   M0-M1 engine unit tests (38 tests)
│       ├── run-tests.sh        Test runner
│       ├── test_uart.pas       UART emulation tests
│       ├── test_atcommand.pas  AT command tests
│       ├── test_fossil.pas     FOSSIL emulation tests
│       ├── test_transport.pas  Transport layer tests
│       ├── test_seam*.pas      SEAM protocol tests (6 files)
│       ├── test_bridge*.pas    Bridge tests
│       ├── test_synapse*.pas   Socket link tests
│       └── ... (28 test files total)
│
├── server/                     ── THE SERVER GUI ──
│   ├── NMServer.lpr            Lazarus project (LCL entry point)
│   ├── NetModemServer.lpr      Alternate entry point (Windows-only deps)
│   ├── MainForm.pas            Main window — node list, debug panel (R1.5)
│   ├── MainForm.lfm            Lazarus form layout
│   ├── SplashForm.pas          Splash screen
│   ├── SplashForm.lfm          Splash form layout
│   ├── NMServer.lpi            Lazarus project info
│   ├── NMServer.res            Compiled resources
│   └── resources/              Icons + bitmaps (mainicon, splash, status icons)
│
├── config/                     ── THE CONFIG TOOL ──
│   ├── NMConfig.lpr            Config editor entry point
│   ├── ConfigMain.pas          Config main form
│   ├── ConfigMain.lfm          Config form layout
│   ├── NMConfig.res            Compiled resources
│   └── resources/              Icons + bitmaps (30 resource files)
│
├── common/                     ── SHARED UNITS ──
│   ├── NMVxD.pas               VxD interface (cross-platform)
│   └── NetModemVxD.pas         VxD interface (Windows-only)
│
├── fossil/                      ── FOSSIL DRIVERS (4 PLATFORMS) ──
│   ├── common/                  Shared code
│   │   ├── m_fossil_socket.pas  Socket FOSSIL backend (sysop/0, 189 lines)
│   │   └── serial_ext.pas      6 extended serial functions (wrench)
│   ├── dos/                     netfosdl — DOS TSR (INT 14h)
│   │   ├── fossil.pas           FOSSIL dispatch FSC-0015
│   │   ├── serial.pas           16550 UART Port[] I/O (sysop/0)
│   │   ├── serial_irq.pas      ISR + 4KB ring buffer (kiddo)
│   │   └── netfosdl.pas         DOS TSR loader
│   ├── linux/                   netfosll — Linux ASYNC layer
│   │   └── async_linux.c        23 ASYNC functions (wrench, 326 lines)
│   ├── os2/                     netfosol — OS/2 (DosDevIOCtl + socket)
│   │   └── netfosol.pas         428 lines (wrench)
│   └── windows/                 netfoswl — Windows (Win32 COM + socket)
│       └── netfoswl.pas         392 lines (wrench)
│
├── dos/                        ── DOS TARGET ──
│   ├── driver/                 FOSSIL driver (D1-D3)
│   │   ├── serial.pas          Real 16550 UART — Port[] I/O (sysop/0, 203 lines)
│   │   ├── serial_irq.pas      ISR + 4KB ring buffer, 8259 PIC (kiddo, 195 lines)
│   │   ├── fossil.pas          FOSSIL dispatch FSC-0015/0072 (398 lines)
│   │   ├── netfosdl.pas        INT 14h hook, Keep (TSR), X00 params (323 lines)
│   │   └── SERIAL_README.md    Driver documentation
│   ├── fossil_dos.pas          DOS FOSSIL interface
│   ├── netmodem.pas            DOS main program
│   ├── fpc-sockets-request.md  Socket API request for fpc264irc
│   └── retired/                Superseded DOS code
│
├── driver/                     ── VxD PASCAL PORT ──
│   ├── pascal-port/             VxD → Pascal port (wrench)
│   │   ├── NM_VxD_Types.pas    Packed records matching ASM structs (205 lines)
│   │   ├── VXD_PORT_PLAN.md    6-phase port plan
│   │   └── vxd_port_test.pas   7-phase test harness (39 tests)
│   └── src-retired-README.md   Points to attic/driver-vxd-original/
│       ├── VPICD.INC           Virtual PIC
│       ├── VWIN32.INC          VWin32 interface
│       ├── COPYING             Original license
│       ├── INFO                Driver info
│       ├── LICENSE-NOTICE.md   License notice
│       └── README.md           Directory documentation
│
├── libs/                       ── LIBRARIES ──
│   └── synapse/                Ararat Synapse socket library (18 files)
│       ├── blcksock.pas        TBlockSocket — core socket class
│       ├── synautil.pas        Utility functions
│       ├── synaser.pas         Serial port (not used — we have serial.pas)
│       ├── synacode.pas        Encoding utilities
│       ├── synafpc.pas         FPC compatibility
│       ├── synaip.pas          IP address utilities
│       ├── synsock.pas         Socket definitions
│       ├── smtpsend.pas        SMTP client (Synapse)
│       ├── *.inc               Platform includes (win32, linux, posix, etc.)
│       ├── SYNAPSE_README.md   Upstream documentation
│       └── README.md           Directory documentation
│
├── tests/                      ── INTEGRATION TESTS ──
│   ├── test_binary_safety.pas  R3.3: 37 tests — all 256 bytes, CP437, IAC, Zmodem
│   ├── test_m3_server.pas      M3: headless echo server
│   ├── test_m3_client.pas      M3: test client (6 tests)
│   ├── test_r34_multinode.pas  R3.4: 3 simultaneous nodes (25 tests)
│   ├── test_d4_fossil.pas      D4: FOSSIL conformance (37 tests, DOS-only)
│   └── test_d5_relay.pas       D5: direct UART relay (50 tests)
│
├── out/                        ── COMPILED BINARIES ──
│   ├── i386/
│   │   ├── NMServer.exe        2.6M Win32 PE32 (fpc264irc)
│   │   ├── NMConfig.exe        Config tool
│   │   ├── NMServer.res        Server resources
│   │   ├── NMConfig.res        Config resources
│   │   └── NETMODEM.CPL        Original Dedrick Allen control panel applet
│   └── win32/
│       ├── NMServer.exe        2.0M Win32 PE32 (FPC 3.2.2)
│       ├── NMConfig.exe        Config tool
│       └── NETMODEM.CPL        Control panel applet
│
├── cpl/                        ── CONTROL PANEL APPLET ──
│   ├── NetModemCPL.pas         CPL source
│   ├── original_forms/         Dedrick's original Delphi forms (6 .dfm files)
│   └── resources/              CPL icons
│
├── docs/                       ── DOCUMENTATION (63 files) ──
│   ├── index.htm               Color-coded doc index with phase status
│   ├── DEBUGGER_GUIDE.md       Plain English debugger reference
│   ├── R42_com0com_NT_path.md  NT virtual COM port setup guide
│   ├── R43_UMDF2_virtual_COM.md UMDF2 driver specification
│   ├── serial_irq_plan.md      ISR + ring buffer plan (implemented)
│   ├── DRIVER_INTERFACE.md     Driver interface specification
│   ├── GUI_BLUEPRINT.md        GUI design blueprint
│   ├── BUILD.md                Build instructions
│   ├── BUGS.md                 Known bugs
│   ├── original/               Dedrick's original docs (ATCOMNDS, README, WHATSNEW)
│   ├── test/                   Older test files (M0-M1 era, 14 files)
│   └── ... (50+ architecture, audit, and protocol docs)
│
├── InnoIRC561/                 ── INNO SETUP (FPC PORT) ──
│   ├── README.md               Inno Setup 5.6.1 FPC port documentation
│   ├── INNO_FPC_PORT.md        Port details
│   ├── INNO_ORIGINAL_SOURCE.md Original source notes
│   ├── netmodem2irc.iss        Installer script
│   ├── lzma/                   LZMA object files (3 .o files)
│   ├── out/                    Built Inno binaries (Compil32, ISCC, ISCmplr, etc.)
│   ├── src/                    Inno Setup 5.6.1 source (vendored, ~700 files)
│   └── superseded/             Old Inno docs (3 files)
│
├── history/                    ── ORIGINAL ARTIFACTS ──
│   ├── ORIGINAL_NETMODEM.md    Recovery story
│   ├── FILE_ID.DIZ             Original BBS description file
│   ├── NETMODEM.CPL            Original control panel applet
│   ├── net32_1b4.zip           Dedrick's NetModem/32 beta 4 installer
│   ├── net32_b4/               Extracted installer (SETUP.EXE + packages)
│   ├── netmdb15.zip            NetModem DOS 1.5 (Dedrick's DOS version)
│   └── netmdb15/               Extracted DOS version (NETFOSSL.EXE, NETMODEM.EXE)
│
├── attic/                       Retired code (historical)
│   ├── driver-vxd-original/     NETMODEM.ASM (5,712 lines, Dedrick Allen)
│   ├── docs/                    50 retired planning docs
│   ├── README.md               What's here and why
│   ├── WIN32COM.PAS            Old Win32 COM port code
│   ├── docs/                   Old docs (6 files, superseded by docs/)
│   ├── netmodem2irc_CREDITS.md Old credits
│   └── watt32/                 Watt-32 TCP stubs (retired)
│
└── .github/
    └── description             GitHub repo description
```

## File Counts

| Directory | Files | What |
|-----------|-------|------|
| engine/ | 22 units + 28 tests | Core modem emulation engine |
| server/ | 8 + resources | NMServer GUI (Lazarus/LCL) |
| config/ | 4 + resources | NMConfig GUI |
| common/ | 2 | Shared VxD interface |
| dos/driver/ | 5 | FOSSIL driver (serial + IRQ + dispatch) |
| dos/ | 4 + retired | DOS target code |
| driver/pascal-port/ | 3 | VxD → Pascal port (types, plan, test) |
| libs/synapse/ | 18 | Ararat Synapse socket library |
| tests/ | 6 | Integration test suites (156 tests) |
| out/ | 10 | Compiled binaries |
| cpl/ | 2 + forms + resources | Control panel applet |
| docs/ | 63 | Architecture, audits, guides, specs |
| InnoIRC561/ | ~720 | Inno Setup FPC port (mostly vendored source) |
| history/ | 15 | Original Dedrick Allen artifacts |
| attic/ | 10 | Superseded code and docs |
| root | 13 | README, ROADMAP, LICENSE, Makefile, etc. |
| **Total** | **878** | |
