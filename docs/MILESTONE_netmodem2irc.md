# MILESTONE — netmodem2irc

Where the NetModem/32 revival stands, and the work ahead. Reviving Dedrick
Allen's NetModem/32 (32-bit FOSSIL Telnet server, 1997-2001) for modern Windows,
with a portable, tested modem-emulation stack.

## M1 COMPLETE (this session) — engine integrated into the server
The tested engine is now wired to the repo's server via NM_ServerBridge:
CM_* message handlers + the driver TIOStruct byte-glue (ServiceDriverIO), all
built and TESTED (11 tests, 0 failures, on FPC 2.6.4 + 3.2.2). Full MainForm
integration code written (netmodem2irc_M1_COMPLETE.md). Remaining M1 items are
user actions: push to repo + rename netmodem2 -> netmodem2irc, then the first
Windows compile (which begins M2).

## DONE (this session) — the emulation stack, built + tested

Written from Dedrick's actual NETMODEM.ASM + published specs (16550/FOSSIL/Hayes),
matching the repo's Pascal style. Full suite: **8 units, 8 test programs, ~85
checks, 0 failures.** VERIFIED building AND passing on **stock FPC 2.6.4** (not
just 3.2.2) — the period-anchor compiler.

| Unit | What | Tests |
|------|------|-------|
| NM_UART16550   | NS-16550 UART emulation (register file, DLAB, TX/RX rings) | 14 |
| NM_Fossil      | FOSSIL INT 14h (init=1954h, full function table) | 17 |
| NetTransport   | Telnet transport, IAC/BINARY, all-256-byte binary-safe | 12 |
| NM_ATCommand   | Hayes AT, ATDT<host> -> dial, result codes from source | 12 |
| NM_Node        | per-node object + multinode manager (isolation proven) | 18 |
| NM_SynapseLink | real Synapse TCP socket link (compile-verified) | stub |
| NM_NamedPipeLink | named-pipe link = the driver seam | 13+4 |

Plus: **Synapse bundled** (real lib, modified-BSD, GPLv2-OK), **multinode** proven
(honors the original's "Comports 3-99"), **Dedrick's FILE_ID.DIZ preserved**,
**dial-OUT implemented** (the feature his alpha3 marked "coming soon").

## ARCHITECTURE — the three-tier virtual-COM strategy
- **A (goal, the "first"):** native user-mode UMDF2 virtual-COM driver in C/C++
  (follows Microsoft's MS-PL FakeModem sample) bridged to our Pascal brain over a
  named pipe. Nobody's built an open one for DOS-BBS-to-Telnet. DESIGN-stage
  (scoping doc done).
- **B (proof of concept):** the tested Pascal stack + NamedPipeLink. DONE/green.
- **C (last resort):** com0com.
The ISocketLink abstraction means the SAME tested transport drives a TCP socket
(Synapse) OR a named pipe (driver) OR com0com — proven by test.

## WORK AHEAD

### Make it a shipping app
1. **Synapse runtime test** — the -dHAS_SYNAPSE path is compile-verified vs real
   Synapse but NOT runtime-tested over a live BBS connection. Needs a Windows build.
2. **Option A C/C++ driver** — write the UMDF2 virtual-COM driver skeleton
   following the FakeModem sample; build/sign/test on Windows. (The frontier.)
3. **Named-pipe real I/O test** — the -dHAS_WINPIPE path on Windows against the
   driver.
4. **Wire to the server GUI** — connect TNodeManager to the server's CM_* window
   messages (CM_CONNECT_NODE, CM_DISCONNECT_NODE, CM_SEND_REMOTE_BREAK, etc.);
   the MainForm.pas TODOs.
5. **Installer** — Inno Setup for NT branch (free, Pascal-native), once the driver
   builds. 9x branch installer separately (VxD needs the DDK).

### 9x branch (separate, lower priority)
6. **VMM.INC** — VALID as-is (corrected: not corrupt); only needs MASM assemble to
   confirm. 9x VxD build also blocked by the underscore linker issue (a 9x-only
   concern; NT branch doesn't need it).

### ELECOM integration (parallel)
7. **ELECOM port** — EleBBS comms lib (VP-era) to modern FPC. BUFUNIT + ELEDEF
   building on 2.6.4; VP->FPC convention-fix pattern documented. FOS_COM =
   go32v2/DOS FOSSIL client (fpc264irc target) = the CLIENT side our NM_Fossil is
   the SERVER side of. Cross-check them (both use $1954 signature — good sign).

## Honest status line
netmodem2irc's modem-emulation BRAIN is done and tested. What remains is the
OS/hardware INTEGRATION (driver, live sockets, GUI wiring, installer) — the logic
those carry is built; they need a Windows build + real network to verify.

## Repo note
Repo to be renamed netmodem2 -> netmodem2irc. User holding repo; will resume.
Everything saved in the all_work_bundle archive.
