# Inno Setup 5.6.1 — FPC 2.6.4irc Port

**Status:** 4/5 targets compile clean, runtime hollow
**Compiler:** fpc264irc r3.1 Phase 9
**Target:** i386-win32 (Windows 98 — Windows 11)

## Build Targets

| Target | Size | Status |
|--------|------|--------|
| ISCC.exe (command-line compiler) | 437KB | ✅ |
| ISCmplr.dll (compiler DLL) | 749KB | ✅ |
| Setup.exe (installer GUI) | 14MB | ✅ |
| SetupLdr.exe (setup loader) | 313KB | ✅ |
| Compil32.exe (IDE) | — | ❌ Phase 8 |

## Phases

All toolchain support confirmed in fpc264irc Phase 9.

### Phase 1: ISCC.exe ✅ DONE
Console compiler. No GUI, no LCL. 437KB.

### Phase 2: Compression ✅ DONE
Compress.pas, CompressZlib.pas, bzlib.pas, LZMA.pas (compressor).
All use dynamic loading via GetProcAddress.

### Phase 3: LCL Integration ✅ DONE
Real LCL (no VCL stubs). 301 LCL PPUs. Setup.exe, ISCmplr.dll,
SetupLdr.exe all compile clean. Requires fpc264irc Phase 9 for
Ctl3D, ParentCtl3D, OEMConvert, CreateWindowHandle, paswstring.

### Phase 4: LZMA Decompression
Compile LZMA C decoder source with MinGW cross-compiler to produce
.o files that FPC can link. Source in-tree:

```
Projects/Lzma2/Decoder/ISLzmaDec.c    — LZMA1 decoder wrapper
Projects/Lzma2/Decoder/ISLzma2Dec.c   — LZMA2 decoder wrapper
Projects/Lzma2/C/LzmaDec.c            — LZMA SDK decoder
Projects/LzmaDecode/LzmaDecodeInno.c   — small decoder
```

fpc264irc ships GNU ld + as for i386-win32 cross-linking. Replace
the 13 stub functions in LZMADecomp.pas and LZMADecompSmall.pas
with `{$L}` directives pointing to the MinGW-compiled .o files.

**Unblocks:** Setup.exe can extract installer payloads.

### Phase 5: Windows Resources
Build .res files with fpcres or windres. fpc264irc ships:

- `fpcres` source + build script (`tools/build-fpcres.sh`)
- `fpcres` native binary (`src/utils/fpcres/fpcres`, prebuilt)

8 .rc source files need compilation. 15 prebuilt .res files on disk
(from original Delphi build) may work directly if fpcres accepts them.

| Resource | Target | Contents |
|----------|--------|----------|
| Setup.res | Setup.exe | Application icon |
| Images.res | Setup.exe | Wizard bitmaps |
| SetupVersion.res | Setup.exe | Version info |
| ISCC.res | ISCC.exe | Application icon |
| ISCC.manifest.res | ISCC.exe | UAC manifest |
| ISCmplr.res | ISCmplr.dll | Version info |
| SetupLdr.res | SetupLdr.exe | Application icon |
| SetupLdrVersion.res | SetupLdr.exe | Version info |
| SetupLdrOffsetTable.res | SetupLdr.exe | Embedded data offset |
| XPTheme.res | Setup.exe | Visual styles manifest |
| HelperEXEs.res | Setup.exe | 64-bit helper binary |

**Unblocks:** Icons, version info, manifests, wizard bitmaps.

### Phase 6: DFM → LFM Forms
Convert 13 Delphi DFM forms to LCL LFM format. fpc264irc ships:

- `lazres` — embeds LFM resources into executables (prebuilt, both
  Linux and Win32 binaries)
- `lrstolfm` — converts LRS (Lazarus resource) to LFM (prebuilt)

DFM .txt files (text-format DFM) are in-tree for all 13 forms.
7 are installer forms (Main, Wizard, NewDisk, SelFolderForm,
SelLangForm, UninstProgressForm, UninstSharedFileForm). 6 are IDE
forms (Phase 8).

**Unblocks:** Wizard layout, dialog positioning, visual UI.

### Phase 7: PascalScript [Code] Section
Full RemObjects PascalScript engine. Source ships with fpc264irc
in `src/lazarus/components/PascalScript/Source/`:

| Unit | Lines | Purpose |
|------|-------|---------|
| uPSCompiler.pas | 15,739 | Bytecode compiler |
| uPSRuntime.pas | 12,669 | Bytecode interpreter |
| uPSDebugger.pas | 654 | Script debugger |
| uPSUtils.pas | 1,728 | Shared types |
| uPSC_*.pas (9) | ~2,400 | Class registration (compiler) |
| uPSR_*.pas (9) | ~2,100 | Class wrappers (runtime) |
| **Total** | **~35,000** | |

Replace the 22 stub files (410 lines) with the real source.
Restore ScriptRunner.pas (543 lines), ScriptCompiler.pas (464),
ScriptClasses_C/R, ScriptDlg, ScriptFunc, ScriptFunc_C/R to
original Inno code pointing at real PascalScript units.

**Unblocks:** [Code] sections, custom wizard pages, ~150 built-in
functions, DLL imports, serial/password validation, all wizard
event hooks, uninstaller script events.

### Phase 8: Compil32.exe (IDE)
Fix 5 ScintEdit.pas errors:

- Byte ↔ set casts (FPC stricter than Delphi)
- POINT vs LPPOINT (FPC API binding difference)
- SListIndexError (add RTLConsts to uses)

Then wire up CompForm, CompOptions, CompSignTools, CompStartup,
CompWizard, CompWizardFile forms.

**Unblocks:** Graphical IDE with Scintilla editor.

### Phase 9: SetupCompat + Runtime Testing
- Fix ListContains (delimiter-aware matching)
- Implement ExpandSetupMessage ({app}, {sys}, {cm:...}, {code:...})
- Implement TAlphaBitmap (premultiplied alpha)
- Runtime test on Win98 and Win11
- Build netmodem2irc installer with ISCC.exe
- Test full install/uninstall cycle

**Unblocks:** Working installer for netmodem2irc.

## Build Instructions

```bash
cd issrc-is-5_6_1/Projects

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
```

## Changes from Original Delphi Source

See INNO_FPC_WORKMAP.md for detailed audit.

### Key changes:
- `Application.Handle` → `GetAppHandle` (FPCCompat.pas)
- `Ole2` → `ActiveX` (LibFusion.pas, CmnFunc2.pas)
- IAssemblyCache → proper `interface` syntax
- CompareFileTime → pointer parameters
- VERSION.INC: Delphi3orHigher defined, no UNICODE
- Int64Em.pas: full .Hi/.Lo record implementation
- All `{$R *.DFM}` disabled (Phase 6 restores via LFM)
- All `{$R *.res}` disabled (Phase 5 restores via fpcres)
- ScriptCompiler.pas: expanded stub with correct signatures
- Compile.pas: added LCLStrConsts for SmkcBkSp etc.
- D2009Win2kFix.pas: gutted (Delphi-specific)
- LZMA COFF .obj disabled (Phase 4 restores via MinGW)

### Requires fpc264irc Phase 9:
- Ctl3D / ParentCtl3D on TWinControl
- OEMConvert on TCustomEdit
- CreateWindowHandle virtual method
- paswstring IFDEF overloads (3-param Win32 / 4-param Unix)
- ustringh.inc reverted to 3-param
- 587 RTL PPUs + 301 LCL PPUs (consistent checksums)
- PascalScript source (src/lazarus/components/PascalScript/Source/)
- lazres + lrstolfm (prebuilt)
- fpcres source + build script
- GNU ld/as/ar for i386-win32 cross-linking
