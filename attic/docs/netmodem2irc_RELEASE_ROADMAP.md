# netmodem2irc — release roadmap & milestones

Goal: a real release of netmodem2irc (NetModem/32 revival). This maps the honest
distance from the current published repo to a shippable release.

## Where things actually stand (verified from live repo, commit 6a9b3f0)

**Published now (the scaffold):**
- driver/src/ — Dedrick's original MASM VxD source (9x)
- server/ — Lazarus GUI scaffold (MainForm/SplashForm) with CM_* handler STUBS
  (MainForm.pas literally says "Fill in the transport (NetTransport.pas) to
  complete it" + TODOs for CM_CONNECT_NODE, CM_DISCONNECT_NODE, etc.)
- config/, common/NMVxD.pas, docs/, docs/original/
- Single `main` branch (no separate 9x/nt branches yet)

**Built this session but NOT yet pushed (the engine):**
- nt_src/ — the tested Pascal emulation stack that FILLS those TODOs:
  UART/FOSSIL/transport/AT/multinode + Synapse link + named-pipe link.
  8 units, ~85 checks, 0 failures, verified on stock FPC 2.6.4.
- The transport the server scaffold is waiting for = our NetTransport.pas.

So: the repo has the body; we built the engine; they need to be joined.

## MILESTONES (in order)

### M1 — Integrate the engine into the repo  [foundation]
Merge this session's nt_src/ into the repo and wire it to the existing server.
- [ ] Add the emulation units (NM_*, NetTransport) to the repo
- [ ] Add libs/synapse/ (bundled), THIRD_PARTY.md, history/FILE_ID.DIZ
- [ ] Add the test/ suite + run-tests.sh
- [ ] Fill server/MainForm.pas CM_* TODOs using TNodeManager:
      CM_CONNECT_NODE -> node.ConnectInbound; CM_DISCONNECT_NODE -> node.Disconnect;
      CM_SEND_REMOTE_BREAK -> node.SendBreak; CM_WILL/WONT_BINARY -> transport
- [ ] Rename repo netmodem2 -> netmodem2irc
Exit: repo contains a coherent, building NT server that USES the tested engine.

### M2 — It builds on Windows  [buildable]
- [ ] Build server + config + engine with FPC/Lazarus on Windows (target the
      2.6.4irc/Lazarus 1.2.6 pairing, or modern Lazarus — decide)
- [ ] Compile the Synapse path (-dHAS_SYNAPSE) against bundled Synapse on Windows
- [ ] Resolve any Win32-specific compile issues
Exit: `NMServer.exe` builds and launches on Windows.

### M3 — It connects  [functional, the real proof]
- [ ] Synapse RUNTIME test: server dials out / accepts a real Telnet connection
- [ ] A DOS BBS door (in an emulator or via the pipe/driver) talks through it
- [ ] Binary-safety confirmed on the wire (CP437 / Zmodem through a real session)
- [ ] Multinode: 2+ simultaneous connections verified live
Exit: a real BBS door session works end-to-end over TCP/IP. THIS is the milestone
that makes it "NetModem, revived."

### M4 — Virtual COM path (the three tiers)  [reach]
- [ ] B (proof of concept): DOS door in emulator via named-pipe COM -> our server
- [ ] A (frontier): C/C++ UMDF2 virtual-COM driver (follows MS-PL FakeModem) so
      native software sees a real COMx; build/sign/test on Windows
- [ ] C (fallback): document com0com path
Exit: native Windows software can use netmodem2irc as a virtual modem.

### M5 — Release  [ship]
- [ ] Installer (Inno Setup, NT branch)
- [ ] README + About updated, honest feature/status matrix
- [ ] Tag a release (e.g. netmodem2irc-0.1 "engine + NT server")
- [ ] 9x branch (VxD) documented as separate/experimental (needs DDK + the
      9x-only linker work)
Exit: a tagged, installable release people can download and run.

## Suggested FIRST release scope (don't wait for everything)
A meaningful **0.1** could be M1+M2+M3: "netmodem2irc — working NT Telnet modem
server with a tested emulation engine and multinode support; virtual-COM driver
(Option A) and installer to follow." Ship the working core; iterate.

## Honest status of each piece (so the release notes stay truthful)
- Emulation engine (UART/FOSSIL/AT/transport/multinode): TESTED (2.6.4 + 3.2.2)
- Synapse socket link: compile-verified vs real Synapse; runtime test = M3
- Named-pipe link: logic tested; real Win pipe = M4
- Option A driver: design-stage (scoping doc); build = M4
- 9x VxD: original source present; VMM.INC valid; build blocked by 9x linker
  issue (separate, experimental)

## Everything is saved
All engine code + docs are in the all_work_bundle archive. M1 is "push that into
the repo and wire it in."
