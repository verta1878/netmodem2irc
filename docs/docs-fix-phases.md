# Docs Fix — Phase Plan

Audited 2026-07-26. 55 docs in docs/, 5 in attic/docs/.

## Phase 1 — Restore missing directories (CRITICAL)

These were deleted from GitHub during the zip upload. Without them
the project doesn't compile and loses licensing provenance.

| Directory | Files | Impact |
|---|---|---|
| `libs/synapse/` | 17 | NMServer won't compile |
| `history/` | ~20 | Dedrick's distributions, licensing chain |
| `driver/src/` contents | 9 | Only LICENSE-NOTICE.md survived, NETMODEM.ASM etc missing |

Source: the session zip has all of these. Re-upload them.

## Phase 2 — Commit DEFERRED-20260725.md

In the container, never made it to GitHub. Two docs reference it.
Commit to the repo root.

## Phase 3 — Resolve duplicates

| Action | File | Why |
|---|---|---|
| Already moved to attic | `docs/ROADMAP.md` | Older copy of root (275 vs 317 lines) |
| Already moved to attic | `docs/THIRD_PARTY.md` | Older copy of root (84 vs 87 lines) |
| Move to attic | `NetModem2_GUI_Rebuild_Guide.md` | Near-identical to `GUI_BLUEPRINT.md` — 3 lines differ (filename renames: NMVxD→NetModemVxD, NMServer→NetModemServer). `GUI_BLUEPRINT.md` has the current names. |
| Already moved to attic | `docs/SYNAPSE_README.md` | Belongs in `libs/synapse/` |
| Already moved to attic | `docs/netmodem2irc_VMM_INC_notice.md` | Shorter duplicate of `VMM_INC_buildnote.md` |

## Phase 4 — Restore docs/README.md as the index

The current `docs/README.md` is a "session updates bundle" narrative
from an earlier session — not the 148-line doc index we wrote in the
last session. Regenerate the index with all 55 docs categorized.

## Phase 5 — Fix stale docs (banners + corrections)

### 5a. NETFOSSL.md — HEAVILY stale, needs a banner

Opens with "A FOSSIL driver that has no serial port behind it" and
describes TCP/IP via Watt-32 and an emulated 16550. Every major claim
is wrong under the current architecture:

| What it says | What's true now |
|---|---|
| "no serial port behind it" | netfosdl IS on a real UART |
| "emulated 16550 whose rings are fed by a TCP socket" | real 16550 hardware, no TCP |
| "Watt-32, and no C anywhere in the build" | Watt-32 removed |
| "backed by a TCP socket" | no network on DOS |
| binary name `netfossl` | renamed to `netfosdl` |

**Action:** add a banner: "HISTORICAL — predates the 2026-07-25
architecture decision. netfosdl is now a standalone FOSSIL driver on a
real UART with no network. See `netmodem2irc_fossil_separation.md` for
the current design."

Do NOT rewrite it — it is the design document for what netfossl was
*supposed to be* before the architecture settled. That history has
value.

### 5b. netmodem2irc_watt32_cleanup_phases.md — 3 stale names

Line 14: `netfossl` → `netfosdl` in the diagram
Line 23: `netfossl` → `netfosdl`
Line 219: `netfossl.exe` → `netfosdl.exe`

### 5c. netmodem2irc_FOSSIL_driver_scoping.md — "client" usage

Line 44: "the DOS driver is another client of" — uses "client" for
ISocketLink consumer, not FOSSIL client. This usage is technically
correct (it means socket-client, not FOSSIL-client) but confusing given
the session's disambiguation. Add a clarifying note.

Line 54: "ELECOM's FOS_COM.PAS is a DOS FOSSIL **client**" — correct,
FOS_COM IS a client. Leave as-is.

### 5d. MILESTONE_netmodem2irc.md — stale "CLIENT" label

Line 69: "i8086 DOS FOSSIL client (fpc264irc target, see dos/) = the
CLIENT side our NM_Fossil is [tested against]" — this predates the
architecture decision. The DOS side is now a PROVIDER, not a client.
Add a note: "NOTE: as of 2026-07-25, the DOS target is a FOSSIL
provider (netfosdl), not a client. See
`netmodem2irc_fossil_separation.md`."

### 5e. docs/README.md — complete rewrite (Phase 4)

### 5f. CREDITS.md — references fixed ✅

`tremedy2c.md` → pointed to `netmodem2irc_SEAM_protocol.md` §"Naming
for readability" (that's where the content actually lives).
`preservation_and_licenses.md` → pointed to `LICENSES.md`.

## Phase 6 — Resolve remaining missing docs

| Doc | Resolution |
|---|---|
| `tremedy2c.md` | ✅ RESOLVED — never existed as a separate file. Content is a section in `netmodem2irc_SEAM_protocol.md`. Reference in CREDITS.md fixed. |
| `preservation_and_licenses.md` | ✅ RESOLVED — covered by `LICENSES.md`. Reference in CREDITS.md fixed. |
| `fpc-sockets-request.md` | Was in `dos/`, the FPC GitLab feature request for i8086 sockets. sysop/0 may have made this moot with the pure Pascal sockets in fpc264irc. Recreate as a one-paragraph historical note, or update the 3 referencing docs to say "resolved by fpc264irc." |
| `NetModem2_Port_Guide.md` | Driver-source port guide. `DRIVER_INTERFACE.md` (226 lines) covers similar ground. Compare — if redundant, update the 2 references to point at `DRIVER_INTERFACE.md`. If different scope, need content from the maintainer. |
| `seeing_the_structure.md` | Design insight doc credited to the team. Referenced by `CREDITS.md`, `overflow_audit.md`, `testing_the_boundary.md`. Content must come from the maintainer — it documents "the lesson" that informed the audit method. |

## Phase 7 — Index the recovered docs

Add these to `docs/README.md` (after Phase 4 restores the index):

| Doc | Category | Notes |
|---|---|---|
| `NETFOSSL.md` | FOSSIL | with Phase 5a banner |
| `NetModem2_GUI_Rebuild_Guide.md` | — | moves to attic (Phase 3) |
| `elecom_modernization.md` | ELECOM | new category |
| `netmodem2irc_M1_HANDOFF.md` | Milestones | M1 history |
| `netmodem2irc_M1_MainForm_integration.md` | Milestones | M1 wiring guide |
| `netmodem2irc_VMM_INC_buildnote.md` | VxD / Driver | new category |

## Summary

| Phase | Items | Effort |
|---|---|---|
| 1 — Restore dirs | 3 dirs (~46 files) | re-upload from zip |
| 2 — Commit DEFERRED | 1 file | trivial |
| 3 — Duplicates | 1 more to move (GUI_Rebuild_Guide) | trivial |
| 4 — Restore index | 1 file | regenerate |
| 5 — Stale banners | 4 docs need banners/fixes | 30 min |
| 6 — Missing docs | 3 remaining (1 needs maintainer) | varies |
| 7 — Index recovered | 5 docs to add | 15 min |

**Phases 1–4 can be done right now. Phase 5 is mechanical. Phase 6
has one item that needs the maintainer (`seeing_the_structure.md`).
Phase 7 follows Phase 4.**
