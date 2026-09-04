# Licensing

Written 2026-07-25.

netmodem2irc is a **mixed-license repository**. Work written for the
revival is GPLv3. Dedrick Allen's original NetModem/32 material stays
GPLv2, as it was received. Third-party libraries keep their own terms.

## By component

| Path | License | Copyright |
|---|---|---|
| `engine/` | **GPLv3+** | Antonio Rico |
| `engine/test/` | **GPLv3+** | Antonio Rico |
| `server/` | **GPLv3+** | Antonio Rico |
| `config/` | **GPLv3+** | Antonio Rico |
| `common/` | **GPLv3+** | Antonio Rico |
| `dos/` | **GPLv3+** | Antonio Rico |
| `InnoIRC561/src/` | Inno Setup license | Jordan Russell + port changes |
| `driver/src/` | **GPLv2** | Dedrick Allen |
| `history/` | **GPLv2** | Dedrick Allen |
| `cpl/original_forms/` | **GPLv2** | Dedrick Allen |
| `libs/synapse/` | modified BSD | Lukas Gebauer |
| `attic/WIN32COM.PAS` | freeware, ELECOM terms | Maarten Bekers |

`LICENSE` is the GPLv3 text and governs the revival work.
`LICENSE-GPLv2` is retained and governs Dedrick's material.

68 source files under `engine/`, `engine/test/`, `server/`, `config/`,
`common/` and `dos/` carry a GPLv3 header. Files belonging to other
copyright holders were deliberately **not** touched — their headers are
left exactly as received, per the project's rule that nothing of
Dedrick's is renamed or obscured.

## Why the split

Dedrick Allen handed NetModem/32 forward personally. The code he wrote
is his; the revival cannot unilaterally move it to a newer licence.
Work written from scratch for the revival is separate and is offered
under GPLv3.

The two bodies of code are distributed together but are **separate
programs**: `NETMODEM.VXD` is a 9x kernel driver built from
`driver/src/`, while `NMServer.exe` and `NMConfig.exe` are user-mode
programs built from `engine/`, `server/` and `config/`. They communicate
across a documented IOCTL / `CM_*` message boundary, not by linking.
Shipping them on the same medium is aggregation, not combination.

## Statement of record — no longer shareware

**Declared 2026-07-25 by Antonio Rico (Reapern66 / verta1878),
maintainer of netmodem2irc:**

> NetModem/32 is no longer shareware. It is free software.
>
> Dedrick Allen released the code to me under GPLv2. That is his
> licence and his code stays under it, respectfully and unchanged.
>
> Our new code is GPLv3, because netmodem2irc will outlive us.

### The chain, in order

| When | What | Terms |
|---|---|---|
| 1997-2001 | Dedrick Allen writes and ships NetModem/32. Antonio Rico contributes as a **beta tester**. | Shareware |
| later | Dedrick releases the code to Antonio directly, author to maintainer | **GPLv2** |
| 2025-2026 | Antonio writes the revival: engine, server, config, DOS bridge | **GPLv3** |

Each step supersedes the previous one only for the code it covers. The
1997 shareware terms describe the original commercial distribution; the
GPLv2 release governs Dedrick's code today; GPLv3 governs the revival
work only.

This supersedes the shareware terms in the original 1997 distribution.
`history/netmdb15/NETMODEM.DOC` still reads "NetModem v1.0bX.sL -
Shareware / CopyRight 1997 - Dedrick Allen" with a "How to Register"
section, and `WHATSNEW.TXT` still says v1.x became freeware while
NetModem/32 would not. **Those files are historical artifacts and are
preserved verbatim — they record what the terms were in 1997, not what
they are now.** Nothing in `history/` is edited to match the current
position; the record stands as it was written.

### What is known, and what is inferred

Stated plainly so no future reader has to guess which is which.

**Known.** Dedrick Allen wrote NetModem/32. Antonio Rico was a beta
tester during the original era and worked with Dedrick then — beta
testing, not authorship, so no copyright in the original arises from it.
Dedrick later released the code to Antonio directly, author to
maintainer. Everything in `driver/src/`, `history/` and
`cpl/original_forms/` is Dedrick's work.

**Inferred.** That the release carries GPLv2 terms. The maintainer's
position is that it does, and the project treats it that way. But no
written grant from Dedrick appears anywhere in this repository, and the
1997 distribution was shareware. The GPLv2 designation is a reasonable
reading of a personal hand-off, not a document anyone can point to.

This is why his material stays at GPLv2 and is never relabelled: the
conservative treatment is the correct one when the terms are inferred
rather than recorded, and it is the respectful one toward the author.

**What was never in doubt.** Dedrick's *right* to make the release. He
was the sole author and therefore the sole copyright holder, and a sole
copyright holder may relicense their own work at any time. The 1997
shareware terms bound the people who received that distribution, not the
author. So the shareware history is not an obstacle to anything, and it
never was — the only inferred part is which licence he chose, not
whether the choice was his to make.

A note from Dedrick — even a forwarded email saying "GPLv2" or "GPLv2 or
later" — would convert the inference into a record and settle this
permanently. It is the single most valuable outstanding item in the
project's provenance, and he is the only person who can supply it.

### A note on the word "freeware"

netmodem2irc is **free software**, not freeware. Worth keeping straight
in a document meant to outlive its authors, because the two words get
used interchangeably and mean different things:

- *Freeware* means zero cost. It says nothing about source code, and is
  usually proprietary. This is the sense `WHATSNEW.TXT` used in 1997
  when it said NetModem v1.x had become freeware.
- *Free software* means the four freedoms: run it, study it, modify it,
  redistribute it. That is what the GPL grants.

The current status is the stronger of the two. The source is open and
the freedoms are guaranteed under GPLv2 for Dedrick's code and GPLv3 for
the revival. Describing the project as "freeware" undersells it and
would mislead someone who found it in fifty years.

## Open questions

These remain recorded, not resolved.

**1. No explicit "or later" clause for Dedrick's code.**
Nothing in the repo grants "version 2 or (at your option) any later
version" for his material. This is why `driver/src/`, `history/` and
`cpl/original_forms/` stay GPLv2 rather than moving to GPLv3 with the
rest — the conservative reading, and the respectful one.

**2. Derivation boundary between the engine and the VxD.**
Several engine units describe themselves as re-creations of what
`NETMODEM.ASM` did — for example `NM_UART16550.pas` is "a faithful
user-mode re-creation of the 16550 register file that Dedrick Allen's
Ring-0 VxD emulated." `common/NMVxD.pas` reproduces his `ComportStruct`
layout and `CM_*` message numbers so the two sides interoperate.

Reimplementing a documented hardware interface is ordinarily fine, and
interface constants needed for interoperability are usually treated as
uncopyrightable. But these units were written by reading his source, so
the line between clean reimplementation and derivative work is not
crisp. If any of it is derivative, that part inherits GPLv2 and the
GPLv3 label on those files would be wrong. Worth a look before release.

**3. com0com forecloses GPLv3 if it is ever forked in.**
com0com is GPLv2 (Vyacheslav Frolov) and `CREDITS.md` commits to keeping
any fork GPLv2. GPLv2-only and GPLv3 cannot be combined into one work.
A com0com-derived backend would therefore have to stay a separate
program communicating across a boundary, exactly as the VxD does — or
the combined work would have to be GPLv2.

## Third-party terms kept intact

`libs/synapse/` is modified BSD. Its per-file copyright headers are
embedded in each `.pas` and must not be stripped. It is compatible with
both GPLv2 and GPLv3.

`attic/WIN32COM.PAS` is ELECOM's, freeware under Maarten Bekers' terms:
credit, and send changes back.

## See also

- `CREDITS.md` — provenance and the hand-off
- `THIRD_PARTY.md` — Synapse bundling rationale
- `LICENSE` — GPLv3
- `LICENSE-GPLv2` — GPLv2
