# attic/ — retired files (kept, not deleted)

Files here are superseded or no longer part of the build, but preserved rather than
deleted (nothing that had a place is thrown away). Each entry says WHY it's retired.

> **Audited 2026-07-25.** `attic/docs/` held 26 files, every one
> byte-identical to its counterpart in `docs/` — copied rather than
> moved, so each document was simultaneously active and retired. The
> shadow copies were removed; `docs/` is now the only location.
> Recoverable from git history if ever needed.
>
> `netmodem2irc_CREDITS.md` was in the same state: recorded below as
> retired, but an identical copy remained at the repo root. The root
> copy has been removed and this one kept, which is what the entry
> below always described.

## Contents
- **watt32/** — the Watt-32 / Watcom mixed-link apparatus, retired 2026-07-25
  when the DOS side was settled as standalone with no network. Holds
  `stubs.asm` and a README recording the toolchain pieces that were never
  tracked here. See `docs/netmodem2irc_watt32_cleanup_phases.md`.
- **WIN32COM.PAS** — the old ELECOM Win32 comms unit, retired when the ELECOM port
  moved to the FPC-target units (FOS_COM / win32_pending). Superseded, kept for
  reference.
- **netmodem2irc_CREDITS.md** — an early, shorter credits file. Superseded by the
  fuller CREDITS.md at the repo root (which credits the same chain — Dedrick Allen,
  mag69, Antonio Rico/Reapern66 — plus Synapse, ELECOM, com0com/com2tcp, FPC, etc.).
  Retired to avoid a duplicate/inconsistent credits file. NOT referenced anywhere.

## Deliberately NOT retired (kept in place — these are NOT old junk)
- **docs/original/** (ATCOMNDS.TXT, README.TXT, WHATSNEW.TXT) — Dedrick Allen's
  ORIGINAL NetModem documentation. Primary-source historical preservation; the
  point of the project. Stays.
- **docs/MILESTONE_netmodem2irc.md, docs/netmodem2irc_M1_COMPLETE.md** — historical
  milestone docs still REFERENCED by README and the M2 build guide. Kept.
- **history/** (Dedrick's FILE_ID.DIZ + facts) — primary source. Stays.
