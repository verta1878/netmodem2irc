# Docs Repair Roadmap

Audited 2026-07-26 against the repo at commit `86a8595`.

## Summary

| Category | Count |
|---|---|
| Docs on disk (docs/) | 59 |
| Recovered this session (new) | 9 |
| Still missing (referenced, not on disk) | 6 |
| Missing directories (deleted during upload) | 3 |
| Duplicates (root vs docs/) | 2 |
| Overwritten (docs/README.md) | 1 |
| Recoverable from container | 1 (DEFERRED-20260725.md) |
| Need to recreate from context | 5 |

## Priority 1 — Restore deleted directories

These existed in our session's commits but were deleted from GitHub
during the cleanup-and-reupload. They need to be restored from the
zip or re-pushed.

| Directory | Contents | Impact |
|---|---|---|
| `libs/synapse/` | 17 files (720K) — the bundled TCP library | **NMServer won't compile without it** |
| `history/` | Dedrick's original distributions — `net32_b4/`, `netmdb15/`, `NETMODEM.CPL` | licensing provenance, historical record |
| `driver/src/` contents | Dedrick's VxD source — `NETMODEM.ASM`, `.INC`, `.DEF`, `.RC` | only `LICENSE-NOTICE.md` survived; 9 files missing |

`attic/docs/` does NOT need restoring — those 26 files were shadow
copies we deliberately deleted. But `attic/` itself should have
`README.md`, `WIN32COM.PAS`, `netmodem2irc_CREDITS.md` and `watt32/`.

## Priority 2 — Fix duplicates and overwrites

| File | Problem | Fix |
|---|---|---|
| `docs/README.md` | Overwritten with a "session bundle" narrative. Was our 148-line doc index. | Restore the index version. |
| `docs/ROADMAP.md` (275 lines) | Duplicate of root `ROADMAP.md` (317 lines). Root is newer and has the dual-compiler policy. | Delete `docs/ROADMAP.md`, keep root only. |
| `docs/THIRD_PARTY.md` (84 lines) | Duplicate of root `THIRD_PARTY.md` (87 lines). Root has the GPLv3 compatibility update. | Delete `docs/THIRD_PARTY.md`, keep root only. |

## Priority 3 — Commit DEFERRED-20260725.md

Exists in this container at `/home/claude/DEFERRED-20260725.md` (6,467
bytes). Referenced by `InnoIRC561/README.md` and
`netmodem2irc_fossil_separation.md`. Never made it into the repo.

Commit it to the root.

## Priority 4 — Missing docs that need recreating

These are referenced from other docs but have never existed in the repo.

| Missing doc | Referenced from | Can recreate from |
|---|---|---|
| `fpc-sockets-request.md` | 3 docs + `attic/watt32/README.md` | Was in `dos/`, the FPC GitLab feature request. sysop/0 may have made it moot with the pure Pascal sockets in fpc264irc. Recreate as a historical record or mark references as resolved. |
| `NetModem2_Port_Guide.md` | `GUI_BLUEPRINT.md`, `NetModem2_GUI_Rebuild_Guide.md` | driver-source port guide. `DRIVER_INTERFACE.md` may cover the same ground — compare before writing a new one. |
| `preservation_and_licenses.md` | `CREDITS.md` | licensing preservation notes. `LICENSES.md` now covers this. Update the reference or write a short pointer doc. |
| `seeing_the_structure.md` | `CREDITS.md`, `overflow_audit.md`, `testing_the_boundary.md` | design insight doc credited to the team. Content must come from the maintainer — referenced as containing "the lesson" that informed the overflow audit method. |
| `tremedy2c.md` | `CREDITS.md` (same line as `seeing_the_structure.md`) | unknown scope. Ask the maintainer. |

## Priority 5 — Index and categorize the 9 recovered docs

These are new to the repo and need to be added to `docs/README.md`
(once it's restored to the index version).

| Doc | Lines | Category |
|---|---|---|
| `NETFOSSL.md` | 381 | FOSSIL — pre-decision design doc, may conflict with current architecture |
| `NetModem2_Build_Roadmap.md` | 112 | Build — early-stage build plan, likely superseded by `ROADMAP.md` |
| `NetModem2_GUI_Rebuild_Guide.md` | 128 | GUI — CPL/GUI rebuild from decompiled alpha-3 |
| `elecom_modernization.md` | 61 | ELECOM — modernizing Maarten Bekers' comms library |
| `netmodem2irc_M1_HANDOFF.md` | 50 | Milestones — engine handoff to the Lazarus build |
| `netmodem2irc_M1_MainForm_integration.md` | 150 | Milestones — wiring the engine into MainForm |
| `netmodem2irc_VMM_INC_buildnote.md` | 113 | VxD build — VMM.INC corruption finding |
| `netmodem2irc_VMM_INC_notice.md` | 52 | VxD build — same finding, shorter version |
| `SYNAPSE_README.md` | 50 | Synapse — duplicate? `libs/synapse/SYNAPSE_README.md` should be the canonical copy |

### Docs to audit for staleness

`NETFOSSL.md` opens with "A FOSSIL driver that has no serial port behind
it" — this predates the decision that netfosdl IS on a real UART and is
standalone. It needs a banner or a rewrite.

`NetModem2_Build_Roadmap.md` is an early build plan. Compare against
root `ROADMAP.md` — if superseded, move to `superseded/` or add a
banner.

`netmodem2irc_VMM_INC_buildnote.md` and `netmodem2irc_VMM_INC_notice.md`
cover the same finding (corrupted VMM.INC). Keep one, move the other.

## Priority 6 — References that resolve without new docs

| Reference | Resolution |
|---|---|
| `CONTRIBUTING.md` | Exists inside `InnoIRC561/src/` — it's upstream Inno's, not ours. Reference is correct in context. |
| `DRIVER_MAP.md` | `netmodem2irc_DRIVER_MAP.md` exists. The short-name reference should be updated to the full name. |
| `netmodem2irc_CREDITS.md` | Deliberately retired to `attic/`. References in `CHANGELOG.md` and `attic/README.md` are about the retirement itself — correct as-is. Root `README.md` and `ROADMAP.md` references should be removed. |
