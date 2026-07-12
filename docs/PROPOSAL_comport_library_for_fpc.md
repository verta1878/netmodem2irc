# Proposal: A standard COM-port / serial library for the FPC ecosystem

**To:** the fpc264irc maintainer
**From:** verta1878 (netmodem2irc maintainer)
**Status:** proposal / discussion — nothing assumed, your call throughout
**Date:** 2026

---

## TL;DR

I'd like to propose extracting the tested COM-port / serial emulation code from
netmodem2irc into a **standalone, reusable Pascal library** — and, if you're open
to it, standardizing it within the fpc264irc ecosystem so it isn't rebuilt twice
across projects. It has two backends: a FOSSIL (INT 14h) path that is
OS-independent, and a virtual-COM path modeled on com0com (with a longer-term
Win9x goal). This would give the ecosystem a shared, blessed serial/COM layer and
move us toward a complete BBS/retro build environment (compiler + COM layer + GUI +
runtime).

This is a proposal for discussion. I'm not assuming a yes, and I've tried to be
honest below about what's finished, what's scoped-only, and what's hard.

---

## Why

Right now the COM/serial emulation lives inside netmodem2irc. But it's genuinely
general-purpose — any BBS/comms/DOS-era project on FPC needs the same thing
(a 16550 UART model, a FOSSIL INT 14h path, a virtual-COM path). Keeping it locked
inside one program means the next project reinvents it.

Extracting it into a shared library:
- lets multiple projects use one tested implementation (not N copies),
- slims netmodem2irc (it becomes "a server that USES the library"),
- gives the fpc264irc ecosystem a standard serial/COM story across targets,
- is a keystone toward a full, coherent BBS/retro build environment
  (fpc264irc compiler + this COM layer + Lazarus/LCL GUI + a DOS-VM runtime).

## What it is (proposed structure)

    comport/            (standalone library)
      core/             shared 16550 register model + ring buffers (Pascal,
                        OS-independent) — the in-process serial abstraction
      backends/
        fossil/         INT 14h FOSSIL path — OS-INDEPENDENT (DOS/VDM; 98/NT/2000+)
        com0com/        OS-level virtual COM port; a FORK of com0com (GPLv2) with a
                        Win9x/Win98 target as a longer-term goal
      adapters/         thin links so consumers use one interface
                        (ISerialPort / ISocketLink-style)

netmodem2irc (and any other consumer) then DEPENDS ON comport instead of
containing the code.

## Current status (honest)

Already built and TESTED (on stock FPC 2.6.4 AND 3.2.2, 0 failures):
- 16550 UART emulation (register-level; TX/RX ring buffers)
- FOSSIL INT 14h service layer (init signature $1954, the standard Rev.5 function
  set + X00 superset range)
- FOSSIL driver frame-dispatch (INT 14h frame <-> dispatch; ISR/TSR guarded for
  the DOS target)
- CROSS-VALIDATED against ELECOM's FOS_COM (an independent, period-correct DOS
  FOSSIL client): our driver answers FOS_COM's exact calls with FOS_COM's exact
  expected results — two implementations ~25 years apart agree on the bit-level
  FOSSIL contract.

Scoped but NOT built:
- The com0com virtual-COM backend, and especially a Win9x/Win98 target for it, is
  real WDM kernel-C work (the 9x driver path) — a substantial, separate effort. It
  is research-gated: Win98 introduced WDM so a driver CAN target it in principle,
  but com0com's own .inf is NT-family only and its C may assume NT-isms. Whether
  adding a 9x path is small or large is unknown until the driver source is read
  deeply.

## Licensing / provenance (important)

- The Pascal core + FOSSIL code is ours to contribute (netmodem2irc is GPLv2).
- The virtual-COM backend, if based on com0com, is an ACKNOWLEDGED FORK of com0com
  (Vyacheslav Frolov, GPLv2): keep GPLv2, credit the author, present it clearly as
  "com0com with additions," never a rename/absorb. Related tools (com2tcp,
  hub4com) are also GPLv2 by the same author.
- Everything here is GPLv2 or GPLv2-compatible, consistent with FPC-ecosystem
  norms. I want provenance kept clean and attribution intact throughout.

## What I'm asking

1. Is there interest in a shared comport library in the fpc264irc ecosystem?
2. If yes: where should it live, and what would "standardized" mean to you
   (a blessed companion library? bundled with the toolchain? something else)?
3. Naming preference for the library.
4. Any constraints I should design to (code style, unit layout, license headers,
   how it should sit next to the RTL/FCL) so it fits cleanly and isn't ported twice.

Two honest distinctions I want to keep clear, so we're aiming at the same target:
- "Standardize within the fpc264irc ecosystem" (near, achievable, your fork) is
  different from "upstream into official Free Pascal" (a longer, separate path
  needing the FPC core team). Either is worthy — I just don't want to blur them.
- I'm proposing, not assuming. If the fit isn't right, a clean companion library
  (like Synapse sits beside FPC) is a perfectly good outcome too.

## Suggested first step (low-risk)

Extract the already-tested Pascal core + FOSSIL backend into the standalone library
first (all tested code moving, netmodem2irc slims immediately). Treat the com0com
Win9x backend as a separate, later, research-gated effort. That way the library is
real and useful right away, without waiting on the hard kernel-driver work.

## What this unlocks

A standardized COM layer is the keystone of a complete BBS/retro build environment:
the fpc264irc compiler, this shared serial/COM layer, Lazarus/LCL for GUI, and a
DOS-VM runtime — a coherent toolchain to build DOS BBS doors, FOSSIL drivers,
Telnet bridges, and GUI servers on modern machines. Preservation that lets people
build NEW things in the old tradition, not just archive the old ones.

Thanks for considering it — and for fpc264irc, which makes all of this possible.

— verta1878
