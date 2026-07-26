# Changelog

## 2026-07-25 — licensing, docs audit, output layout

- **Licence split**: GPLv3 for revival work, GPLv2 retained for Dedrick
  Allen's original material. `LICENSE` is now GPLv3; `LICENSE-GPLv2`
  preserved; `LICENSES.md` added with the chain of title and open
  questions. No longer shareware.
- GPLv3 headers added to 68 source files (engine, engine/test, server,
  config, common, dos). Files under `driver/src/`, `history/`,
  `cpl/original_forms/`, `libs/synapse/` and `attic/` deliberately
  untouched. `driver/src/LICENSE-NOTICE.md` added.
- Stale GPLv2-only claims corrected in `THIRD_PARTY.md` and `AUTHORS`.
- **Docs audit**: `attic/docs/` removed — all 26 files were
  byte-identical shadow copies of live files in `docs/`. Root
  `netmodem2irc_CREDITS.md` removed; the attic copy is the retired one,
  as `attic/README.md` always said.
- `docs/README.md` added — index and status for all 46 docs.
- `docs/netmodem2irc_fossil_separation.md` added, then corrected by the
  maintainer. Both sides answer INT 14h; the real distinction is a
  **real UART** (DOS) versus an **emulated** one (virtual comport).
- **DOS settled as standalone with no network.** `netfosdl.exe` is a
  FTSC FOSSIL driver over a real UART — not part of netmodem, no `NM_*`
  units, no SEAM, no TCP. Must be a drop-in for X00 / BNU / ADF /
  NetFoss. DOS and i386 are independent platforms, not one pipeline.
- **Watt-32 removed.** `dos/stubs.asm` retired to `attic/watt32/`.
  The ten `_w32_*` externals in `dos/netmodem.pas` are to be deleted,
  not ported — FPC's i8086 `sockets` unit has no backend and `fcl-net`
  wraps `Sockets`/`WinSock2`/`Windows`, so neither works on DOS.
- `docs/netmodem2irc_watt32_cleanup_phases.md` added — 8 phases.
- `docs/netmodem2irc_synapse.md` added — the bundled library file by
  file, `NM_SynapseLink`, and its two tests. Records that
  `libs/synapse/smtpsend.pas` is a zero-byte placeholder and that
  `synaser.pas` is unused.
- `engine/NM_Debug.pas` added — central debug logging. Compiles to
  nothing without `-dNM_DEBUG`. Win32: `OutputDebugString` + file.
  DOS: file or stderr. Play/Stop and a visual debug panel planned,
  inspired by Carl Gorringe's RIPtermJS debug log.
- `ROADMAP.md` added — master roadmap across all three tracks, order of
  work, and the aggressive commenting standard codified.
- **Output layout**: `out/` split by target arch into `dos/`, `win32/`,
  `i386/`. `out/i386/` contents undecided.
- `InnoIRC561/`: source extracted to `src/` (498 files), tarball rebuilt
  without build artifacts (4.7M to 2.2M), original upstream tarball
  restored and renamed
  `innosetup-5.6.1-ORIGINAL-delphi-not-win98.tar.gz`, three superseded
  docs moved to `InnoIRC561/superseded/`, Phase 10 opened for the
  ISCmplr DLL-init AV.

## Current — full config GUI, global settings, installer

- ConfigMain: all 11 per-node fields + 25 global settings wired to GUI
  (5 tabbed pages: Comports, Server, Logging, Options, Features)
- NM_GlobalConfig: server-level settings (registry + NETCONFIG.CNF)
- NM_Listserv: BBS directory registration (designed by Dedrick, never finished)
- NM_AutoNews: periodic news broadcast (designed by Dedrick, never finished)
- Original NETMODEM.CPL (657KB, Delphi 5) preserved and shipped as-is
- Icons: 14 icons + 36 bitmaps extracted from original CPL
- Globe + splash bitmaps extracted from TForm1
- Inno Setup installer script (InnoIRC561/netmodem2irc.iss)
- build.sh: win32/tests/fossil/resources/clean targets
- 38/38 tests, 0 failures
- fpc264irc r3.1+

## M1 — engine integrated

- Engine: UART 16550, FOSSIL INT 14h, Telnet transport, AT commands,
  multinode manager, Synapse + named-pipe links, server bridge
- NM_Config: all 11 per-node ComportStruct fields, 14 baud rates
- NM_DefaultConfig: factory defaults, registry read/write
- NMVxD: driver interface with {$IFDEF WINDOWS} guards
- SEAM protocol: driver↔server framed binary protocol
- TSR skeleton: FOSSIL resident-program framework
- Win32 cross-compile from Linux
- DOS i8086 FOSSIL bridge (netfossl.exe, 179KB)
- 38 test programs covering all engine units

## M0 — initial recovery

- Recovered Dedrick Allen's original NetModem/32 source
- VxD driver (NETMODEM.ASM/INC/DEF) — experimental
- Original distributions preserved (net32_b4, netmdb15)
- Original CPL binary + 6 decompiled DFM forms
