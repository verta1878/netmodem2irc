# netmodem2irc / virtual-COM driver — the boundary (step 1: clean, verified)

Goal: keep netmodem2irc a focused FOSSIL/Telnet bridge; keep the (future,
general-purpose) virtual-COM driver as its OWN project. Step 1 was to separate the
two. Finding: netmodem2irc is ALREADY clean — no surgery needed, only this explicit
boundary.

## Verified state (why it's already clean)
- The ENGINE (engine/*.pas) is OS-INDEPENDENT: no engine unit `uses Windows`, none
  `uses NetModemVxD`. Proven by the 33 tests building engine-only on Linux.
- NM_ServerBridge MIRRORS the driver's TIOStruct layout with a plain record and a
  comment ("kept here so the bridge is testable without the driver unit; layouts
  MUST match") — an intentional DECOUPLING, not a dependency.
- VxD / virtual-COM mentions in engine units (NM_Fossil, NM_UART16550,
  NM_ATCommand) are PROVENANCE COMMENTS (history: "Dedrick's VxD dispatched via
  Int14_Table..."). They document heritage; they are not code coupling. KEEP them.

## Where the driver/virtual-COM material lives (correctly isolated)
- common/NetModemVxD.pas — Ring-3 interface to Dedrick's NETMODEM.VXD. Used by the
  server GUI (server/MainForm.pas, NetModemServer.lpr) ONLY — never by the engine.
- driver/src/ — Dedrick Allen's original 9x VxD source (NETMODEM.ASM + VxD includes
  VMM/VCOMM/VCOMMW32/VPICD/VWIN32/SHELL/REGDEF). Original, GPL, reference.

## The boundary (make it explicit)
netmodem2irc = the FOSSIL/Telnet BRIDGE:
  DOS door --INT 14h/FOSSIL--> netmodem2irc engine --seam/switch--> Telnet/TCP.
  Its "port" for a DOS door is the FOSSIL TSR (no kernel driver needed).
  The engine stays OS-independent and driver-independent.

The virtual-COM DRIVER (general-purpose, com0com-like) = a SEPARATE project:
  gives ANY Windows program a virtual COM port pair. Not netmodem-specific.
  9x => a VxD (Dedrick's driver/src is the model/reference).
  NT => a WDM driver (com0com is the model/reference).
  netmodem2irc can USE such a driver (Path B) but does not contain it.

## How they connect without coupling
- The server GUI can point at EITHER the FOSSIL path OR a virtual-COM port. The
  engine doesn't care — it speaks its tested interfaces (UART regs, seam). The
  virtual-COM driver, if present, is just another way to feed the same engine.
- The TIOStruct layout is the contract; both sides keep it matching, neither
  imports the other.

## Step 1 conclusion
No code separation required — the engine was built clean. This doc IS the
separation: it states the boundary so the future virtual-COM driver project (steps
2-4: header investigation, fpc264irc maintainer proposal) knows exactly where
netmodem2irc ends. netmodem2irc stays the bridge; the driver is its own effort.
