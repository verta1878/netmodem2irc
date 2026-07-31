# netmodem2irc

Revival of Dedrick Allen's **NetModem/32** (32-bit FOSSIL Telnet server, 1997-2001)
for modern Windows, with a portable, tested Pascal modem-emulation engine.

> *"The virtual COM port is the foundation — without it, DOS BBS software is dead hardware. netmodem2irc makes DOS Mystic work on the modern internet. The FOSSIL driver, the serial code, the modem examples — they're not legacy, they're the bridge."*
>
> — Antonio Rico (verta1878)

## Repository

```
netmodem2irc/
│
├── engine/                        ← the core (24 Pascal units)
│   ├── NM_UART16550.pas              16550 UART emulation (registers, RX/TX rings)
│   ├── NM_DebugView.pas              protocol analyzer — LED panel, event log (1,455 lines)
│   ├── NM_DirectRelay.pas            TCP↔UART bypass, no FOSSIL overhead (299 lines)
│   ├── NM_Debug.pas                  three-channel debug (OutputDebugString, file, callback)
│   ├── NM_ServerBridge.pas           server bridge (listen, accept, pump, 99 nodes)
│   ├── NM_Node.pas                   node/connection manager
│   ├── NM_SynapseLink.pas            socket link with debug logging
│   ├── NM_SeamProtocol.pas           SEAM length-prefixed binary framing
│   ├── NM_SeamSender.pas             SEAM frame sender
│   ├── NM_ServerLink.pas             server link interface
│   ├── NetTransport.pas              Telnet BINARY negotiation, IAC doubling
│   ├── NM_Fossil.pas                 FOSSIL function emulation
│   ├── NM_FossilDriver.pas           FOSSIL driver interface
│   ├── NM_ATCommand.pas              AT modem command parser
│   ├── NM_Config.pas                 configuration records
│   ├── NM_ConfigApply.pas            apply config to running engine
│   ├── NM_DefaultConfig.pas          factory defaults
│   ├── NM_GlobalConfig.pas           global config singleton
│   ├── NM_Int14ISR.pas               INT 14h ISR placeholder
│   ├── NM_TSR.pas                    TSR (terminate-stay-resident) support
│   ├── NM_TSRResident.pas            TSR resident code
│   ├── NM_NamedPipeLink.pas          named pipe transport (for UMDF2 driver)
│   ├── NM_Listserv.pas               mailing list server (future)
│   └── NM_AutoNews.pas               auto-news feature (future)
│
├── server/                        ← the GUI application
│   ├── NMServer.lpr                  Lazarus project — main program
│   ├── NetModemServer.lpr            alternate entry point (Windows-only)
│   ├── MainForm.pas                  main window + debug panel (R1.5)
│   └── SplashForm.pas                splash screen
│
├── common/                        ← shared between engine + server
│   ├── NMVxD.pas                     VxD interface (cross-platform)
│   └── NetModemVxD.pas               VxD interface (Windows-only)
│
├── tests/                         ← 156 tests, 0 failures
│   ├── test_binary_safety.pas        R3.3: 37 tests — CP437, Zmodem, IAC, nulls, 64KB bulk
│   ├── test_m3_server.pas            M3: headless echo server (TCP accept + echo)
│   ├── test_m3_client.pas            M3: 6 tests — ASCII, CP437, high bytes, Zmodem, 4KB
│   ├── test_r34_multinode.pas        R3.4: 25 tests — 3 nodes, no cross-talk, disconnect
│   ├── test_d4_fossil.pas            D4: 37 tests — every INT 14h function (DOS-only)
│   └── test_d5_relay.pas             D5: 50 tests — direct UART relay, DCD, RING, bulk
│
├── dos/driver/                    ← DOS FOSSIL driver (TSR)
│   ├── serial.pas                    real 16550 UART — Port[] I/O (sysop/0, 203 lines)
│   ├── serial_irq.pas                ISR + 4KB ring buffer, 8259 PIC (kiddo, 195 lines)
│   ├── fossil.pas                    FOSSIL dispatch FSC-0015/0072 (398 lines)
│   └── netfosdl.pas                  INT 14h hook, Keep (TSR), X00 params (323 lines)
│
├── driver/src/                    ← Dedrick Allen's original VxD source (16 files)
│   ├── NETMODEM.ASM                  172K — the original Windows 95/98 VxD
│   ├── NETMODEM.INC, .DEF, .RC       driver build files
│   ├── VMM.INC, VCOMM.INC, etc.     Windows DDK includes
│   ├── RESOURCE.H                    resource definitions
│   └── README.md                     provenance notes
│
├── libs/synapse/                  ← Ararat Synapse socket library (16 files)
│   ├── blcksock.pas                  TBlockSocket — core TCP/UDP
│   ├── synautil.pas, synaser.pas     utilities, serial
│   ├── synacode.pas, synaip.pas      encoding, IP helpers
│   └── synafpc.pas, synsock.pas      FPC bindings
│
├── out/                           ← compiled binaries
│   ├── i386/
│   │   ├── NMServer.exe              2.0M Win32 PE32 (FPC 3.2.2)
│   │   ├── NMConfig.exe              configuration tool
│   │   └── NETMODEM.CPL              control panel applet (Dedrick Allen original)
│   └── win32/                        same binaries, alternate path
│
├── InnoIRC561/                    ← Inno Setup 5.6.1 (FPC port)
│   ├── out/
│   │   ├── ISCC.exe                  command-line compiler
│   │   ├── Compil32.exe              GUI compiler
│   │   ├── Setup.exe                 installer stub
│   │   └── ISCmplr.dll + 10 DLLs    installer runtime
│   ├── src/issrc-is-5_6_1/          upstream Inno Setup source
│   ├── lzma/                         LZMA compression objects
│   └── netmodem2irc.iss              installer script
│
├── config/                        ← NMConfig source
├── cpl/                           ← control panel applet source
├── history/                       ← Dedrick Allen's original files (7 files)
├── attic/                         ← superseded docs (6 files)
│
├── docs/                          ← 64 documents
│   ├── index.htm                     color-coded doc index with phase status
│   ├── DEBUGGER_GUIDE.md             plain English debugger reference
│   ├── R42_com0com_NT_path.md        NT virtual COM port setup guide
│   ├── R43_UMDF2_virtual_COM.md      UMDF2 driver specification
│   ├── serial_irq_plan.md            ISR + ring buffer plan (implemented)
│   ├── DRIVER_INTERFACE.md           FOSSIL/VxD interface specification
│   └── ... 58 more (architecture, audits, protocols, build guides)
│
├── README.md                      ← this file
├── ROADMAP.md                     3 tracks, 24 phases, coding standards
├── Makefile                       make / make tests / make win32 / make dos
├── build.sh                       build script
├── LICENSE                        GPLv3
├── AUTHORS                        team credits
├── CREDITS.md                     full credits with specs + upstream
├── CHANGELOG.md                   version history
├── LICENSES.md                    third-party license inventory
├── THIRD_PARTY.md                 third-party component list
└── .gitattributes                 line ending rules (CRLF for .pas/.asm)

879 files total. 24 engine units. 6 test suites (156 tests).
4 DOS driver files. 16 Synapse files. 16 VxD source files.
64 docs. 12 Inno Setup binaries. 5 compiled binaries.
```

## Status

Three independent tracks. DOS doesn't feed i386. The installer packages i386.

### i386 — the server (the core product)

| Milestone | What | Status |
|---|---|---|
| M0 | Recover Dedrick's original source | ✅ |
| M1 | Engine integrated — 38 tests, 0 failures | ✅ |
| M2 | Builds on Windows — dual compiler verified | ✅ |
| M3 | Live connection — 6 tests pass | ✅ |
| M4 | Virtual COM path (VxD 9x / com0com NT / UMDF2) | ⬜ |
| M5 | Tagged installable release | ⬜ |

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
| Inno 9-10 | Setup.exe + ISCmplr runtime AV | ⬜ needs Windows |

### Release milestones

| Phase | What | Status |
|---|---|---|
| R1.1-R1.7 | Debug infrastructure (NM_Debug + panel + SynapseLink) | ✅ |
| R2.1-R2.5 | Setup.exe + ISCmplr AV fix | ⬜ needs Windows |
| R3.3 | Binary safety — 37 tests pass | ✅ |
| R3.4 | Multinode — 25 tests pass (3 simultaneous nodes) | ✅ |
| R4.1 | Win9x VxD test | ⬜ needs Win98 VM |
| R4.2 | NT com0com path — documented | ✅ |
| R4.3 | NT UMDF2 driver — specified | ✅ |
| R5.1 | Inno installer packaging | ⬜ needs Windows |

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
│   ├── NM_Int14ISR.pas         INT 14h ISR far pointer placeholder
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
├── driver/                     ── ORIGINAL VxD SOURCE ──
│   └── src/                    Dedrick Allen's NetModem VxD (16 files)
│       ├── NETMODEM.ASM        172K x86 assembly — the VxD
│       ├── NETMODEM.DEF        Module definition
│       ├── NETMODEM.INC        NetModem include
│       ├── NETMODEM.RC         Resource script
│       ├── RESOURCE.H          Resource header
│       ├── REGDEF.INC          Register definitions
│       ├── SHELL.INC           Shell interface
│       ├── VCOMM.INC           VCOMM interface
│       ├── VCOMMW32.INC        VCOMM Win32 interface
│       ├── VMM.INC             Virtual Machine Manager
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
│       ├── smtpsend.pas        Zero-byte placeholder (future mailing list)
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
├── attic/                      ── SUPERSEDED / ARCHIVE ──
│   ├── README.md               What's here and why
│   ├── WIN32COM.PAS            Old Win32 COM port code
│   ├── docs/                   Old docs (6 files, superseded by docs/)
│   ├── netmodem2irc_CREDITS.md Old credits
│   └── watt32/                 Watt-32 TCP stack stubs (for DOS)
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
| driver/src/ | 16 | Original VxD assembly source |
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
