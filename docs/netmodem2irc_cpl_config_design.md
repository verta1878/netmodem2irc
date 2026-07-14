# netmodem2irc CPL configuration utility — design (for M2 / Windows)

DESIGN-STAGE. The GUI itself is M2 work (needs Lazarus/Windows to build). This
documents the design so it's a build-ready plan when you're at the Windows box.
Target noted by the maintainer: Windows NT 4.

## What it is
A Control Panel applet (.cpl) that configures the netmodem2irc FOSSIL driver. On
NT4 a .cpl shows up in Control Panel — exactly where a user expects to configure a
modem/comms driver. It edits the per-node comport/host/port setup.

## The clean chain (CPL only ever writes NM_Config)
  CPL applet (GUI)  --writes-->  NM_Config file
        NM_Config (parse/validate, TESTED)
        NM_ConfigApply (bring up nodes on the switch, TESTED)
        NM_TSRResident / server (register UARTs, hook INT 14h)
The CPL touches ONLY the config file/format. It never talks to the ISR, the switch,
or the driver internals. Configure data; the running system reads that data to wire
itself. This keeps the seams clean (same discipline as the rest of the project).

## Config format (already defined + tested in NM_Config)
  node <index> <host> <port>
  e.g.
    node 3 bbs.example.com 23
    node 4 chat.example.org 6667
Bounds already enforced by NM_Config: node index 0..99, port 1..65535, host
non-empty, bad lines rejected. The CPL's job is to make editing this SAFE and
FRIENDLY (dropdowns, validation) and write a valid file.

## Two layers
1. The GUI form (Lazarus/LCL) — the actual configuration UI.
2. The CPL DLL wrapper — a Win32 DLL exporting CPlApplet, so Windows loads it as a
   Control Panel applet. The wrapper just launches/embeds the form.

### CPL wrapper (Win32 DLL, CPlApplet entry) — structure
A .cpl is a DLL exporting a single function:
    function CPlApplet(hWnd: HWND; msg: DWORD; lp1, lp2: LPARAM): LongInt; stdcall;
Windows sends messages the applet answers:
  - CPL_INIT     -> return 1 (success, proceed)
  - CPL_GETCOUNT -> return 1 (we expose one applet icon)
  - CPL_INQUIRE / CPL_NEWINQUIRE -> fill name, icon, description for the CP icon
  - CPL_DBLCLK   -> user double-clicked our icon -> SHOW THE CONFIG FORM
  - CPL_STOP / CPL_EXIT -> cleanup
Build as a DLL, rename the output .cpl, drop in system32 (NT4) — it appears in
Control Panel. (FPC/Lazarus can build Win32 DLLs with a stdcall export.)

### GUI form design (fields map 1:1 to NM_Config)
A node list + per-node editor:
  - Node list (grid): Node# | Host | Port   [Add] [Edit] [Remove]
  - Editor for a node:
      Comport/Node index : spin/dropdown 0..99   (maps NodeConfig.NodeIndex)
      Host               : text field            (maps NodeConfig.Host)
      Port               : spin 1..65535, default 23  (maps NodeConfig.Port)
  - [Save] -> writes the config file in the NM_Config `node i host port` format
  - [Test] (optional, later) -> try a TCP connect to host:port, report reachable
  - Validation on Save reuses NM_Config's own rules (index/port range, host
    non-empty) so the CPL can NEVER write a file the driver would reject.

### Reuse, don't reinvent
- Writing the file: emit `node <i> <host> <port>` lines — the exact format
  NM_Config.ParseText reads. Round-trip: load an existing file into the grid by
  running NM_Config over it and reading NodeByPosition.
- Validation: call the same bounds NM_Config enforces (or link NM_Config directly
  from the CPL, since it's plain Pascal) so GUI and driver agree by construction.

## NT4 notes
- NT4 is Win32 (no Win9x VxD). The .cpl DLL model is the standard NT4 Control Panel
  mechanism. Place the .cpl in %SystemRoot%\system32.
- The FOSSIL driver target on NT runs in the DOS VM (NTVDM); the CPL configures it
  from the Win32 side by writing the shared NM_Config file the driver reads.
- Keep the CPL 32-bit Win32; it configures, it is not the real-mode driver.

## Build order (when at Windows/Lazarus)
1. Build the Lazarus form standalone first (an .exe) — get the UI + NM_Config
   read/write working and validated.
2. Wrap it as a .cpl DLL (CPlApplet) once the form is solid.
3. Test in Control Panel on NT4.
Design-stage: no GUI code built here (needs M2). This is the build-ready plan;
the config MODEL it writes (NM_Config) is already done + tested.
