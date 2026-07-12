# netmodem2irc — FOSSIL driver (NetFOSSIL/32 revival) scoping — M3.5

Honest scope for the loadable FOSSIL driver: the piece that lets real DOS BBS
software use netmodem2irc, exactly as NetModem/32's NetFOSSIL/32 did.

## What the original was (verified from docs/original/WHATSNEW.TXT)
**NetFOSSIL/32 v2.0** — a "32bit Revision Level 5 FOSSIL driver with support for
the SuperSet functions (1Ch-21h) defined by Raymond L. Gwinn." Gwinn = the X00
FOSSIL author, so NetFOSSIL/32 = standard Rev.5 FOSSIL + X00 SuperSet extensions.
DOS software could use it OR X00/BNU/ADF.

## The requirement
A DOS-loadable driver that:
1. Hooks **INT 14h** (the FOSSIL interrupt) and answers the FOSSIL function table.
2. Presents itself as a FOSSIL (init returns AX=$1954, the signature).
3. Routes serial I/O to the netmodem2irc server (over the pipe/socket seam),
   instead of to a real UART.
So a BBS calls INT 14h thinking it's a modem; the driver carries bytes to the
server; the server does Telnet to the remote. This is how NetModem/32 worked.

## What we can REUSE (already built + tested)
Our NM_Fossil.pas already implements the FOSSIL SERVICE LOGIC:
- Standard functions 00h-1Bh (41 FN_ constants): init($1954)/deinit, set-baud,
  TX/RX wait+nowait, status, DTR, flush/purge, block read/write, break, etc.
- The $1954 signature + BX version word.
- X00-superset screen/cursor/keyboard (11h-17h).
This is the BRAINS of the driver — the semantics of every function are done and
tested. What's missing is the DOS PACKAGING around it.

## What is genuinely NEW (the driver packaging)
1. **INT 14h vector hook** — install our handler into the interrupt vector table,
   chain the previous handler for non-our-comport calls. Real-mode ISR work.
2. **Register-level entry/exit** — FOSSIL passes args in AH/AL/DX (function/port)
   and returns in AX etc. Our NM_Fossil already models TFossilRegs; the driver
   wraps the actual ISR register frame onto it.
3. **TSR or loadable form** — stay resident (real-mode TSR) OR a go32v2 resident
   strategy. DOS-target packaging.
4. **The seam to the server** — how the DOS-side driver reaches the Windows
   server. Options:
   - If DOS runs in an EMULATOR (DOSBox-X/vDos) alongside the Windows server:
     a shared pipe/socket the emulator exposes.
   - If real DOS on a LAN: a packet-driver/TCP path (heavier; period-authentic
     NetModem used its server on the same machine).
   This seam is the same ISocketLink idea — the DOS driver is another client of
   the server.

## Build reality (honest)
- This is **real-mode / go32v2 DOS code** = **fpc264irc territory**, NOT the NT
  host. INT 14h hooking needs Dos/Registers/Intr (DOS target) or asm.
- Verified by a **DOS build + a real door talking through it**, not on the NT box.
- fpc264irc is the compiler; this is exactly the kind of DOS target it exists for.

## Cross-validation with ELECOM (nice)
ELECOM's FOS_COM.PAS is a DOS FOSSIL **client** (calls INT 14h, checks $1954).
Our driver is the **server/provider** side (answers INT 14h). They're two ends of
the same wire, same $1954 signature — FOS_COM can literally be a TEST CLIENT for
our driver. Independent period code validating our driver.

## Milestone breakdown (M3.5)
- [ ] M3.5a — DOS test harness: a go32v2 program that calls INT 14h fn 04h and
      checks $1954 (proves we can hook + answer). (FOS_COM can seed this.)
- [ ] M3.5b — wrap NM_Fossil's logic behind a real INT 14h handler (the ISR
      register frame -> TFossilRegs -> FossilDispatch -> back).
- [ ] M3.5c — the server seam (pipe/socket) from the DOS side.
- [ ] M3.5d — a real DOS door (e.g. a simple one) connects out through it.
- [ ] M3.5e — TSR/resident packaging + config (comport, server address).

## Priority note
This slots around M3 (it connects). Once the server does live Telnet (M3), the
FOSSIL driver (M3.5) is what lets actual DOS BBS software drive it — the
original's core use case. It's arguably THE feature that makes netmodem2irc
"NetModem, revived" rather than just a Telnet bridge.

---

## TARGET DECISION — i8086 (16-bit real-mode) is the better fit for the driver

Question raised: since the fpc264irc maintainer plans to add i8086 (real-mode
16-bit) support, would that be a better target for the FOSSIL driver than go32v2?

**Answer: yes — i8086 real-mode is the better and more faithful target.**

### Why i8086 over go32v2 for a FOSSIL driver
- A FOSSIL driver is, by nature, a **16-bit real-mode TSR** (X00, BNU, ADF — all
  classic 16-bit resident drivers). Hooking INT 14h, SetIntVec, and staying
  resident (Keep/TSR) are **native, natural real-mode operations**.
- **go32v2** produces **32-bit protected-mode (DPMI)** programs. A FOSSIL driver
  can be built there, but TSR residency + INT 14h hooking fight the grain:
  protected↔real mode transitions, DPMI callbacks, and go32v2 programs not being
  natural TSRs. Doable, but awkward.
- **i8086** produces genuine **16-bit real-mode** code — exactly the shape a
  FOSSIL TSR wants. The driver *is* a small real-mode resident; i8086 matches it.

### Runtime on modern 64-bit Windows — preference (maintainer decision)
Stock 64-bit Windows cannot run 16-bit code (no virtual-8086 mode in long mode;
Microsoft removed NTVDM from x64/ARM). DOS-VM environments bring it back, and they
all run **16-bit** code — so a 16-bit real-mode driver targets them directly.

**Preferred: ntvdmx64** (Leecher1337; a fork is maintained at verta1878/ntvdmx64).
Reasoning:
- It runs the **actual Windows 16-bit code path** — Microsoft's real NTVDM ported
  to 64-bit. For preservation, that authenticity is the point: it is *the* 16-bit
  environment, not an emulation of one.
- It is **open source** (patch-based; forkable and modifiable).
- Its feature set is smaller than DOSBox-X in some respects, but fidelity to real
  Windows 16-bit execution is the higher value for this project.

**Kept as an option (door NOT closed): DOSBox-X / vDos.** These remain supported
runtimes. Clean-provenance emulators, easy socket/pipe serial to the server. We do
not banish them — keeping options open is itself the ethos. They are the choice
for anyone who prefers an emulator or can't use ntvdmx64.

**Also noted: nxvdm** (SourceForge) — a clean-room 16-bit CPU emulator; WIP.

**Honest caveat — the injector.** ntvdmx64 hooks itself into 32/64-bit processes
via a **non-standard injector** (the project itself warns it "may cause problems
not yet recognized"). This is the fragile, uneasy part — and a sad one: real
16-bit code only runs again on modern Windows *because* of a hack like this, since
the capability was deliberately severed. We note the injector honestly as the
concession the modern OS forces, not something to celebrate. It is the reason to
keep DOSBox-X's door open as a less-invasive alternative.


### Sequencing (honest)
- i8086 is the fpc264irc **r3** expedition (2.6.4 has zero i8086 scaffolding; the
  backend arrived in FPC 3.0 — a multi-month port). So i8086 is the RIGHT target
  but a FUTURE one.
- go32v2 is available NOW (fpc264irc bundles it) but is the more awkward fit.
- **Decision: scope the FOSSIL driver for i8086 (real-mode TSR) as the eventual
  target.** The tested service logic (NM_Fossil) and the frame-dispatch layer
  (NM_FossilDriver.DispatchFrame) are already target-agnostic and verified, so
  they carry over unchanged; only the ISR hook + TSR packaging bind to i8086 when
  it lands. If a working driver is wanted before i8086 ships, a go32v2 interim
  build is possible but should be treated as a stopgap, not the final form.

### What this means for the code we already have
- NM_Fossil (service logic) and NM_FossilDriver.DispatchFrame (INT 14h frame <->
  dispatch) are target-independent and TESTED — they are ready for either target.
- Only the DOS_TARGET-guarded ISR hook / TSR residency is target-specific, and it
  should be written for **i8086 real-mode** (GetIntVec/SetIntVec + a real-mode
  interrupt handler + Keep), built under fpc264irc once i8086 is available.

---
