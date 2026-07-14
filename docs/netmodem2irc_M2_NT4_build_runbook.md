# netmodem2irc — M2 / Windows NT4 build-and-test runbook

A step-by-step runbook for the M2 milestone: building netmodem2irc into RUNNING
Windows programs (server GUI + config utility) and testing toward the first live
connection, on Windows NT 4.

HONEST STATUS: this guide is REASONED from the project structure — it has NOT been
run on a real NT4/Lazarus box (no Windows in the build sandbox). Expect a few
real-world snags at the machine; note them and we refine. The Pascal core it builds
is tested (33 host tests); M2 is about getting it to build+run on Windows.

## What M2 produces
1. NetModemServer.exe   — the Telnet server GUI (Lazarus)  [server/]
2. NetModemConfig.exe    — the configuration utility (Lazarus, rebuilt from
                          Dedrick's original NETMODEM.CPL)  [config/]
   (later: repackage config as a .cpl Control Panel applet — see
    netmodem2irc_cpl_config_design.md)
3. (later, needs i8086) the FOSSIL TSR for NTVDM.

## Prerequisites on the NT4 box
- Windows NT 4.0 (SP6a recommended for best Win32 stability).
- Lazarus + Free Pascal for Windows. NOTE ON VERSIONS: the newest Lazarus will not
  run on NT4. Use a version old enough for NT4 — historically Lazarus around
  0.9.30 / FPC 2.4.x era ran on NT4. If a modern Lazarus refuses to start on NT4,
  either (a) use an older Lazarus that supports NT4, or (b) BUILD on a newer
  Windows targeting Win32 and RUN the resulting exe on NT4 (Win32 exes are broadly
  forward/backward compatible). Option (b) is often the path of least resistance.
- The netmodem2irc repo checked out (engine/, server/, config/, common/,
  libs/synapse/).

## STEP 1 — Build the server GUI (NetModemServer.exe)
1. Open Lazarus. File > Open > server/NetModemServer.lpi.
2. The project already sets (verified in the .lpi):
     - Unit search paths: ../engine ; ../common ; ../libs/synapse
     - Custom option: -dHAS_SYNAPSE   (compiles the real TCP backend)
   Confirm these under Project > Project Options > Compiler Options > Paths /
   Custom Options if the build can't find units.
3. Build: Run > Build (or Shift+F9). It compiles the engine units + Synapse + the
   GUI (TfrmMain, TfrmSplash) into NetModemServer.exe.
4. EXPECTED SNAGS + fixes:
   - "Can't find unit blcksock / synsock": the Synapse path isn't on the search
     path, or Synapse needs its platform inc — ensure ../libs/synapse is listed and
     that ssfpc.inc / sswin32.inc are present (they are in libs/synapse).
   - Synapse on Win32 needs winsock — Synapse handles this via sswin32.inc; if the
     linker complains about winsock symbols, confirm you're targeting Win32.
   - LCL widgetset: ensure the project targets the Win32/Win64 widgetset (Project
     Options > Additions and Overrides, or the LCLWidgetType), not gtk.
5. Run it (F9). The splash then the main form should appear.

## STEP 2 — Build the config utility (NetModemConfig.exe)
1. File > Open > config/NetModemConfig.lpr (project) / ConfigMain.pas (form).
2. This app (per its header) reads/writes
     HKLM\Software\Allen Software\NetModem  (ComportConfig, IRQ)
   and calls IOCTL 03 to reload config without reboot — it was rebuilt from the
   original NETMODEM.CPL's 6 Delphi forms. On NT4 the registry write needs admin.
3. Build (Shift+F9) -> NetModemConfig.exe. Run it; the config form appears.
4. DESIGN NOTE: our tested NM_Config uses a text format (node i host port). The
   original NETMODEM.CPL used the registry. Decide which is canonical for the
   revival:
     - If the DRIVER reads the registry (Dedrick's original mechanism), keep the
       registry path and have NM_Config load/save mirror it.
     - If the driver reads the NM_Config text file (our tested path), point the
       config app at that file.
   Simplest for the revival: make the config app write BOTH, or standardize on the
   NM_Config text file and have the driver read it. Note the decision here.

## STEP 3 — (later, needs i8086) the FOSSIL TSR in NTVDM
Once the fpc264irc i8086 backport lands and the TSR is built (see
netmodem2irc_i8086_TSR_finish_guide.md):
1. NT4 runs DOS programs in NTVDM (the built-in DOS VM). The FOSSIL TSR loads
   inside NTVDM.
2. Start an NTVDM session (run a DOS program or command.com). Load the TSR.
3. It hooks INT 14h inside that VM and bridges to the server over the link.
4. Alternative runtimes if NTVDM is limiting: DOSBox-X, or the maintainer's
   ntvdmx64 fork (preferred).

## STEP 4 — First connection test (M3 preview)
Order of testing, cheapest first:
1. SERVER ALONE: run NetModemServer.exe, confirm it opens a listening node
   (per config). Use a telnet client (SyncTERM/NetRunner/putty) to connect TO the
   server's node port and confirm the server accepts + shows the connection.
2. CONFIG ROUND-TRIP: set a node in NetModemConfig, confirm the server picks it up
   (reload/IOCTL 03), confirm the node comes up with the configured host/port.
3. OUTBOUND: point a node at a real remote Telnet BBS (host:23). Confirm the server
   connects out (Synapse) and negotiates Telnet BINARY (our NetTransport).
4. FULL PATH (needs the TSR): a DOS door in NTVDM -> FOSSIL TSR -> server -> remote
   BBS. This is M3 "it connects" — the first end-to-end run.

## STEP 5 — Report back
For each step note: did it build? did it run? exact error text on any failure.
Bring those here and we work through them. The most likely real snags are (a)
Lazarus/NT4 version compatibility, (b) Synapse winsock linking, (c) the
registry-vs-textfile config decision, (d) NTVDM's real-mode limits for the TSR.

## Reference docs
- netmodem2irc_cpl_config_design.md   — turning the config app into a .cpl applet
- netmodem2irc_i8086_TSR_finish_guide.md — finishing the TSR when i8086 lands
- docs/netmodem2irc_M1_COMPLETE.md      — how the engine wires into MainForm
