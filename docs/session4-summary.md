# Session 4 Summary — 2026-07-28/29 (late night)

## Transcript
/mnt/transcripts/2026-07-28-15-15-14-netmodem2irc-session3-docs-serial-openolms.txt
(continued from session 3 compaction)

## What Got Done

### netmodem2irc — 8 phases completed

| Phase | Status | Tests |
|-------|--------|-------|
| M2 | ✅ NMServer.exe 2.0M Win32 PE32 | cross-compiled from Linux |
| R3.3 | ✅ Binary safety | 37 tests pass |
| M3 | ✅ Live connection | 6 tests pass |
| R3.4 | ✅ Multinode (3 nodes) | 25 tests pass |
| R1.5 | ✅ Debug panel (TMemo) | compile-verified |
| R1.6 | ✅ Color-coded subsystem tags | compile-verified |
| R1.7 | ✅ Debug wired into SynapseLink | compile-verified |
| R4.2 | ✅ com0com docs | 75-line guide |
| R4.3 | ✅ UMDF2 spec | 180-line specification |

68 tests total, 0 failures.

### M2 — Win32 Cross-Compile
- FPC 3.2.2 ppcross386 + upstream unpatched FPC source (not Debian)
- Win32 RTL: 89 PPUs built
- Win32 packages: all built (100 package dirs)
- Win32 LCL: 136 PPUs cross-compiled from Linux
- Trick: compile forms.pp FIRST (breaks circular dep), then interfaces.pp
- Exclude FV from search path (App unit collision)
- NMServer.exe: 2.0M PE32 Win32 binary, no lazbuild needed
- Also verified: FPC 3.2.2 + Lazarus 3.0 nogui → 5.1M Linux ELF

### R3.3 — Binary Safety (37 tests)
- All 256 byte values survive round-trip
- CP437 box-drawing (128-255) pass through
- IAC ($FF) properly doubled/un-doubled
- IAC commands filtered from guest data stream
- Zmodem headers (ZPAD/ZDLE/ZBIN/ZHEX) not IAC
- Zmodem CRC-32 with $FF bytes doubled correctly
- Null bytes ($00) pass through
- CR/LF raw in BINARY mode
- SEAM length-prefix framing is binary-clean
- 64KB bulk binary (256 IAC bytes doubled, all recoverable)

### M3 — Live Connection (6 tests)
- Server listens on TCP port, client connects
- ASCII text (26 bytes) echoes correctly
- CP437 box-drawing (9 bytes) survives
- High bytes 128-254 (127 bytes) pass clean
- Null bytes pass through
- Zmodem header pattern survives
- 4KB bulk transfer verified (4,277 bytes in/out)

### R3.4 — Multinode (25 tests)
- 3 simultaneous clients connected
- Independent echo per node (20 bytes each, unique data)
- Interleaved sends — no cross-talk ($A0→node0, $A1→node1, $A2→node2)
- Disconnect node 1, nodes 0 and 2 still alive
- 1KB bulk transfer per node simultaneously

### R1.5-R1.7 — Debug Infrastructure
- R1.5: TMemo debug panel docked to MainForm bottom, hidden by default
  - Toggle via File > Debug Panel
  - 5000-line cap, auto-scroll
  - DebugSetLineHandler wired to OnDebugLine callback
- R1.6: Bracket-tagged subsystem prefixes with timestamps
  - [NMServer], [Synapse], [Transport], [UART], [FOSSIL], [Bridge]
- R1.7: NM_Debug wired into NM_SynapseLink
  - Connect success/failure logged with host:port
  - Close logged
  - Always-on (not gated behind NM_SOCKET_DEBUG)

### R4.2 — com0com NT Path (documented)
- Full setup guide for virtual COM port pairs
- NMServer integration via standard Win32 serial API
- Registry configuration
- Known issues (unsigned driver on Win10/11)

### R4.3 — UMDF2 Virtual COM Driver (specified)
- Architecture diagram (all user-mode, no BSOD risk)
- INF file template
- C driver skeleton with serial IOCTLs
- Named pipe protocol for NMServer communication
- Signing guide (WHDC attestation)
- Comparison table vs com0com
- 7-step development roadmap

### OpenOLMS v0.5 — released for GitHub
- Cloned from verta1878/OpenOLMS, all docs updated
- STATUS.md, CHANGELOG.md, CREDITS.md, AUTHORS, TODO.TXT, INSTALL.TXT
- gap_analysis.md with MOLMS section
- WHATSNEW.TXT v0.1-v0.5 (root + docs/ synced)
- kiddo credited for protocols (not g00r00)
- "Pending license" language removed everywhere
- examples/ directory confirmed safe to delete

### mterm v0.1 — updated
- mtripgfx.pas: RIP graphics pixel engine (640x350 EGA)
- keytest.pas: keyboard test tool
- mterm.pas: Ctrl-key binds, Serial/FOSSIL/Local connect dialogs
- mtphone.pas: default phonebook (Cosmo Castle, Fluph BBS)
- MANUAL.md: complete user manual

### fpc264irc — verified
- FIONREAD: ✅ termios.inc ($541B / $4004667f)
- UDP: ✅ SOCK_DGRAM, fpsendto, fprecvfrom
- netdb/DNS: ✅ netdb.pp + resolve.pp + compiled PPUs
- All three were already present — scratched from TODO
- Compiler fix: ncal.pas nil-safe check for EAccessViolation in LCL
- PPU version mix found: system.ppu=135(2.6.4), inifiles.ppu=207(3.2.x)
- sysop/0 needs to rebuild ALL Win32 PPUs with the fixed ppc386

## Decisions
- [DECISION] M2 trick: FPC 3.2.2 + upstream source + forms.pp first + exclude FV
- [DECISION] fpc264irc features NOT missing — FIONREAD, UDP, netdb all present
- [DECISION] fpc264irc PPU mix: sysop/0 must rebuild all Win32 PPUs with fixed ppc386
- [DECISION] R4.2 (com0com) works TODAY for sysops; R4.3 (UMDF2) is the long-term path
- [DECISION] Debug panel hidden by default, toggled via menu

## Test Files Created
- tests/test_binary_safety.pas (395 lines) — R3.3, 37 tests
- tests/test_m3_server.pas (231 lines) — M3 headless echo server
- tests/test_m3_client.pas (212 lines) — M3 test client
- tests/test_r34_multinode.pas (260 lines) — R3.4, 25 tests

## Packages Released
- netmodem2irc-repo-20260726-FINAL.zip (18M) — with NMServer.exe + all tests
- openolms-repo-v05.zip (1.8M) — full OpenOLMS repo for GitHub
- openolms-complete.zip (1.5M) — standalone release
- mterm-v01-serial11.zip (482K) — mterm + serial + OLMS + binaries
- session4-summary.md — this file

## Remaining
- R2.1-R2.5: Setup.exe + ISCmplr AV fix
- R4.1: Win9x VxD test (needs Win98 VM)
- R5.1: Inno installer packaging
- D4: Conformance testing (needs 386)
- D5: Relay rewrite (direct port I/O)
- Inno 9-10: Setup.exe + ISCmplr runtime AV
- sysop/0: rebuild ALL Win32 PPUs with fixed ppc386 (PPU version 135)
- verta1878: ANSI/RIP editor viewer testing
- sysop/0 backporting LCL to 2.6.4 (the real backport)

## Team
verta1878 (lead), sysop/0 (compiler — fixed ncal.pas EAccessViolation),
kiddo (serial IRQ, protocols), wrench (docs/arch/OpenOLMS), evga (RIPView)

## Key Quote
sysop/0: "Nice repo. Clean-room reimplementation, Peter Rocca's permission,
37 units, 28 commits. Now let me rebuild LCL for Win32"
