# Inno Setup 5.6.1 — FPC Port

Inno Setup 5.6.1 ported to FPC 2.6.4irc.
Uses real LCL (no VCL stubs). Requires fpc264irc r3.1 Phase 9.

**Target range: Windows 98 → Windows 11**, single i386-win32 binary.
Min OS 4.0 with DEP and ASLR disabled keeps Win9x happy while still
loading on current Windows.

Virtual COM ports split by OS family: **com0com** on NT-family,
**NETMODEM.VXD** on Win9x. Two open questions on the com0com path — it
is GPLv2, so a backend built on it is an acknowledged fork, and its
`.inf` is NT-family only, so Win9x support is unproven. See
`DEFERRED-20260725.md` (DEFERRED 7) and `CREDITS.md`.

Port work: 2026-07-19 → 2026-07-23. Phases 1-9 complete, Phase 10 open.

## Layout

```
InnoIRC561/
├── src/                                          9.3M  — uncompressed FPC port source (498 files)
│   └── issrc-is-5_6_1/
│       ├── Projects/                             295 files — the port lives here
│       │   ├── *.dpr (5)                                 — build targets: ISCC, ISCmplr,
│       │   │                                               Setup, SetupLdr, Compil32
│       │   ├── *.pas (103)                               — ported units + ~35K lines PascalScript
│       │   ├── *.lfm (7)  *.lrs (7)                      — Phase 6 form conversions
│       │   ├── *.dfm (13)                                — original Delphi forms, kept for diffing
│       │   ├── *.rc (8)  *.res (21)                      — Phase 5 Windows resources
│       │   ├── *.inc (8)                                 — VERSION.INC and friends
│       │   ├── *.fpas (11)                               — dead VCL stubs, superseded by real LCL
│       │   ├── *.o (3)                                   — LZMA objects, {$L} link inputs
│       │   ├── Lzma2/C/  Lzma2/Decoder/  Lzma2/Encoder/  — LZMA SDK + Inno wrappers (C source)
│       │   ├── LzmaDecode/                               — small decoder for SetupLdr (C source)
│       │   ├── ISPP/                                     — preprocessor + its help source
│       │   └── Helper/x64/Release/                       — 64-bit helper binary
│       ├── Components/                            25 files — shared controls
│       │   └── Ps/  UniPs/                                — PascalScript component glue
│       ├── Files/                                  86 files — runtime payload
│       │   └── Languages/Unofficial/                      — .isl translations
│       ├── ISHelp/                                 32 files — help source
│       │   └── ISHelpGen/  Staging/images/
│       ├── Examples/                               46 files — sample .iss scripts
│       │   └── MyDll/{C,C#,Delphi}/  MyProg/Help/
│       ├── compile.bat  build.bat                        — original Delphi build scripts (unused)
│       ├── setup.iss                                     — Inno's own installer script
│       ├── license.txt  README.md  CONTRIBUTING.md
│       ├── whatsnew.htm
│       └── VCL-Controls-*.txt  scintilla-*.txt           — upstream patch notes
├── out/                                           14M  — 19 files: 5 built targets + helper DLLs + bitmaps
│   ├── ISCC.exe  ISCmplr.dll  Setup.exe  SetupLdr.exe  Compil32.exe
│   ├── Setup.e32  SetupLdr.e32                          — pre-patch copies
│   ├── islzma.dll  islzma32.exe  iszlib.dll  isunzlib.dll
│   ├── isbzip.dll  isbunzip.dll  isscint.dll
│   ├── WizModernImage.bmp  WizModernSmallImage.bmp
│   ├── Default.isl
│   └── netmodem2irc.iss  test.iss
├── lzma/                                          36K  — 3 MinGW-built LZMA decoder objects
│   ├── ISLzmaDec.o  ISLzma2Dec.o  LzmaDecodeInno.o
│   └── README.md                                        — how they were built
├── innosetup-5.6.1-ORIGINAL-delphi-not-win98.tar.gz  1.9M — pristine upstream — NOT Win98, do not build
├── innosetup-5.6.1-fpc-src.tar.gz                   2.2M — port snapshot, artifacts stripped
├── netmodem2irc.iss                                      — installer script for NetModem/32
├── README.md                                             — this file
├── INNO_ORIGINAL_SOURCE.md                               — provenance + why the original is unusable
├── INNO_FPC_PORT.md                                      — per-phase detail, build, toolchain
└── superseded/                                          — superseded docs, kept for the record
    ├── INNO_FPC_WORKMAP.md                                   — file-by-file FPC-compat audit
    ├── INNO_FPC_PORT_FEATURES_LIST.md                        — pre-Phase-4 gap list
    └── INNO_HOLLOW_FEATURES.md                               — pre-Phase-4 stub inventory
```

Build from `src/`. The two tarballs are archives, not build inputs.

## Compiled Binaries (i386-win32)

All carry Win98-compatible PE headers: min OS 4.0, DllCharacteristics
0x0000 (no DEP, no ASLR).

| File | Size | Subsystem | Status |
|------|------|-----------|--------|
| ISCC.exe | 437K | CONSOLE | ✅ Verified on Win98 SE |
| ISCmplr.dll | 1.9M | CONSOLE | ⚠️ Builds, AV at DLL init |
| Setup.exe | 3.6M | GUI | ⚠️ Builds, AV at form init |
| SetupLdr.exe | 316K | GUI | ✅ Builds |
| Compil32.exe | 3.2M | GUI | ✅ Builds |

`.e32` files are the pre-patch copies from before the CONSOLE→GUI
subsystem patch was applied.

## Phase Status

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | ISCC.exe (console compiler) | ✅ |
| 2 | Compression libraries | ✅ |
| 3 | LCL integration (301 LCL PPUs) | ✅ |
| 4 | LZMA decompression (MinGW .o) | ✅ |
| 5 | Windows resources (fpcres) | ✅ |
| 6 | DFM → LFM forms (7 via lazres) | ✅ |
| 7 | PascalScript (~35,000 lines) | ✅ |
| 8 | Compil32.exe IDE | ✅ |
| 9 | Runtime testing | ⚠️ Partial |
| 10 | ISCmplr — DLL-init AV + portability | ⬜ Open |

### Phase 10: ISCmplr — DLL-init AV + toolchain portability

Highest-value open item. Two separate problems, detail in
`INNO_FPC_PORT.md`.

**10a — AV during DLL initialization.** `wine ISCC.exe
netmodem2irc.iss` returns rc=5; ISCmplr.dll fails to initialize with
`status c0000005`, before any `.iss` parsing. Display ruled out under
Xvfb. DLL is well-formed (PE32 i386, ImageBase 0x800000, relocs
intact). This is the second binary to AV at init after Setup.exe —
likely a shared defect in the port's init path.

**10b — will not build under stock FPC 3.2.2.** 44 errors on the
`Colors` constant array at `Compile.pas:603`; stock LCL's `TColor`
range rejects the 42 colour constants. Compile-time constant folding,
so `-Cr-` and `{$R-}` don't suppress it. Preferred fix: type the array
as `Longint`/`TColorRef` and cast at use sites, which keeps both
toolchains building from one source.

## Runtime Status

- **ISCC.exe** — runs correctly on real Windows 98 SE and under Wine;
  produces working installers.
- **Setup.exe** — access violation during form initialization on
  Win98, Win11 and Wine. Unresolved. CONSOLE→GUI subsystem patch
  applied as a candidate fix; `test-setup.exe` and `net32_20setup.exe`
  built with it are still untested on real hardware.
- **ISCmplr.dll** — access violation during DLL initialization
  (Phase 10a).

The original verdict on the Setup.exe AV was a Wine codepage
limitation. Two binaries now fault at init on three platforms, which
argues instead for a real defect in the port's initialization path.
Treat the codepage explanation as unconfirmed.

## Build

```bash
cd src/issrc-is-5_6_1/Projects

FPC=/path/to/fpc264irc/bin/ppc386
RTL=/path/to/fpc264irc/bin/units/i386-win32
LCL=/path/to/fpc264irc/bin/lazarus/units/i386-win32
TOOLS=/path/to/fpc264irc/bin/tools/i386-win32

FLAGS="-Twin32 -Mdelphi \
  -Fu$RTL -Fu$LCL/lazutils -Fu$LCL/lcl -Fu$LCL/lcl/win32 \
  -Fu../Components -FU. -FE../../out \
  -FD$TOOLS"

$FPC $FLAGS ISCC.dpr
$FPC $FLAGS Setup.dpr
$FPC $FLAGS SetupLdr.dpr
$FPC $FLAGS ISCmplr.dpr
$FPC $FLAGS Compil32.dpr
```

## Toolchain

**fpc264irc is currently an empty repository** — zero refs, zero
commits, nothing to clone. The build recipe above cannot be run as
written until it is restored. Stock FPC 3.2.2 is the only working
compiler on hand; see below.

fpc264irc r3.1 Phase 9 is required. It supplies 587 RTL PPUs and 301
LCL PPUs with consistent checksums, plus `Ctl3D`/`ParentCtl3D` on
TWinControl, `OEMConvert` on TCustomEdit, the `CreateWindowHandle`
virtual method, and the 3-param `paswstring` overloads. It also ships
the PascalScript source, `lazres`, `lrstolfm`, `fpcres`, and GNU
ld/as/ar for i386-win32.

### Building with stock FPC 3.2.2 (not supported)

Tested 2026-07-25 against FPC 3.2.2 `ppcross386` + stock Lazarus LCL.
4 of 5 targets compile: ISCC, SetupLdr, Setup, Compil32. ISCmplr fails
with 44 identical errors on the `Colors` constant array at
`Compile.pas:603` — stock LCL declares `TColor` with a range the
`clBlack`/`clMaroon`/etc. constants don't satisfy. It is a compile-time
constant evaluation, so neither `-Cr-` nor `{$R-}` suppresses it.

The resulting binaries are ~20MB against fpc264irc's ~3.6MB and carry
none of the Win98 LCL patches. Useful as a syntax check only — do not
ship them.

## Document Status

Audited 2026-07-25.

| Doc | State |
|-----|-------|
| `README.md` | Current — canonical for layout and phase status |
| `INNO_FPC_PORT.md` | Current — per-phase detail, build, toolchain |
| `INNO_ORIGINAL_SOURCE.md` | Current — upstream provenance and SHA256 |
| `superseded/INNO_FPC_WORKMAP.md` | Superseded — obsolete phase numbers; FPC-compat audit still valid |
| `superseded/INNO_FPC_PORT_FEATURES_LIST.md` | Superseded — pre-Phase-4 |
| `superseded/INNO_HOLLOW_FEATURES.md` | Superseded — pre-Phase-4 |

The three historical docs describe the stub-era build before Phases
4-8. They carry banners saying so. `INNO_FPC_WORKMAP.md` used a
different phase numbering (4=Setup.exe Runtime, 5=Component Controls,
6=GUI Wizard); the numbering in this README is canonical.

Outside this directory, `DEFERRED-20260725.md` is the newest source of
truth on open runtime issues and supersedes older verdicts.
