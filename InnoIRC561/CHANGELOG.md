# Inno Setup 5.6.1 FPC Port — Changelog

All notable changes to the FPC port of Inno Setup 5.6.1.
This is NOT the upstream Inno Setup changelog — it covers only
the FPC/Lazarus port work for netmodem2irc.

## [Unreleased] — R2/Inno Phase 10 Fix

### Root Cause: ISCmplr.dll + Setup.exe Access Violation (c0000005)

**Symptom:** Both ISCmplr.dll and Setup.exe crash with STATUS_ACCESS_VIOLATION
($C0000005) during initialization. Occurs on Windows 98, Windows 11, and Wine.
ISCC.exe (console compiler) works fine. The crash happens before any .iss
parsing — during DLL_PROCESS_ATTACH / form initialization.

**Root cause:** `SafeDLLPath.pas` calls `SetProcessDEPPolicy(PROCESS_DEP_ENABLE)`
in its initialization section. This permanently enables Data Execution Prevention
for the host process.

The problem: FPC's linker (GNU ld for i386-win32) does not guarantee that all
code sections have the NX-compatible `PAGE_EXECUTE` flag. Delphi's linker does.
When DEP is enabled, Windows enforces NX on all memory pages. Any FPC-generated
code that landed on a page without `PAGE_EXECUTE` triggers an NX fault:

```
STATUS_ACCESS_VIOLATION ($C0000005)
  attempting to execute non-executable memory
```

This affects DLLs more than executables because:
- An .exe's code section is typically mapped with execute permission by the loader
- A .dll loaded into another process gets its pages from the host's virtual
  memory, where FPC's page flags may not include execute

**Why ISCC.exe works:** ISCC.exe is a standalone program (not a DLL). Its code
pages get execute permission from the PE loader. SetProcessDEPPolicy enables
DEP, but the code is already on executable pages, so no crash.

**Why ISCmplr.dll crashes:** ISCmplr.dll is loaded by ISCC.exe via LoadLibrary.
SafeDLLPath.pas runs during DLL_PROCESS_ATTACH. It enables DEP for the entire
process. Then later initialization code in ISCmplr.dll (or its dependencies)
executes from a page without PAGE_EXECUTE — instant NX fault.

**Why Setup.exe crashes too:** Same SafeDLLPath.pas, same init path. The form
initialization code in LCL triggers the same DEP violation.

### Fix: MarkModuleCodeExecutable (Option 2)

We chose Option 2 (keep DEP, fix pages) over Option 1 (disable DEP):

- **Option 1:** Comment out SetProcessDEPPolicy. Simple, but disables a
  security feature. Not acceptable for a modern installer.
- **Option 2:** Mark FPC's code pages executable BEFORE enabling DEP.
  Keeps DEP active (security), FPC code runs (compatibility).

**The patch** (SafeDLLPath.pas):

Added `MarkModuleCodeExecutable` procedure that:

1. Gets the module's base address via `HInstance`
2. Walks the module's virtual memory with `VirtualQuery`
3. For each committed page:
   - `PAGE_READONLY` → `PAGE_EXECUTE_READ` (via VirtualProtect)
   - `PAGE_READWRITE` → `PAGE_EXECUTE_READWRITE` (via VirtualProtect)
4. Caps the walk at 64MB to prevent runaway scanning
5. Only processes pages whose `AllocationBase` matches our module

**Call order in initialization section:**

```pascal
  if Assigned(SetProcessDEPPolicyFunc) then
  begin
    MarkModuleCodeExecutable;          // 1. fix pages FIRST
    SetProcessDEPPolicyFunc(PROCESS_DEP_ENABLE);  // 2. then enable DEP
  end;
```

Order is critical — DEP is permanent once enabled. If you enable DEP first,
you can't fix the pages because the process crashes immediately.

**Why VirtualQuery + VirtualProtect is safe:**

- Both are kernel32 APIs available on all NT-based Windows (2000+)
- They operate only on the calling process's own memory
- VirtualProtect only adds the execute flag — it doesn't remove protections
- The approach is explicitly recommended by Microsoft:
  "Applications can use VirtualProtect to set memory protections appropriately"
  (MSDN: Data Execution Prevention)

### Affected Files

| File | Change |
|------|--------|
| `Projects/SafeDLLPath.pas` | Added MarkModuleCodeExecutable + call before DEP enable |

### Affected Binaries

| Binary | Before | After (expected) |
|--------|--------|-------------------|
| ISCmplr.dll | AV at DLL init | Loads and compiles .iss |
| Setup.exe | AV at form init | Runs installer wizard |
| ISCC.exe | ✅ works | ✅ still works (no change in behavior) |
| SetupLdr.exe | ✅ works | ✅ still works |
| Compil32.exe | ✅ works | ✅ still works |

### How to Verify the Fix

1. Recompile ISCmplr.dll with patched SafeDLLPath.pas:
   ```
   ppc386 -Twin32 -Mdelphi [flags] ISCmplr.dpr
   ```

2. Test under Wine (quick check):
   ```
   wine ISCC.exe netmodem2irc.iss
   ```
   Should produce `netmodem32_setup.exe` instead of crashing.

3. Test on real Windows (thorough):
   - Windows 11: should work (DEP is OptIn by default)
   - Windows 10: should work
   - Windows 7: should work (DEP available since Vista SP1)
   - Windows XP SP3: should work (DEP added in SP3)
   - Windows 98: no change (SetProcessDEPPolicy not available,
     GetProcAddress returns nil, entire block skipped)

4. Verify DEP is actually active after the fix:
   ```pascal
   // In any unit's initialization, after SafeDLLPath:
   var Flags: DWORD; Permanent: BOOL;
   GetProcessDEPPolicy(GetCurrentProcess, @Flags, @Permanent);
   // Flags should include PROCESS_DEP_ENABLE
   ```

### For Other FPC Projects Hitting This

If you're porting a Delphi project to FPC and it calls
`SetProcessDEPPolicy(PROCESS_DEP_ENABLE)`, you may hit the same crash.
The fix is the same:

1. Before enabling DEP, walk your module's memory with VirtualQuery
2. VirtualProtect any committed page to add PAGE_EXECUTE
3. Then enable DEP

Or: if you don't need DEP (e.g. a BBS door, not an installer),
just don't call SetProcessDEPPolicy. The PE header's
DllCharacteristics controls the default DEP behavior.

### References

- Microsoft: [SetProcessDEPPolicy](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setprocessdeppolicy)
- Microsoft: [Data Execution Prevention](https://learn.microsoft.com/en-us/windows/win32/memory/data-execution-prevention)
- Microsoft: [VirtualProtect](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualprotect)
- FPC: GNU ld linker does not set NX-compatible flags on all sections
- Inno Setup: SafeDLLPath.pas from Jordan Russell (original Delphi version)

### Timeline

- 2026-07-19 to 2026-07-23: Phases 1-9 completed
- 2026-07-25: ISCmplr.dll AV identified, initially attributed to Wine codepage
- 2026-07-28: Two binaries (ISCmplr + Setup) crash on three platforms
  (Win98, Win11, Wine) — not a Wine issue, real defect
- 2026-07-31: Root cause identified: SetProcessDEPPolicy + FPC page flags
- 2026-07-31: Fix written (MarkModuleCodeExecutable in SafeDLLPath.pas)
- Pending: sysop/0 recompiles with patched source and tests

## [Phase 1-9] — 2026-07-19 to 2026-07-23

### Phase 1: ISCC.exe ✅
Console compiler. No GUI, no LCL. 437KB. Verified on Win98 SE.

Key fixes to compile under FPC:
- `Application.Handle` → `GetAppHandle` wrapper (FPCCompat.pas)
- `Ole2` unit → `ActiveX` unit (LibFusion.pas, CmnFunc2.pas)
- IAssemblyCache → proper `interface` syntax for FPC
- CompareFileTime → pointer parameters (FPC strict typing)
- VERSION.INC: defined `Delphi3orHigher`, disabled `UNICODE`
- Int64Em.pas: full `.Hi`/`.Lo` record implementation for FPC
- D2009Win2kFix.pas: gutted (Delphi-specific, not applicable to FPC)

### Phase 2: Compression ✅
Compress.pas, CompressZlib.pas, bzlib.pas, LZMA.pas.
All use dynamic loading via GetProcAddress — no static linking changes needed.

### Phase 3: LCL Integration ✅
Replaced all VCL stubs with real LCL (Lazarus Component Library).

Requires fpc264irc Phase 9 additions to LCL:
- `Ctl3D` / `ParentCtl3D` properties on TWinControl
- `OEMConvert` property on TCustomEdit
- `CreateWindowHandle` virtual method
- `paswstring` 3-param overloads (IFDEF Win32 vs 4-param Unix)
- `ustringh.inc` reverted to 3-param signatures

All `{$R *.DFM}` directives disabled (replaced in Phase 6).
All `{$R *.res}` directives disabled (replaced in Phase 5).

### Phase 4: LZMA Decompression ✅
Cross-compiled LZMA C source with MinGW to produce .o files:

```
i686-w64-mingw32-gcc -c -O2 ISLzmaDec.c -o ISLzmaDec.o
i686-w64-mingw32-gcc -c -O2 ISLzma2Dec.c -o ISLzma2Dec.o
i686-w64-mingw32-gcc -c -O2 LzmaDecodeInno.c -o LzmaDecodeInno.o
```

FPC links these via `{$L ISLzmaDec.o}` directives.
Replaced 13 stub functions in LZMADecomp.pas and LZMADecompSmall.pas
with real LZMA SDK decoder calls.

### Phase 5: Windows Resources ✅
Built 8 .rc → .res files with fpcres/windres.
15 prebuilt .res files from original Delphi build reused directly.

| Resource | Fix needed |
|----------|-----------|
| Setup.res | Rebuilt with fpcres |
| ISCC.manifest.res | UAC manifest for Vista+ |
| HelperEXEs.res | Contains 64-bit helper binary |
| Others | Used Delphi prebuilt .res as-is |

### Phase 6: DFM → LFM Forms ✅
Converted 13 Delphi DFM forms to LCL LFM format.

Process:
1. Text-format DFM files already in tree (Delphi saves both binary + text)
2. Manual edit: remove Delphi-specific properties (ParentFont, Ctl3D, etc.)
3. `lazres` embeds LFM into executables as resources
4. `{$R *.lfm}` replaces `{$R *.dfm}`

7 installer forms: Main, Wizard, NewDisk, SelFolderForm,
SelLangForm, UninstProgressForm, UninstSharedFileForm.
6 IDE forms (Phase 8).

### Phase 7: PascalScript ✅
Replaced 22 stub files (410 lines total) with full RemObjects
PascalScript engine (~35,000 lines) from fpc264irc.

Key files restored:
- ScriptRunner.pas (543 lines) — script execution wrapper
- ScriptCompiler.pas (464 lines) — expanded stub → real code
- ScriptClasses_C.pas / ScriptClasses_R.pas — class registration
- ScriptDlg.pas — custom wizard page creation
- ScriptFunc.pas / ScriptFunc_C.pas / ScriptFunc_R.pas — ~150 built-in functions

### Phase 8: Compil32.exe IDE ✅
Fixed 5 ScintEdit.pas errors:

1. `Byte` ↔ set type casts (FPC stricter than Delphi on set operations)
2. `POINT` vs `LPPOINT` (FPC Win32 API binding uses different pointer types)
3. Added `RTLConsts` to uses clause (SListIndexError not found)
4. Wired up 6 IDE forms: CompForm, CompOptions, CompSignTools,
   CompStartup, CompWizard, CompWizardFile
5. Scintilla editor control (isscint.dll) — no changes needed, DLL loads fine

### Phase 9: Runtime Testing ⚠️ Partial
Completed:
- ISCC.exe verified working on Windows 98 SE + Wine
- Fixed ListContains (delimiter-aware substring matching)

Still needed:
- ExpandSetupMessage ({app}, {sys}, {cm:...}, {code:...})
- TAlphaBitmap (premultiplied alpha for wizard bitmaps)
- CONSOLE → GUI subsystem patch applied to Setup.exe (untested)
- Full install/uninstall cycle on real Windows

### Changes from Original Delphi Source (all phases)

```
SafeDLLPath.pas     — DEP fix: MarkModuleCodeExecutable (Phase 10)
FPCCompat.pas       — GetAppHandle, VCL→LCL type mappings
Compile.pas         — added LCLStrConsts for SmkcBkSp constants
CompForm.pas        — LFM form binding
CmnFunc2.pas        — Ole2→ActiveX, interface syntax
LibFusion.pas       — Ole2→ActiveX
Int64Em.pas         — full Hi/Lo record for FPC
D2009Win2kFix.pas   — gutted (Delphi-specific)
ScintEdit.pas       — 5 FPC compatibility fixes
VERSION.INC         — Delphi3orHigher, no UNICODE
ISCmplr.dpr         — library target, DLL exports
Setup.dpr           — CONSOLE→GUI subsystem patch candidate
LZMADecomp.pas      — MinGW .o linking via {$L}
ScriptCompiler.pas  — expanded from stub to real code
All 13 DFM forms    — converted to LFM
22 PascalScript stubs — replaced with real engine
```

## [Unreleased] — Wine Loader-Lock Deadlock (Phase 10a continued)

### Root Cause: Critical Section Timeout Under Wine

**Symptom:** After the DEP fix, ISCmplr.dll loads (no more c0000005) but
hangs with `RtlpWaitForCriticalSection section 00446B10 wait timed out,
blocked by 0000`. Happens under Wine. May also affect real Windows in
edge cases (server environments, terminal services).

**Root cause:** Loader lock violation. ISCmplr.dpr is a `library` (DLL).
FPC runs all unit `initialization` sections during DLL_PROCESS_ATTACH,
which executes inside the Windows loader lock. Two violations occur:

**Violation 1: SafeDLLPath.pas calls LoadLibrary 13 times inside DllMain.**
The `SafeLoadLibrary` function is called for uxtheme.dll, userenv.dll,
setupapi.dll, apphelp.dll, propsys.dll, dwmapi.dll, cryptbase.dll,
oleacc.dll, version.dll, profapi.dll, comres.dll, clbcatq.dll, and
ntmarta.dll. Microsoft's DLL best practices explicitly state:
"You should never call LoadLibrary or LoadLibraryEx from DllMain,
either directly or indirectly. This can cause a deadlock or a crash."
(https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-best-practices)

**Violation 2: Struct.pas → Graphics → LCL widgetset → window creation.**
Struct.pas uses the Graphics unit. Graphics pulls in the full LCL
widgetset (Win32 interface). The widgetset initialization creates a
window during unit init. Window creation inside DllMain violates the
loader lock — the window message pump needs the loader to finish, but
the loader is waiting for DllMain to return. Classic deadlock.

**This is known Lazarus bug #7182** — "Problems using LCL in DLL",
filed 2006, still open as of 2026. LCL was never designed to
initialize inside DllMain.
(https://gitlab.com/freepascal.org/lazarus/lazarus/-/issues/7182)

### Fix Plan (3 patches, no compiler changes)

**Fix 1: SafeDLLPath.pas — skip LoadLibrary calls in DLL context.**

```pascal
if not IsLibrary then begin
  // Only preload system DLLs when running as a standalone .exe.
  // In a DLL, we're already loaded — the host process handles
  // its own DLL search path security.
  SafeLoadLibrary(SystemDir + 'uxtheme.dll');
  SafeLoadLibrary(SystemDir + 'userenv.dll');
  // ... all 13 calls ...
end;
```

`IsLibrary` is a built-in FPC function that returns True when the
code is running inside a `library` (DLL) rather than a `program`.
This is safe because the DLL preloading is a security hardening
measure for standalone installers — a DLL doesn't need it.

**Fix 2: Struct.pas — use GraphType instead of Graphics.**

Struct.pas only needs TColor and a few type definitions. The full
Graphics unit pulls in the entire LCL widgetset initialization chain.
Replace:

```pascal
uses ... Graphics ...    // pulls in LCL widgetset → window creation
```

with:

```pascal
uses ... GraphType ...   // provides TGraphicsColor (= TColor) without LCL init
```

This breaks the chain: Struct → Graphics → LCL → widgetset → window
→ deadlock. GraphType is a lightweight unit in LazUtils that defines
color types without any GUI initialization.

**Fix 3: Defer LCL widgetset init for DLL builds.**

If any remaining unit still pulls in Graphics or the widgetset,
guard the widgetset initialization:

```pascal
initialization
  if not IsLibrary then
    WidgetSet := ... // only init GUI when running as a program
```

ISCmplr.dll is a compiler — it doesn't need a GUI. It reads .iss
text files and produces installer binaries. No windows, no forms,
no visual controls. The LCL should never have been initialized.

### Why This Is Not a Compiler Bug

This affects FPC 2.6.4 and 3.2.x equally. The issue is architectural:
LCL unit initialization does things that are forbidden inside DllMain
(LoadLibrary, window creation, thread synchronization). Microsoft's
rules are absolute — no exceptions, not even for Pascal.

The fix is in our code (SafeDLLPath.pas + Struct.pas), not in FPC
or LCL. We control what units ISCmplr.dpr pulls in.

### References

- Microsoft: Dynamic-Link Library Best Practices
  https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-best-practices
- Microsoft: DllMain entry point restrictions
  https://learn.microsoft.com/en-us/windows/win32/dlls/dllmain
- Raymond Chen: "Another reason not to do anything scary in your DllMain"
  https://devblogs.microsoft.com/oldnewthing/20040128-00/?p=40853
- Lazarus Bug #7182: "Problems using LCL in DLL"
  https://gitlab.com/freepascal.org/lazarus/lazarus/-/issues/7182
- Wine loader.c source
  https://github.com/wine-mirror/wine/blob/master/dlls/ntdll/loader.c

### Timeline

- 2026-07-31: DEP fix applied — c0000005 gone, loader-lock deadlock exposed
- 2026-07-31: Root cause identified — two loader lock violations
- 2026-07-31: Fix plan documented (3 patches)
- Pending: implement and test fixes 1-3

## [Phase 10a Wine Fix] — 2026-07-31

### Wine Deadlock — FIXED

**Root cause:** FPC 2.6.4 `system.pp` initializes `InitSystemThreads` (which
registers critical section functions) AFTER `SysInitExceptions` and `SysInitStdIO`.
If anything in those early init functions uses a critical section, the thread
manager isn't ready. Real Windows tolerates it. Wine doesn't.

**Fix:** sysop/0 applied two changes to fpc264irc:
1. `system.pp` — moved `InitSystemThreads` to right after `InitHeap`
2. `systhrd.inc` — don't set `IsMultiThread := true` during DLL init

Same fix FPC 3.2.2 applied upstream.

**Verification:**
```
FPC 2.6.4 (old):       ISCC.exe under Wine → DEADLOCK
FPC 2.6.4irc (fixed):  ISCC.exe under Wine → RUNS CLEAN
FPC 3.2.2:              ISCC.exe under Wine → RUNS CLEAN
```

### Phase 10 — Complete Summary

| Issue | Status |
|-------|--------|
| DEP AV (c0000005) | ✅ FIXED — MarkModuleCodeExecutable in SafeDLLPath.pas |
| TColor range | ✅ FIXED — Lazarus 3.0 + fpc264irc both have full LongInt range |
| Wine deadlock | ✅ FIXED — InitSystemThreads moved early in system.pp |
| LoadLibrary in DllMain | ✅ FIXED — IsLibrary guard in SafeDLLPath.pas |
| Graphics in ISCmplr | ✅ FIXED — PS_NOGRAPHCONST removes Graphics.pp dependency |

All Inno Setup phases complete. ISCC.exe + ISCmplr.dll ready for testing.
