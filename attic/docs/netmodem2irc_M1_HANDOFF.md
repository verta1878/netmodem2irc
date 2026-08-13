# M1 handoff — engine ready for the Lazarus 1.2.6 + FPC 2.6.4irc build

The maintainer is setting up the Lazarus 1.2.6 + FPC 2.6.4irc build environment.
This note is what to drop in and where. The engine + integration are DONE and
TESTED; the build-environment/.lpi setup is the maintainer's side.

## What's ready (tested on FPC 2.6.4 AND 3.2.2)
All 8 engine units compile clean on stock FPC 2.6.4 (the irc anchor):
  NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node,
  NM_ServerBridge, NM_SynapseLink, NM_NamedPipeLink
All use {$MODE OBJFPC}{$H+}. Full test suite: 10 tests, 0 failures.

## Drop-in steps for the Lazarus project
1. **Add engine units to the project search path.**
   Put nt_src/*.pas where Lazarus can find them (e.g. a `engine/` dir under the
   repo, added to Project > Options > Paths > Other unit files). Or copy them
   next to server/.

2. **Bundle Synapse.**
   Add libs/synapse to the unit path (Other unit files) AND the include path
   (include files) — it needs both (jedi.inc etc.). Build with -dHAS_SYNAPSE to
   get real sockets; without it, the build succeeds but sockets are stubbed
   (good for a first GUI-only compile check).

3. **Wire MainForm.pas** per netmodem2irc_M1_MainForm_integration.md:
   - add NM_ServerBridge to uses
   - add FBridge: TServerBridge field; create in FormCreate, free in FormDestroy
   - fill the CM_* handlers with FBridge.OnConnectNode / OnDisconnectNode /
     OnSendRemoteBreak / OnBinary
   - add the pump TTimer calling FBridge.DriverIO per node (the TIOStruct
     pointer<->buffer copy is the thin driver-side glue to finish on Windows)

4. **First build target order (recommended):**
   a. GUI-only compile (no -dHAS_SYNAPSE) — proves the units + wiring compile in
      Lazarus 1.2.6 / 2.6.4irc.
   b. Add -dHAS_SYNAPSE + Synapse paths — proves the socket path compiles.
   c. Run — the server window comes up; then the TIOStruct marshalling + a live
      Telnet test (that's M2->M3).

## What I did NOT do (maintainer's lane)
- No .lpi / .lpr build-config edits guessed blind. The .lpr currently uses
  MainForm, SplashForm; the maintainer adds the engine units via project paths
  (or a uses addition) in the real Lazarus 1.2.6 environment.
- No Windows-specific build tuning — that's done where the toolchain lives.

## Honest status
- Engine + bridge + DriverIO: BUILT + TESTED (2.6.4 + 3.2.2).
- Lazarus project integration: drop-in steps above; the actual .lpi/build config
  + Windows compile is the maintainer's current work.
- Synapse runtime + TIOStruct pointer glue: Windows-build items (M2/M3).
