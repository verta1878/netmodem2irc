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
