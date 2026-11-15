# InnoIRC561 — findings from a Wine test build (byte, 2026-11-14, updated 2026-11-15)

For wrench. Source tested: `netmodem2irc/InnoIRC561/src/issrc-is-5_6_1` (GitHub HEAD `2562cd6`; the copy on the
share in `bbses/netmodem2irc/InnoIRC561` is identical). Built with fpc264irc GitHub `77210616` (2026-11-15: `c78cd59c`, which has the fixes for bugs 2 and 5) (`bin/ppc386`,
`bin/units/i386-win32`, `bin/lazarus/units/i386-win32`), tested under Wine 9 on Linux. Not run on real Windows.

## Summary

| # | What | Where | Status |
|---|---|---|---|
| 1 | Setup.exe crash at start of decompression (the "AV at form init") | `Projects/LZMADecomp.pas` | **fixed** (this change, 2026-11-15) |
| 2 | Empty header strings come back as the previous string → "app constant before it was initialized" | **fpc264irc RTL**, `src/rtl/i386/i386.inc` | **fixed in fpc264irc** `c78cd59c` (BUG-046) — nothing to do in InnoIRC |
| 3 | Win98: 5.6.1 refuses Win9x (compiler and Setup) | `Compile.pas`, `Main.pas` | **version checks fixed** (this change); real Win98 test still needed |
| 4 | Build on Linux: file name case, `-Fu` order, `fpcres` | build notes | worked around |
| 5 | LCL win32 "Failed to create win32 control, error 1411: Class does not exist" (GLOBALS G-017) | **fpc264irc LCL**, commit `3cc25923` "U-1 Win9x ANSI" | **fixed in fpc264irc** `c78cd59c` (BUG-047) — nothing to do in InnoIRC |
| 6 | After "Installation process succeeded" the silent setup does not exit | `Projects/Main.pas` `TerminateApp` | **fixed** (this change, 2026-11-15) |
| — | The working `netmodem32_setup.exe` | `installer/Output/` | built with **stock Delphi** Inno 5.6.1, not InnoIRC |

Changes in this tree (byte, 2026-11-15): **3 files** — `Projects/LZMADecomp.pas` (bug 1), `Projects/Main.pas` (bugs 6 and 3),
`Projects/Compile.pas` (bug 3). Against GitHub `2562cd6` only these three source files changed. The Delphi
build is unchanged (all changes are `{$IFDEF FPC}` / `{$IFNDEF FPC}`, except bug 1, which is a plain fix).

What works with today's fpc264irc: all 5 targets build (ISCC, ISCmplr, SetupLdr, Setup, Compil32). **Your Phase 10
DEP fix works**: ISCmplr.dll loads, ISCC compiles a script into a setup.exe (Wine). SetupLdr starts and unpacks Setup.

## The working installer was stock Inno

`installer/Output/netmodem32_setup.exe` installs fine under Wine ("Installation process succeeded"). Its log says
`Inno Setup version 5.6.1 (a)` and its loader is 59,392 bytes (`/SL5="$...,1169211,59392,..."`) — the size of the
**Delphi** SetupLdr; the FPC SetupLdr is ~337 KB. The setup.exe that worked was made by the original Inno 5.6.1,
which does not run on Win98. The FPC engine in `InnoIRC561/out/Setup.e32` has bug 1 (same crash, same address).

## BUG 1 — Setup.exe crash: LZMADecomp.pas calling convention / parameter passing

Symptom: Setup (the `.tmp` SetupLdr starts) faults right after start: DEP execute fault at `0x45890CEC`
(`info[0]=8`), edi = address of `LZMAAllocFunc`. Same with `out/Setup.e32` and with a fresh build.

Cause (two mismatches with the MinGW C objects `ISLzmaDec.o` / `ISLzma2Dec.o`):
1. The externals take `const alloc: TLZMAISzAlloc`. For `cdecl`, FPC passes that record **by value** (copied on the
   stack). C expects `ISzAlloc *` — it takes the first field (address of `LZMAAllocFunc`) as the record pointer,
   reads code bytes as the function pointer and jumps there (`0x45890CEC` = bytes `EC 0C 89 45` of the prologue).
2. `Alloc` / `Free` in the record have no calling convention → `register` in `{$mode delphi}`; C calls them `cdecl`.

Fix (tested — Setup now unpacks, opens its log, runs InitializeSetup):
```pascal
  TLZMAISzAlloc = record
    Alloc: function(p: PLZMAISzAlloc; size: Cardinal): Pointer; cdecl;
    Free: procedure(p: PLZMAISzAlloc; address: Pointer); cdecl;
  end;
{ the 4 externals IS_LzmaDec_Init, LzmaDec_Free, IS_Lzma2Dec_Init, IS_Lzma2Dec_Free:
    const alloc: TLZMAISzAlloc   ->   var alloc: TLZMAISzAlloc }
function LZMAAllocFunc(p: PLZMAISzAlloc; size: Cardinal): Pointer; cdecl;
procedure LZMAFreeFunc(p: PLZMAISzAlloc; address: Pointer); cdecl;
```
Worth a look for the same pattern: any other Pascal record of callbacks handed to C (zlib / bzip2 alloc records,
`LZMADecompSmall`), and the compressor side in ISCmplr / islzma.

## BUG 2 — "expand the app constant before it was initialized": fpc264irc RTL bug (i386 only)

Symptom: silent install stops — log: `Internal error: An attempt was made to expand the "app" constant before it was
initialized.` Backtrace: `ExpandIndividualConst <- ExpandConst <- InitializeSetup (ExpandedAppMutex :=
ExpandConst(SetupHeader.AppMutex))`. Dump of `SetupHeader` after `SECompressedBlockRead`: **every empty string holds
the previous string** (AppVerName = AppName, AppCopyright = AppName ..., AppMutex = `{app}` copied from
UninstallFilesDir). Your code in `SetupEnt.pas` is correct.

Root cause — fpc264irc, not InnoIRC: `SetLength(S, 0)` does not empty a string that is shared.
```pascal
s := 'abc' + IntToStr(1);  t := s;  SetLength(s, 0);  writeln(Length(s));   { prints 4, must be 0 }
```
- i386-linux: 4 · i386-win32 (Wine): 4 · x86_64-linux: 0 (correct).
- Checked against the official compilers (same 3-line program, no Inno code):

  | Compiler | Target | Result |
  |---|---|---|
  | official FPC 2.6.4 (freepascal.org, i386-linux) | i386-linux | 0 - correct |
  | official FPC 3.2.2 (freepascal.org, i386-linux) | i386-linux | 0 - correct |
  | official FPC 3.2.2 (Debian `fpc`) | x86_64-linux | 0 - correct |
  | fpc264irc `bin/ppc386` | i386-linux, i386-win32 | **4 - wrong** |
  | fpc264irc `bin/ppcx64` | x86_64-linux | 0 - correct |

  So the bug is only in fpc264irc's i386 RTL (newer `astrings.inc` + old assembler decr_ref), not in Inno and not
  in upstream FPC.
- `src/rtl/inc/astrings.inc` is the newer version: `SetLength(S,0)` just calls `fpc_ansistr_decr_ref(S)` and relies
  on decr_ref setting `S := nil` (the Pascal decr_ref does `s:=nil` first).
- `src/rtl/i386/i386.inc` has its own assembler `fpc_AnsiStr_Decr_Ref` (the BUG-029 one) that sets `S := nil` **only
  when the count reaches 0** (and not for constant strings). When the string is shared, the count is decremented but
  `S` still points at it — wrong length *and* a reference that is no longer counted (can become use-after-free).
- Affects every i386 target of fpc264irc (win32, linux, go32v2, os2, freebsd, darwin), not only InnoIRC.

Fix belongs in fpc264irc: the assembler decr_ref must clear `S` on every path (as the Pascal version), then the i386
`system` units are rebuilt. Fixed in fpc264irc `c78cd59c` (BUG-046): all 6 i386 targets rebuilt with their kits - only `system` changes
(same checksums); the 3-line test prints 0 on i386-linux, i386-win32 (Wine) and go32v2 (DOSBox). In SECompressedBlockRead a workaround
would be `S := '';` before `SetLength`, but the RTL fix is the real one.

## Result with bugs 1, 2 and 5 fixed (byte's sandbox, Wine)

InnoIRC built with fpc264irc + the two fpc264irc fixes below: ISCC compiles the test script, **setup.exe installs**
("Installation process succeeded": file, Start-menu icon, uninstall key) and **unins000.exe uninstalls** (exit 0).
With bug 6 fixed too (2026-11-15, fpc264irc `c78cd59c`): `/VERYSILENT` x3 and `/SILENT` install and **exit by
themselves** (exit code 0, about 3 s, log ends with `Deinitializing Setup.`); the uninstaller removes the folder; no
process left. Not run on real Windows or Win98.

Not a bug (withdrawn): "error 1400 Invalid window handle" seen on single runs (Setup got `/SL5="$0,..."` - SetupLdr's
`CreateWindowEx('STATIC')` returned 0). Happens only when Wine has no X display (first run before Wine's desktop was up,
and once when byte's Xvfb had died - then no program can create a window). With a working display: every run fine.
A test-machine effect, not InnoIRC.

## BUG 5 — LCL win32 GUI under NT/Wine: fpc264irc's U-1 change (not InnoIRC)

Symptom: every LCL win32 program, InnoIRC's Setup included, stops with `Failed to create win32 control, error:
1411 : Class does not exist.` (fpc264irc GLOBALS G-017). Wine `+class` trace: the LCL registers its main window
class `"Window"` as **`"W"`** and `"HintWindow"` as `"H"`.

Cause: fpc264irc commit `3cc25923` (2026-08-13, "U-1 Win9x ANSI complete") added `win32compat.pas` and replaced 46
`Windows.xxxW` calls in the LCL win32 widgetset with `Win*` wrappers. All 46 are inside
`if UnicodeEnabledOS then` (the NT-only branch) - and because fpc264irc builds without `UNICODE`, the wrappers are
the **A** functions: a `WNDCLASSW` goes to `RegisterClassA` (reads "W" and stops at the 0 byte), then
`DefWindowProcA` for wide windows (stack overflow, run-time error 202), `SendMessage`/`GetWindowText` A on wide
buffers, and so on. On Win9x `UnicodeEnabledOS` is false, so those branches never run there: the change did
nothing for Win98 and broke NT/2000/XP ... Windows 11.

Fix (fpc264irc `c78cd59c`, BUG-047): 12 files back to the original upstream Lazarus code (`A` on 9x, `W` on NT,
chosen at run time by `UnicodeEnabledOS`). The W functions BUG-040 kept out of the import table are loaded at run
time by `win32compat.pas` (`DynRegisterClassW` ...), so the import table is the same as before. Under Wine: a plain LCL win32 program (form, button,
timer) runs with the Lazarus set and with the flat `bin/units/i386-win32/lcl`; InnoIRC Setup gets past it.
**Win98 note:** the 9x (ANSI) branches are unchanged; the W functions in the NT branches were already imported
before U-1 (and still are elsewhere: CreateWindowW, TextOutW, GetTextExtentPoint32W) - not tested on real Win98.

## BUG 6 — silent setup does not exit: LCL ignores WM_QUIT

Symptom: after `Need to restart Windows? No` the setup `.tmp` stays running (no `Deinitializing Setup` line, the
caller waits forever); the uninstaller exits normally.

Cause: `TerminateApp` in `Main.pas` ends Setup with `PostMessage(0, WM_QUIT, 0, 0)` - in Delphi the VCL message loop
sees `WM_QUIT` and ends `Application.Run`. The LCL win32 loop (`TWin32WidgetSet.AppProcessMessages`) only re-posts a
`WM_QUIT` (`PostQuitMessage`) and never sets `Application.Terminated`, so `Application.Run` never returns. (The
uninstaller has its own message loop that handles `WM_QUIT` itself - that is why it exits.)

Fix (tested - `/VERYSILENT` and `/SILENT` end by themselves, exit code 0):
```pascal
procedure TerminateApp;
begin
  { ... original comment ... }
{$IFDEF FPC}
  { LCL: Application.Run does not end on WM_QUIT (TWin32WidgetSet.AppProcessMessages only
    re-posts it), so a posted WM_QUIT left Setup running after "Installation process
    succeeded" (InnoIRC BUG 6). Application.Terminate sets Terminated and posts no WM_QUIT,
    so the shell32 DDE problem above does not apply. }
  Application.Terminate;
{$ELSE}
  PostMessage(0, WM_QUIT, 0, 0);
{$ENDIF}
end;
```
The Delphi build is unchanged. The other `WM_QUIT` users (`Uninstall.pas` own loop, `DebugClient.pas`) need nothing.

## BUG 3 — Win98 refused by 5.6.1 itself

Two checks (Inno 5.5 dropped Win9x):
- ISCC/ISCmplr (`Compile.pas`, `ssMinVersion`): any Win9x part in `MinVersion` stops the compile with `Minimum Windows
  version specified by MinVersion must be 0. (Windows 95/98/Me are no longer supported.)`
- Setup (`Main.pas`, `InstallOnThisVersion`): on a non-NT system `MinVer := 0` -> "not on this platform", whatever the
  script says -> `This program does not support the version of Windows your computer is running.`

Fix (tested): both back to the Inno 5.4 behaviour, FPC build only:
```pascal
{ Compile.pas, ssMinVersion }
{$IFNDEF FPC}
        if SetupHeader.MinVersion.WinVersion <> 0 then
          AbortCompileOnLine(SCompilerMinVersionWinMustBeZero);
{$ENDIF}

{ Main.pas, InstallOnThisVersion, the non-NT branch }
{$IFDEF FPC}
    MinVer := MinVersion.WinVersion;
    OnlyBelowVer := OnlyBelowVersion.WinVersion;
{$ELSE}
    MinVer := 0;
    OnlyBelowVer := 0;
{$ENDIF}
```
Win98 is **opt-in per script**: the default stays `MinVersion=0,5.0` (not on Win9x). A setup for Win98 + NT says
`MinVersion=4.1,5.0` (4.1 = Windows 98, 5.0 = Windows 2000). The same applies to per-entry `MinVersion` /
`OnlyBelowVersion` in [Files], [Icons] ... (same function). `netmodem32.iss` would need `MinVersion=4.1,5.0`.

Tested under Wine (normal = NT 10.0, and Wine set to Windows 98 = 4.10.2222, "NT platform: No"):

| Wine | Script | Result |
|---|---|---|
| normal | `MinVersion=5.0` | installs + uninstalls |
| normal | `MinVersion=4.1,5.0` | installs + uninstalls |
| Win98 mode | `MinVersion=5.0` | refused ("does not support the version of Windows") - correct |
| Win98 mode | `MinVersion=4.1,5.0` | installs + uninstalls, Setup's Win9x code paths run |

**Not proven yet - needs a real Win98:** Wine's Win98 mode only changes the version Setup sees; the functions are
still Wine's. On real Win98 every imported function must exist in Win98's DLLs or the program does not start.
- kernel32: all imports of Setup, SetupLdr, ISCC, ISCmplr, Compil32 are in Geoff Chappell's KERNEL32 export lists
  for Windows 95/98 (versions 4.0 / 4.10). Caveat: his base list (NT 3.51) does not mark the few 3.51 functions
  Windows 95 never had.
- user32, gdi32, advapi32, comctl32, comdlg32, shell32, ole32, oleaut32, version, mpr, msimg32: no public export
  list - to be checked against the DLLs of a real Win98 (`C:\WINDOWS\SYSTEM`), then run on Win98.
- PE headers (min OS 4.0, no DEP/ASLR flags) are right.

## Build notes (Linux host)

- **File name case**: the tree mixes `VERSION.INC` / `Version.inc`, `Int64Em` / `Int64em.pas`, `BidiCtrls.pas` ...
  Windows does not care; Linux FPC finds a file only as written, lower case or upper case. Lower-case links (or
  consistent names) needed.
- **`-Fu` order** (fpc264irc `toolkit/SEGMAP.TXT`): Lazarus folders first —
  `-Fu$L/lcl/win32 -Fu$L/lcl -Fu$L/lazutils -Fu$RTL`. With the README order Free Vision's `Menus` (main folder) and
  `AvgLvlTree` clash with the LCL ones; `ppc386` itself then dies on `Setup.dpr` with
  `EListError : List index exceeds bounds (265)` (a compiler bug of its own, but the order is the fix).
- **fpcres**: SetupLdr needs `fpcres` on PATH for the host (Linux: build `src/utils/fpcres` with `ppcx64 -Tlinux`).
- Stale `.ppu` in `Projects/` (from a build with `-FU.`) are found before a changed source is recompiled — delete
  them when switching `-FU`.
- Also with a separate `-FU` folder: after editing a unit, empty that folder before rebuilding - byte got a Setup.exe
  with the old `Main` once (the edit was not compiled in). A clean unit folder per build is safest.
- README "fpc264irc is an empty repository": out of date — the repo is back; `bin/units/i386-win32` +
  `bin/lazarus/units/i386-win32` build all 5 targets.

## Test kit used (byte's sandbox)

`ISCC.exe`, `ISCmplr.dll`, `Setup.exe` → `Setup.e32`, `SetupLdr.exe` → `SetupLdr.e32` + the helper DLLs, bitmaps and
`Default.isl` from `InnoIRC561/out`. Test script: one file, one icon, `Compression=lzma`, `MinVersion=5.0`;
`setup.exe /VERYSILENT /SUPPRESSMSGBOXES /LOG=...` under Wine + Xvfb.
