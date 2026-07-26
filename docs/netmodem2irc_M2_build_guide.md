# M2 — building the server in Lazarus (LCL ready)

With LCL widgetset support finished in fpc264irc, the server GUI can now be built.
This is the M2 step: turn engine + GUI source into a running NMServer.exe.

## Project files (prepared)
- server/NMServer.lpr — updated to `uses` the engine units + driver interface
- server/NMServer.lpi — NEW: sets the unit search paths so Lazarus finds:
    ../engine        (the netmodem2irc engine units)
    ../common        (NMVxD — driver interface)
    ../libs/synapse  (bundled Synapse, for the -dHAS_SYNAPSE build)

## Two build modes (in the .lpi)
- **Default** — builds the server WITHOUT Synapse (engine + GUI compile; sockets
  stubbed). Good for a first GUI-up smoke test — you can SEE the window.
- **Synapse** — adds `-dHAS_SYNAPSE` + the Synapse path, for real TCP. Use this
  for the networked build (M3).

## Steps (on Windows, Lazarus 1.2.6 + FPC 2.6.4/fpc264irc)
1. Open server/NMServer.lpi in Lazarus.
2. Apply the MainForm wiring from docs/netmodem2irc_M1_COMPLETE.md (the FBridge
   field, create/destroy, the CM_* handlers, the pump timer). This is the one
   hand-edit; it's fully specified there.
3. Build (Default mode) → NMServer.exe. Run it → the GUI window appears.
   THIS is "install it and see the GUI."
4. Switch to Synapse build mode for the networked version (M3).

## Honest boundaries
- The .lpr/.lpi are prepared and the paths verified to resolve in the repo tree,
  but the actual Lazarus BUILD is a Windows-side action (Lazarus can't run in the
  dev sandbox here). The engine itself is verified compiling on FPC 2.6.4 + 3.2.2.
- MainForm wiring (step 2) is documented drop-in code, not yet applied to the repo
  MainForm.pas (left for you so your own GUI changes aren't overwritten).
- First target: Default mode (GUI up). Synapse/networked is M3.

## What "done" looks like for M2
NMServer.exe builds in Lazarus and launches showing the server window.
Then M3 (it connects) with the Synapse build + a live Telnet test.
