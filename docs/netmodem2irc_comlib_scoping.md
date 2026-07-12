# Scoping: a single COM-port library across all targets + slimming netmodem2irc

Goal (from the maintainer): ONE COM-port library spanning all targeted OSes,
extracted OUT of netmodem2irc so netmodem2irc gets slimmer. Scoping only (design,
not build) — addressing the three flags (fork scope / honest-fork / verify-98).

## First, an honest distinction — there are TWO different "COM" things
These are NOT the same layer, and the plan must respect that:

1. **In-process 16550 emulation (Pascal)** — netmodem2irc's NM_UART16550
   (register-level 16550 in software, TX/RX rings). This is what the FOSSIL layer
   and the engine talk to, IN our process. It is OS-independent Pascal.

2. **OS-level virtual COM port (kernel driver)** — com0com. A real Windows COM
   port other programs can open, backed by a kernel driver. Cross-process, OS-bound.

You cannot merge #1 and #2 into "one library" as a single artifact — one is
in-process Pascal logic, the other is an OS kernel driver in C. BUT you CAN have a
single COHERENT com-port PROJECT with a shared interface and per-target backends.

## What CAN happen (the realistic single-library shape)
A standalone **comport library/project** (separate repo, extracted from
netmodem2irc) with ONE interface and per-target backends:

  comport/  (new, standalone — the "one library")
    core/        the shared abstraction (a common COM interface + the 16550
                 register model + ring buffers) — Pascal, OS-independent. This is
                 NM_UART16550 (and helpers) MOVED here out of netmodem2irc.
    backends/
      fossil/    INT 14h FOSSIL path (from NM_Fossil / NM_FossilDriver) — DOS/VDM,
                 OS-INDEPENDENT (works 98/NT/2000/+ and in DOS VMs).
      com0com/   OS-level virtual COM via com0com (NT-family, 2000+), as a FORK of
                 com0com with a 9x/Win98 target added.
    adapters/    thin links so netmodem2irc (and other consumers) use the library
                 through one interface (e.g. ISerialPort / ISocketLink-style).

netmodem2irc then DEPENDS ON this library instead of containing the com code —
that's the slimming. netmodem2irc keeps only its server/bridge/node logic.

## Addressing the three flags
### (1) Scope reality — this is real, multi-language work
- core/ + fossil/ = Pascal (we already have it, tested — it MOVES, low risk).
- com0com/ Win98 = WDM KERNEL C, the 9x driver path = a substantial, separate
  effort (Windows kernel dev, 98 DDK). Confirmed: com0com is ~25 C files, mature,
  with BSOD-fix history — not a weekend port.
=> So the library is delivered in LAYERS: the Pascal core+fossil first (easy,
   high value, slims netmodem2irc NOW), the com0com Win98 backend later (big).

### (2) Honest fork
Basing the Win98 backend on com0com = an ACKNOWLEDGED FORK of com0com (GPLv2):
credit Vyacheslav Frolov, keep GPLv2, state clearly "com0com with Win98 support
added." NOT a rename/absorb (that would be the CodeTyphon mistake). com0com stays
com0com, forked openly. netmodem2irc is GPLv2 too, so license-compatible.

### (3) Verify Win98 is reachable
Windows 98 DID introduce WDM, so a WDM driver CAN target it in principle. BUT
com0com 2.2.2.0's .inf declares NT-family only (NTx86/NTia64/NTamd64), and its C
may assume NT-isms. Whether adding a 9x path is small or large is UNKNOWN until
the driver source is read deeply. Scope-first is right; the 98 backend is
research-gated, not yet a commitment.

## What slims out of netmodem2irc (the win, available now)
Move to comport/core + comport/backends/fossil:
  NM_UART16550 (332 ln), NM_Fossil (249 ln), NM_FossilDriver (114 ln) = ~695 lines
netmodem2irc keeps: NetTransport, NM_ATCommand, NM_Node, NM_ServerBridge,
NM_SeamProtocol, the links, the server. It becomes "the server that USES the
comport library," which is a cleaner identity.

## Honest recommendation
- YES, the single-library vision CAN happen — as a coherent PROJECT with one
  interface + per-target backends, not one monolithic artifact.
- Do it in layers: extract the Pascal core+fossil into a standalone comport
  library NOW (slims netmodem2irc immediately, low risk, all tested code moving).
- Treat the com0com Win98 backend as a SEPARATE, research-gated, GPLv2 fork effort
  — scoped now, built later.
- Keep FOSSIL as a backend of this library (it's the OS-independent one, still
  primary for netmodem2irc).

## Open question for the maintainer
Name + home for the extracted library? (e.g. "comlib", "vcomlib", a fpc-comport
project.) And: should it live with the fpc264irc ecosystem (shareable, like the
ELECOM port) so it's not re-built twice?

---

## Note: "Windows 98" and Windows ME (the 9x family)

Does "Win98 support" include Windows ME? For driver purposes: generally YES, with
caveats — do NOT treat it as an unqualified yes.

- **Same family:** Windows 98, 98 SE, and ME are all "Windows 9x" (monolithic,
  DOS-based hybrid kernel), sharing the same WDM driver model that 98 introduced.
  A WDM driver targeting 9x generally covers 98/98SE/ME as one target family.

- **CAVEAT 1 — ME restricted real-mode DOS.** ME deliberately cut back real-mode
  DOS access (no "boot to DOS"). This does not affect protected-mode WDM work
  (the com0com/virtual-COM backend), BUT it DIRECTLY affects the FOSSIL/INT-14h
  path, which lives at the DOS/real-mode layer. So:
    - com0com/WDM backend: "Win98" reasonably includes 98/98SE/ME (validate on ME).
    - FOSSIL backend: ME's DOS restrictions are a real flag — INT 14h/DOS behavior
      may differ on ME vs 98. Check ME specifically; don't assume.

- **CAVEAT 2 — ME quirks.** ME ("Mistake Edition") had stability/driver quirks;
  "targets 9x" != "tested-good on ME" without actual ME testing.

- **CAVEAT 3 — .inf:** 9x .inf can target the family broadly, but ME-specific
  handling sometimes needs its own attention. Not automatic.

**Scoping stance:** treat the 9x family (98/98SE/ME) as ONE target for the WDM/
com0com backend (validate on ME), and flag ME's real-mode-DOS restriction as a
specific risk for the FOSSIL backend. Verify on real ME before claiming ME support.
