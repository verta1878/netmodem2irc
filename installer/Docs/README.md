# netmodem2irc — session updates bundle

Everything from this working session, in one archive so nothing is lost.
Status is HONEST: what's tested, what's compile-only, what's design-stage.

## What's here

### nt_src/  — the NT-branch revival source (Pascal), TESTED
The working, tested modem-emulation stack. Full suite: 8 units, 8 tests, 0
failures (~85 checks). VERIFIED building AND passing on stock FPC 2.6.4.
- NM_UART16550.pas   — 16550 UART emulation (14 tests)
- NM_Fossil.pas      — FOSSIL INT 14h emulation (17 tests)
- NetTransport.pas   — Telnet transport, IAC/BINARY, binary-safe (12 tests)
- NM_ATCommand.pas   — Hayes AT, ATDT dial (12 tests)
- NM_Node.pas        — per-node object + multinode manager (18 tests)
- NM_SynapseLink.pas — real Synapse TCP socket link (compile-verified w/ Synapse)
- NM_NamedPipeLink.pas — named-pipe link, the driver seam (13 + 4 tests)
- test/              — all test programs + run-tests.sh (portable runner)
- libs/synapse/      — bundled Ararat Synapse (modified-BSD, GPLv2-compatible)
- history/           — Dedrick Allen's original FILE_ID.DIZ + facts
- THIRD_PARTY.md     — Synapse license + inclusion notes

HONEST BOUNDARIES:
- Synapse networked path (-dHAS_SYNAPSE): COMPILE-verified vs real Synapse, NOT
  runtime-tested over a live connection (needs a Windows build).
- Named-pipe real I/O (-dHAS_WINPIPE): written vs stable Win32 API, logic tested
  with a fake backend; real pipe needs a Windows build.

### Docs (design + reference)
- netmodem2irc_DRIVER_MAP.md      — functional map of Dedrick's NETMODEM.ASM
- netmodem2irc_LAYER_A_SPEC.md    — 16550 + FOSSIL spec (the re-creation blueprint)
- netmodem2irc_NT_TRANSPORT_LAYER.md — NT Layer-B replacement design
- netmodem2irc_VMM_INC_buildnote.md — CORRECTED: VMM.INC is VALID, not corrupt
- netmodem2irc_Option_A_scoping.md — the native UMDF2 virtual-COM plan (frontier)
- elecom_modernization.md         — ELECOM (EleBBS comms lib) port progress

### attic/  — retired files (kept, not deleted)
- WIN32COM.PAS — author-deprecated ELECOM unit (replaced by W32SNGL.PAS)
- README.md    — the attic rule + Virtual Pascal -> FPC history note

## Three-tier virtual-COM strategy (recap)
- A (goal): native user-mode UMDF2 driver (C/C++, follows MS-PL FakeModem sample)
  + our Pascal brain over a named pipe. The "first" — see Option_A_scoping.
- B (proof of concept): the tested Pascal stack + NamedPipeLink. DONE/green.
- C (last resort): com0com.

## Build quick-check
  cd nt_src && sh test/run-tests.sh
  (uses `fpc`; or FPC=/path/to/ppcXXX sh test/run-tests.sh)
