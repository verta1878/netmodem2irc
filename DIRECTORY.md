# netmodem2irc — Directory Map

879 files. Revival of Dedrick Allen's NetModem/32 (1997-2001).
Virtual modem engine: TCP/Telnet ↔ FOSSIL ↔ BBS door.
156 tests, 0 failures. GPLv3.

```
netmodem2irc/
│
├── README.md                    Project overview, status, build instructions
├── ROADMAP.md                   3 tracks, all phases, coding standards
├── LICENSE                      GPLv3
├── CREDITS.md                   Team + upstream credits
├── CHANGELOG.md                 Version history
├── AUTHORS                      Contributors
├── DIRECTORY.md                 This file
├── Makefile                     Build: make, make tests, make win32, make dos
├── THIRD_PARTY.md               Third-party license inventory
│
├── engine/                      ── The virtual modem engine (24 units) ──
│   ├── NM_UART16550.pas             16550 UART emulation (registers, RX/TX rings)
│   ├── NM_Debug.pas                 3-channel debug (OutputDebugString, log, callback)
│   ├── NM_DebugView.pas             Protocol analyzer — 1,455 lines
│   │                                  USR Courier LED panel (AA CD OH RD SD TR MR CS HS ARQ)
│   │                                  Human-readable event log + data stream
│   │                                  ANSI decoder, AT command scanner, Zmodem detector
│   │                                  Session lifecycle, throughput, export to file
│   ├── NM_DirectRelay.pas           Direct TCP↔UART relay — bypasses FOSSIL (299 lines)
│   ├── NM_Config.pas                Registry configuration
│   ├── NM_DefaultConfig.pas         Default configuration values
│   ├── NM_GlobalConfig.pas          Global config singleton
│   ├── NM_ConfigApply.pas           Apply config changes at runtime
│   ├── NM_ATCommand.pas             AT modem command parser (ATDT, ATH, ATA, ATZ)
│   ├── NM_Fossil.pas                FOSSIL function emulation (Fn $00-$1B)
│   ├── NM_FossilDriver.pas          FOSSIL driver interface
│   ├── NM_Node.pas                  Node manager (99 nodes, TNodeManager)
│   ├── NM_SeamProtocol.pas          SEAM length-prefixed binary framing
│   ├── NM_ServerBridge.pas          Server bridge (listen, accept, pump)
│   ├── NM_SynapseLink.pas           Socket link with R1.7 debug logging
│   ├── NM_NamedPipeLink.pas         Named pipe transport (for UMDF2 driver)
│   ├── NM_Int14ISR.pas              INT 14h ISR far pointer
│   ├── NM_TSR.pas                   TSR support
│   ├── NM_TSRResident.pas           TSR resident code
│   ├── NM_Listserv.pas              Mailing list server (future)
│   ├── NM_AutoNews.pas              Auto-news feature
│   ├── NM_SeamSender.pas            SEAM packet sender
│   └── NetTransport.pas             Telnet BINARY negotiation, IAC doubling
│
├── server/                      ── NMServer GUI (Lazarus/LCL) ──
│   ├── NMServer.lpr                 Main program (Lazarus project)
│   ├── NetModemServer.lpr           Alternate entry point
│   ├── MainForm.pas                 Main window (node list, debug panel, menus)
│   └── SplashForm.pas               Splash screen
│
├── common/                      ── Shared units ──
│   ├── NMVxD.pas                    VxD interface (cross-platform)
│   └── NetModemVxD.pas              VxD interface (Windows-only)
│
├── libs/synapse/                ── Ararat Synapse socket library (18 files) ──
│   ├── blcksock.pas                 TBlockSocket — core TCP/UDP
│   ├── synautil.pas                 Utility functions
│   ├── synaser.pas                  Serial port
│   ├── synacode.pas                 Encoding (Base64, URL, etc.)
│   ├── synafpc.pas                  FPC compatibility
│   ├── synaip.pas                   IP address utilities
│   ├── synsock.pas                  Socket API wrapper
│   ├── smtpsend.pas                 SMTP (zero-byte placeholder)
│   ├── jedi.inc                     JEDI compatibility defines
│   ├── sswin32.inc                  Win32 socket includes
│   ├── sslinux.inc                  Linux socket includes
│   ├── ssfpc.inc                    FPC socket includes
│   ├── ssposix.inc                  POSIX socket includes
│   ├── ssdotnet.inc                 .NET socket includes
│   ├── ssos2ws1.inc                 OS/2 socket includes
│   ├── kylix.inc                    Kylix compatibility
│   ├── README.md                    Synapse documentation
│   └── SYNAPSE_README.md            Upstream readme
│
├── dos/driver/                  ── DOS FOSSIL driver (netfosdl) ──
│   ├── serial.pas                   Real 16550 UART — Port[] I/O (sysop/0, 203 lines)
│   ├── serial_irq.pas               ISR + 4KB ring buffer, 8259 PIC (kiddo, 195 lines)
│   ├── fossil.pas                   FOSSIL dispatch FSC-0015/0072 (398 lines)
│   ├── netfosdl.pas                 INT 14h hook, Keep (TSR), X00 params (323 lines)
│   └── SERIAL_README.md             Driver documentation
│
├── driver/src/                  ── Dedrick Allen's original VxD source (16 files) ──
│   ├── NETMODEM.ASM                 Original VxD (172K x86 assembly)
│   ├── NETMODEM.INC                 Main include
│   ├── NETMODEM.DEF                 Module definition
│   ├── NETMODEM.RC                  Resource script
│   ├── RESOURCE.H                   Resource header
│   ├── REGDEF.INC                   Register definitions
│   ├── SHELL.INC                    Shell interface
│   ├── VCOMM.INC                    VCOMM API
│   ├── VCOMMW32.INC                 VCOMM Win32 API
│   ├── VMM.INC                      Virtual Machine Manager
│   ├── VPICD.INC                    Virtual PIC driver
│   ├── VWIN32.INC                   VWin32 API
│   ├── COPYING                      Original license
│   ├── INFO                         Original info file
│   ├── LICENSE-NOTICE.md            License notice
│   └── README.md                    Directory documentation
│
├── tests/                       ── Test suites (156 tests total) ──
│   ├── test_binary_safety.pas       R3.3: 37 tests — 8-bit clean transport
│   │                                  All 256 bytes, CP437, IAC, Zmodem, nulls, 64KB bulk
│   ├── test_m3_server.pas           M3: headless echo server (231 lines)
│   ├── test_m3_client.pas           M3: test client — 6 tests (212 lines)
│   │                                  ASCII, CP437, high bytes, nulls, Zmodem, 4KB bulk
│   ├── test_r34_multinode.pas       R3.4: 25 tests — 3 simultaneous nodes
│   │                                  Independent echo, no cross-talk, disconnect survival
│   ├── test_d4_fossil.pas           D4: FOSSIL conformance — 37 tests (DOS-only)
│   │                                  Every INT 14h function against FSC-0015/0072
│   └── test_d5_relay.pas            D5: direct relay — 50 tests
│                                      FeedByte, DrainByte, DCD, RING, pump cycle, 4KB bulk
│
├── docs/                        ── Documentation (64 files) ──
│   ├── index.htm                    Color-coded doc index with phase status
│   ├── DEBUGGER_GUIDE.md            Plain English debugger reference
│   ├── R42_com0com_NT_path.md       NT virtual COM port setup guide
│   ├── R43_UMDF2_virtual_COM.md     UMDF2 driver specification
│   ├── serial_irq_plan.md           ISR + ring buffer plan (implemented)
│   ├── DRIVER_INTERFACE.md          FOSSIL driver interface spec
│   ├── netmodem2irc_recovery.md     vBulletin crash story + source recovery
│   ├── netmodem2irc_protocols_and_libs.md   Every protocol + library with specs
│   ├── seeing_the_structure.md      Structural audit method
│   ├── fpc264irc_sockets_lifecycle.md   Socket exit discipline
│   └── ...                          58 more architecture, audit, build docs
│
├── out/                         ── Built binaries ──
│   └── i386/
│       └── NMServer.exe             2.0M Win32 PE32 (FPC 3.2.2 cross-compile)
│
├── history/                     ── Project history (7 files) ──
│   ├── netmodem32-original.zip      Dedrick Allen's original distribution
│   └── ...                          Recovery notes, session logs
│
├── attic/                       ── Superseded docs (11 files) ──
│   └── docs/                        Earlier versions of architecture docs
│
└── InnoIRC561/                  ── Inno Setup 5.6.1 FPC port ──
    ├── README.md                    Inno Setup port documentation
    ├── INNO_FPC_PORT.md             Port notes
    ├── netmodem2irc.iss             Installer script
    ├── lzma/                        LZMA decompression objects
    ├── out/                         Built Inno binaries
    │   ├── Compil32.exe                 GUI compiler
    │   ├── ISCC.exe                     Command-line compiler
    │   ├── ISCmplr.dll                  Compiler DLL
    │   ├── Setup.exe                    Setup launcher
    │   └── ...                          DLLs, BMPs, templates
    └── src/                         Inno Setup 5.6.1 source (upstream)
```

## By the numbers

| Directory | Files | What |
|-----------|-------|------|
| engine/ | 24 | Virtual modem engine |
| server/ | 4 | NMServer GUI (LCL) |
| common/ | 2 | Shared VxD interface |
| libs/synapse/ | 18 | TCP/IP socket library |
| dos/driver/ | 5 | DOS FOSSIL driver |
| driver/src/ | 16 | Dedrick's original VxD |
| tests/ | 6 | Test suites (156 tests) |
| docs/ | 64 | Documentation |
| out/ | 1 | NMServer.exe binary |
| history/ | 7 | Project history |
| attic/ | 11 | Superseded docs |
| InnoIRC561/ | ~750 | Inno Setup port |
| root | 11 | README, ROADMAP, LICENSE, etc. |
| **Total** | **879** | |

## Team

| Who | What |
|-----|------|
| verta1878 | Project lead, architect |
| sysop/0 | Compiler (fpc264irc), terminal, serial UART |
| kiddo | Serial IRQ ring buffer, protocols, RIPscrip engine |
| wrench | Engine, debugger, network architecture |
| evga | Display, RIPView, Mystic monitor |
| hexadecimal | PCBoard 15.4 (pcbrevival) |
| g00r00 | Mystic BBS (GPLv3 upstream) |
| Dedrick Allen | Original NetModem/32 (1997-2001) |
