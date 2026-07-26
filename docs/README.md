# docs/ — index

Audited 2026-07-25. 48 documents.

Naming convention: engineering docs carry the `netmodem2irc_` prefix.
Eight older files predate that convention and are listed unprefixed
below; they have not been renamed because they are referenced from the
root README and from each other.

## Architecture and specification

| Doc | Covers |
|---|---|
| `netmodem2irc_LAYER_A_SPEC.md` | UART + FOSSIL emulation layer |
| `netmodem2irc_NT_TRANSPORT_LAYER.md` | NT-branch user-mode replacement for Layer B |
| `netmodem2irc_SEAM_protocol.md` | driver↔server framed binary protocol |
| `netmodem2irc_DRIVER_MAP.md` | functional map of Dedrick's NETMODEM.ASM |
| `DRIVER_INTERFACE.md` | recovery record + FPC port guide |
| `netmodem2irc_driver_boundary.md` | the driver/server boundary |
| `netmodem2irc_serverlink.md` | concrete TServerLink for the TSR |
| `netmodem2irc_switch_upgrade.md` | switch-style bridge, fixes multinode sluggishness |

## FOSSIL

| Doc | Covers |
|---|---|
| **`netmodem2irc_fossil_separation.md`** | **real-UART DOS driver vs emulated-UART virtual comport, and `out/` layout — read this first** |
| **`netmodem2irc_watt32_cleanup_phases.md`** | **8-phase plan: strip Watt-32, build the real UART driver. Phase 3 blocks on the maintainer** |
| `netmodem2irc_FOSSIL_driver_scoping.md` | NetFOSSIL/32 revival scoping, M3.5 |
| `netmodem2irc_FOSSIL_crossvalidation.md` | our driver vs ELECOM FOS_COM |
| `netmodem2irc_fossil_getinfo.md` | Fn 1Bh GET_INFO |
| `netmodem2irc_fossil_block_io.md` | Fn 18h/19h block read/write |
| `netmodem2irc_fossil_dtr_fix.md` | Fn 06h SET_DTR fix |
| `netmodem2irc_fossil_audit_summary.md` | audit findings and fixes |
| `netmodem2irc_fossil_audit_todo.md` | **PARKED** — one finding remains |

## 16-bit / DOS / TSR

| Doc | Covers |
|---|---|
| `netmodem2irc_WHY_16BIT.md` | the preservation stance |
| `netmodem2irc_TSR_skeleton.md` | NM_TSR resident-program shell |
| `netmodem2irc_i8086_TSR_finish_guide.md` | fill-in guide for when the backport lands |

## Virtual COM port on NT

| Doc | Covers |
|---|---|
| **`netmodem2irc_synapse.md`** | **the bundled Synapse library file-by-file, NM_SynapseLink, and its two tests** |
| `netmodem2irc_com0com_notes.md` | how com0com works on modern Windows |
| `netmodem2irc_com2tcp_findings.md` | com0com + com2tcp source analysis |
| `netmodem2irc_Option_A_scoping.md` | native user-mode virtual COM driver |
| `netmodem2irc_driver_signing_notes.md` | where signing does and doesn't apply |
| `PROPOSAL_comport_library_for_fpc.md` | **proposal** — standard serial library for FPC |
| `netmodem2irc_comlib_scoping.md` | single COM library across all targets |

## Configuration

| Doc | Covers |
|---|---|
| `netmodem2irc_config.md` | configuration storage |
| `netmodem2irc_registry.md` | original registry layout |
| `netmodem2irc_cpl_config_design.md` | CPL configuration design |
| `GUI_BLUEPRINT.md` | Windows GUI recovery and rebuild |

## Audits

Each records a structural-sight sweep of one unit or path.

| Doc | Result |
|---|---|
| `netmodem2irc_transport_audit.md` | found + fixed: outbound IAC-doubling |
| `netmodem2irc_overflow_audit.md` | found + fixed: seam LEN overflow |
| `netmodem2irc_at_ghost_audit.md` | clean |
| `netmodem2irc_link_audit.md` | clean |
| `netmodem2irc_boundary_audit_full.md` | full seam/switch path |
| `testing_the_boundary.md` | method: proving a fix without the real condition |
| `netmodem2irc_TELNET_crossvalidation.md` | NetTransport vs ELECOM TELNET |

## Build and process

| Doc | Covers |
|---|---|
| `BUILD.md` | build instructions |
| `BUGS.md` | fpc264irc bugs — **dated: r3.1, 2026-07-18** |
| `netmodem2irc_M2_build_guide.md` | building the server in Lazarus |
| `netmodem2irc_M2_NT4_build_runbook.md` | NT4 build-and-test runbook |
| `netmodem2irc_commit_message_template.md` | commit message shape |
| `GITHUB_UPLOAD_WALKTHROUGH.md` | first-timer's publishing walkthrough |

## Milestones and roadmap

| Doc | State |
|---|---|
| `MILESTONE_netmodem2irc.md` | historical, still referenced |
| `netmodem2irc_M1_COMPLETE.md` | historical, still referenced |
| `netmodem2irc_RELEASE_ROADMAP.md` | roadmap |

## Licensing

Licensing lives at the repo root, not here.

| Doc | Covers |
|---|---|
| `../LICENSES.md` | which licence covers what, chain of title, open questions |
| `../LICENSE` | GPLv3 — the revival work |
| `../LICENSE-GPLv2` | GPLv2 — Dedrick Allen's original material |
| `../CREDITS.md` | provenance and the hand-off |
| `../THIRD_PARTY.md` | Synapse bundling rationale |
| `../driver/src/LICENSE-NOTICE.md` | GPLv2 notice guarding Dedrick's VxD source |

Short version: the revival is GPLv3, Dedrick's original material stays
GPLv2, Synapse is modified BSD. 68 source files under `engine/`,
`engine/test/`, `server/`, `config/`, `common/` and `dos/` carry GPLv3
headers; files belonging to other copyright holders were left untouched.

## Primary sources

`original/` holds Dedrick Allen's own documentation — `ATCOMNDS.TXT`,
`README.TXT`, `WHATSNEW.TXT`. Historical preservation, not ours to
edit.

## Notes from the 2026-07-25 audit

**Undated docs.** Only `BUGS.md` and `netmodem2irc_fossil_separation.md`
carry a date. The rest cannot be aged from their content. New docs
should open with a date line.

**`attic/docs/` removed.** It held 26 files, every one byte-identical to
its counterpart in `docs/`. They had been copied rather than moved, so
the same document was simultaneously "active" and "retired". The shadow
copies are gone; `docs/` is the only location. Recoverable from git if
needed.

**Root `netmodem2irc_CREDITS.md` removed.** `attic/README.md` recorded
it as retired and superseded by root `CREDITS.md`, but an identical copy
remained at the root, so the retirement had never taken effect. The
attic copy is retained as the record.

**DOS / FOSSIL settled, 2026-07-25.** `netfosdl.exe` is a standalone
FTSC FOSSIL driver over a real UART — not part of netmodem, no network.
Watt-32 removed; `dos/stubs.asm` retired to `attic/watt32/`. DOS and
i386 are independent platforms. Docs predating this that describe the
DOS side as a TCP bridge — including `dos/fpc-sockets-request.md` and
parts of `MILESTONE_netmodem2irc.md` — reflect the older design.
`netmodem2irc_fossil_separation.md` and
`netmodem2irc_watt32_cleanup_phases.md` are current.

**Relicensing, 2026-07-25.** The project moved to a split licence:
GPLv3 for revival work, GPLv2 retained for Dedrick Allen's material.
`LICENSES.md` was added at the root and records the chain of title.
Stale GPLv2-only claims were corrected in `THIRD_PARTY.md` and
`AUTHORS`. Docs in this directory describe engineering, not licensing —
if a doc here makes a licence claim, `LICENSES.md` overrides it.

**Outside this directory:** `DEFERRED-20260725.md` is the newest source
of truth on open runtime issues and supersedes older verdicts.
`InnoIRC561/` documents the installer port separately, with its own
`superseded/` folder.
