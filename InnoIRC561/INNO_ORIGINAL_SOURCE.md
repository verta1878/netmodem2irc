# innosetup-5.6.1-ORIGINAL-delphi-not-win98.tar.gz — Original Inno Setup Source

**This is NOT the Win98 source. Do not build from it.**
For the Win98 build, use `src/` (or `innosetup-5.6.1-fpc-src.tar.gz`).

## What this file is

Pristine, unmodified Inno Setup 5.6.1 source as published by
jrsoftware. Nothing in this archive is our work — it is kept purely
as the reference baseline to diff the FPC port against.

| | |
|---|---|
| File | `innosetup-5.6.1-ORIGINAL-delphi-not-win98.tar.gz` |
| Size | 1,983,699 bytes |
| SHA256 | `2985cd6a1e2d21a0429f0d430297e7bad1b255e73c7f8f813be1b91f523ab092` |
| Entries | 464 |
| Root dir | `issrc-is-5_6_1/` |
| File dates | all 2018-06-13 |
| Upstream | `jrsoftware/issrc`, tag `is-5_6_1` |
| Origin | https://github.com/jrsoftware/issrc/archive/refs/tags/is-5_6_1.tar.gz |

Provenance verified 2026-07-25: the copy re-downloaded from upstream
GitHub, the copy recovered from git history (`235cd69^`), and the copy
in the release staging tree all hash identically to the SHA256 above.

## Why it is not Win98-usable

Two independent reasons.

**1. Upstream dropped Win9x six years before this release.**
Inno Setup 5.5.0 (2012-05-29) removed Windows 95, 98, Me and NT 4.0
support from the non-Unicode build; Windows 2000 became the minimum
supported OS. The Unicode build never supported Win9x at all. 5.6.1
(2018) is well past that cutoff, so stock Inno 5.6.1 will not run on
Windows 98 even if built correctly.

**2. It cannot be built with our toolchain anyway.**
This is Delphi source. It will not compile under FPC 2.6.4irc without
the port's changes — `Application.Handle`, `Ole2` vs `ActiveX`,
IAssemblyCache interface syntax, `CompareFileTime` pointer params,
Int64Em record layout, and the DFM/RES resource handling all differ.

None of the Win98 fixes exist in this archive:

| Fix | Original | FPC port |
|---|---|---|
| CRC32 table indexing | `Lo(CurCRC)` — OOB under FPC | `Byte(CurCRC)` |
| LZMA decoder objects | Borland COFF `.obj`, unlinkable by FPC | MinGW `.o` |
| Forms | 13 `.dfm` only | 7 `.lfm` added |
| PE subsystem | n/a | patched CONSOLE to GUI |
| PE min OS / DllChar | n/a | 4.0 / 0x0000 |

## What to use instead

| Path | Contents |
|---|---|
| `src/` | FPC port, uncompressed, 498 files — **build from here** |
| `innosetup-5.6.1-fpc-src.tar.gz` | same port, archived snapshot incl. build artifacts |
| `out/` | built binaries, Win98 PE flags applied |
| `lzma/` | MinGW-built LZMA decoder objects |

Port work dates: 2026-07-19 through 2026-07-23.
Build instructions and phase status: `INNO_FPC_PORT.md`.
Original-vs-ours audit: `INNO_FPC_WORKMAP.md`.
