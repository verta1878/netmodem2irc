# netmodem2irc OS/2 Port — Phase Plan

## Goal

Native OS/2 NMServer that runs PCBoard 15.4 (PCBOARD2.EXE)
without DOSBox or Wine. Full native stack:

```
caller (telnet)
  → NMServer.exe (OS/2 native)
    → FOSSIL (OS/2 native — SIO/VMODEM or pcbfoss)
      → PCBOARD2.EXE (OS/2 native — OpenWatcom built)
```

## Prerequisites

| Item | Status |
|------|--------|
| OS/2 Toolkit 4.5 (SDK) | ✅ have it — 3,377 files, sockets + serial + PM |
| PCBOARD2.EXE (OS/2) | ✅ hexadecimal cross-compiled with OpenWatcom 2.0 |
| openwatcomirc | ✅ sysop/0 built — 4 targets including OS/2 |
| fpc264irc | ✅ check for i386-os2 target support |
| netmodem2irc engine | ✅ pure Pascal — 24 units, 156 tests |

## Compiler Decision

Two paths — pick one:

**Path A: FPC cross-compile to OS/2**
- FPC has an OS/2 target (i386-os2, EMX runtime)
- fpc264irc may already support it (sysop/0 to verify)
- Same Pascal source, same test suite
- Fastest path if fpc264irc has the target

**Path B: OpenWatcom C port**
- openwatcomirc already builds OS/2 binaries
- Rewrite engine in C (serial.c, tcp.c, fossil.c)
- Same architecture, different language
- Aligns with pcbrevival's C codebase
- Longer path but unifies the toolchain

**Recommendation:** Path A first (FPC). If fpc264irc can't target OS/2,
fall back to Path B. The engine is proven in Pascal — don't rewrite
what already works unless the compiler forces it.

## Phases

### Phase O1: Verify FPC OS/2 Target
- Check if fpc264irc has i386-os2 cross-compiler
- If yes: compile a hello world for OS/2
- If no: check stock FPC 3.2.2 for OS/2 target
- If neither: fall back to Path B (OpenWatcom C port)

**Deliverable:** OS/2 hello world binary, verified on ArcaOS/eCS/OS2

### Phase O2: OS/2 Sockets Unit
- OS/2 TCP/IP uses BSD socket API via so32dll.dll / tcp32dll.dll
- FPC's Synapse may already support OS/2 (uses BSD sockets)
- If not: write os2sockets.pas wrapping DosLoadModule + socket calls
- Test: TCP echo server on OS/2, connect from telnet

**SDK files needed:**
```
h/sys/socket.h        — socket(), bind(), listen(), accept()
h/netinet/in.h        — sockaddr_in, INADDR_ANY
h/arpa/inet.h         — inet_addr(), inet_ntoa()
lib/so32dll.lib       — import library for linking
lib/tcp32dll.lib      — TCP/IP import library
```

**Deliverable:** TCP echo server compiles and runs on OS/2

### Phase O3: Engine Cross-Compile
- Cross-compile the pure Pascal engine units to OS/2
- These should port unchanged (no platform-specific code):
  - NM_UART16550 (register emulation)
  - NM_Debug (three-channel debug)
  - NM_DebugView (protocol analyzer, 1,455 lines)
  - NM_DirectRelay (TCP↔UART bypass)
  - NM_Config, NM_DefaultConfig, NM_GlobalConfig
  - NM_ATCommand (AT parser)
  - NM_Fossil (FOSSIL emulation)
  - NM_FossilDriver (FOSSIL interface)
  - NM_Node (node manager)
  - NM_SeamProtocol (binary framing)
  - NM_ServerBridge (listen, accept, pump)
  - NetTransport (Telnet BINARY, IAC)
- Run test suite on OS/2

**Deliverable:** 24 engine units compile for OS/2, tests pass

### Phase O4: OS/2 Serial Port
- OS/2 serial I/O uses DosOpen + DosDevIOCtl
- Write serial_os2.pas:

```pascal
// Open serial port
DosOpen('COM1', Handle, Action, 0, 0,
  OPEN_ACTION_OPEN_IF_EXISTS, OPEN_SHARE_DENYREADWRITE or
  OPEN_ACCESS_READWRITE, nil);

// Set baud rate
DosDevIOCtl(Handle, IOCTL_ASYNC, ASYNC_SETBAUDRATE,
  @BaudRate, SizeOf(BaudRate), @ParmLen,
  nil, 0, @DataLen);

// Get modem status (DCD, DSR, CTS, RI)
DosDevIOCtl(Handle, IOCTL_ASYNC, ASYNC_GETMODEMINPUT,
  nil, 0, @ParmLen,
  @ModemStatus, SizeOf(ModemStatus), @DataLen);
```

- Implement serial_ext.pas functions for OS/2:
  - SerGetDCD → DosDevIOCtl ASYNC_GETMODEMINPUT
  - SerDataAvailable → DosDevIOCtl ASYNC_GETINQUECOUNT
  - SerSetFIFO → DosDevIOCtl ASYNC_SETENHANCEDMODEPARMS
  - SerDetectUART → DosDevIOCtl ASYNC_GETCOMMSTATUS

**SDK files needed:**
```
h/bsedev.h            — DosDevIOCtl definitions
h/wpserial.h          — serial port constants
IOCTL_ASYNC category  — async serial IOCTLs
```

**Deliverable:** serial_ext.pas works on OS/2, DCD/data available tested

### Phase O5: OS/2 NM_SynapseLink
- Adapt NM_SynapseLink to use OS/2 sockets
- If Synapse works on OS/2: minimal changes (socket API is BSD)
- If not: write NM_OS2SocketLink replacing Synapse with
  direct so32dll.dll calls
- Wire into NM_ServerBridge

**Deliverable:** NMServer accepts Telnet connection on OS/2

### Phase O6: OS/2 GUI (PM or VIO)
Two options:

**Option A: Presentation Manager (PM) GUI**
- FPC/Lazarus has an OS/2 PM widgetset (basic)
- MainForm.pas with TMemo debug panel
- Same look as Win32 version
- Most work — PM programming is complex

**Option B: VIO Console (text mode)**
- OS/2 VIO (Video I/O) subsystem — text-mode console
- NMServer runs as a console app
- Debug output to stdout or log file
- LED panel as text: `[*]AA [*]CD [ ]OH [~]RD`
- Less work — ship faster

**Recommendation:** Option B first (VIO console). Get it working.
Add PM GUI later if needed. PCBoard itself runs in a VIO session.

**Deliverable:** NMServer runs on OS/2 (console or PM)

### Phase O7: FOSSIL Bridge
- OS/2 FOSSIL options:
  - SIO (Ray Gwinn's serial I/O — standard OS/2 FOSSIL)
  - VMODEM (virtual modem for OS/2)
  - pcbfoss (sysop/0's FOSSIL from pcbis — 620 lines)
- NMServer ↔ FOSSIL via named pipes or shared memory
- PCBoard opens COM port → FOSSIL intercepts → NMServer bridges to TCP

**Deliverable:** PCBoard answers a Telnet call through NMServer on OS/2

### Phase O8: Test Suite on OS/2
- Port and run all 156 tests on OS/2
- R3.3 binary safety (37 tests)
- M3 live connection (6 tests)
- R3.4 multinode (25 tests)
- D5 direct relay (50 tests)
- D4 FOSSIL conformance (37 tests — against pcbfoss or SIO)

**Deliverable:** 156 tests pass on OS/2

### Phase O9: Integration Test
- Full stack on OS/2:
  1. Start NMServer (listening on port 23)
  2. Load FOSSIL driver (SIO or pcbfoss)
  3. Start PCBOARD2.EXE
  4. Telnet in from another machine
  5. Login, browse menus, download a file, logout
- Verify the debugger traces the full session

**Deliverable:** PCBoard 15.4 serves a caller on OS/2 via NMServer

### Phase O10: Package and Release
- Create OS/2 installer (or WarpIN package)
- Bundle: NMServer + config + FOSSIL + docs
- README with OS/2-specific setup
- Test on ArcaOS (modern OS/2 distribution)

**Deliverable:** netmodem2irc-os2 release package

## Platform-Specific Code Map

| Unit | Win32 | OS/2 | Linux | Change needed |
|------|-------|------|-------|--------------|
| NM_UART16550 | pure Pascal | same | same | none |
| NM_Debug | OutputDebugString | DosWrite to log | syslog | output channel |
| NM_DebugView | pure Pascal | same | same | none |
| NM_DirectRelay | pure Pascal | same | same | none |
| NM_SynapseLink | Winsock | so32dll | BSD sockets | socket init |
| NetTransport | pure Pascal | same | same | none |
| NM_Node | pure Pascal | same | same | none |
| NM_ServerBridge | pure Pascal | same | same | none |
| MainForm | LCL Win32 | LCL PM or VIO | LCL GTK/nogui | GUI backend |
| serial_ext | Win32 API | DosDevIOCtl | ioctl | serial API |
| NMVxD | VxD calls | N/A | N/A | remove/stub |

**Pure Pascal (no changes):** 18 of 25 units
**Platform-specific:** 7 units (sockets, serial, GUI, debug output)

## Test Matrix

| Test | OS/2 | Win32 | Linux/Wine |
|------|------|-------|------------|
| Engine (M0-M1) | O3 | ✅ | ✅ |
| Binary safety (R3.3) | O8 | ✅ | ✅ |
| Live connection (M3) | O8 | ✅ | ✅ |
| Multinode (R3.4) | O8 | ✅ | ✅ |
| Direct relay (D5) | O8 | ✅ | ✅ |
| FOSSIL conformance (D4) | O8 | needs 386 | needs 386 |
| Full stack (PCBoard) | O9 | needs data | DOSBox ✅ |

## Timeline Estimate

| Phase | Effort | Depends on |
|-------|--------|------------|
| O1 Verify FPC target | 1 session | sysop/0 |
| O2 OS/2 sockets | 1 session | O1 |
| O3 Engine cross-compile | 1 session | O1 |
| O4 OS/2 serial | 1 session | O2, SDK |
| O5 SynapseLink OS/2 | 1 session | O2 |
| O6 GUI (VIO console) | 1 session | O3 |
| O7 FOSSIL bridge | 1-2 sessions | O4, O5 |
| O8 Test suite | 1 session | O3, O5 |
| O9 Integration test | 1 session | O7, O8 |
| O10 Package | 1 session | O9 |

**Total: ~10 sessions.** Phases O2-O5 can run in parallel.

## References

- OS/2 Toolkit 4.5 — h/sys/socket.h, h/bsedev.h, lib/so32dll.lib
- FPC OS/2 target — i386-os2, EMX runtime
- openwatcomirc — C alternative if FPC can't target OS/2
- pcbfoss — sysop/0's FOSSIL driver (620 lines, from NM_Fossil)
- PCBOARD2.EXE — hexadecimal's OS/2 build (OpenWatcom 2.0)
- ArcaOS — modern OS/2 distribution for testing
