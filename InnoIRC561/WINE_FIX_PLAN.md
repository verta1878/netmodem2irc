# Wine Loader-Lock Fix Plan — ISCmplr.dll Critical Section Deadlock

## Status
Phase 10a DEP fix: ✅ DONE (c0000005 gone)
Phase 10a Wine hang: 🔧 PLAN WRITTEN, 3 patches needed

## Root Cause
ISCmplr.dll hangs on critical section under Wine (and possibly real Windows).
FPC runs all unit `initialization` sections during DLL_PROCESS_ATTACH — inside
the Windows loader lock. Two violations:

1. SafeDLLPath.pas calls LoadLibrary 13 times (system DLL preloads)
2. Struct.pas → Graphics → LCL widgetset → creates a window

Both are forbidden inside DllMain per Microsoft:
"You cannot call any function that directly or indirectly tries to acquire
the loader lock. Otherwise, you will introduce the possibility that your
application deadlocks or crashes."

Known Lazarus bug: GitLab #7182 "Problems using LCL in DLL" (filed 2006, still open)

## Three Fixes (in order)

### Fix 1: SafeDLLPath.pas — skip LoadLibrary calls in DLL context
```pascal
if not IsLibrary then begin
  // 13 SafeLoadLibrary calls for DLL preloading
  // Only needed for standalone .exe protection
  SafeLoadLibrary(SystemDir + 'uxtheme.dll');
  SafeLoadLibrary(SystemDir + 'userenv.dll');
  // ... etc
end;
```

### Fix 2: Struct.pas — use GraphType instead of Graphics
Struct.pas only needs TColor. GraphType provides TGraphicsColor without
pulling in the full LCL widgetset initialization chain.
```pascal
// BEFORE (pulls in widgetset, creates window):
uses Graphics;

// AFTER (types only, no widgetset init):
uses GraphType;
```
This breaks: Struct → Graphics → LCL → widgetset → window → deadlock

### Fix 3: Defer LCL widgetset init
If any unit still needs Graphics after Fix 2, wrap widgetset init:
```pascal
if not IsLibrary then
  Application.Initialize;  // creates widgetset, windows
```
ISCmplr.dll is a compiler, not a GUI. It should never create windows.

## Not an FPC/compiler bug
This affects FPC 2.6.4 and 3.2.x equally. The fix is in our code
(SafeDLLPath.pas + Struct.pas), not in the compiler. No backport needed.

## Lazarus LCL Bug #7182
https://gitlab.com/freepascal.org/lazarus/lazarus/-/issues/7182
"Problems using LCL in DLL" — filed July 2006, still open.
LCL was never designed to initialize inside DllMain.
Our fix works around it without patching LCL itself.

## Test Matrix
| Platform | Expected |
|----------|----------|
| Wine | ISCC loads ISCmplr.dll, compiles .iss, no hang |
| Windows 11 | Same |
| Windows 10 | Same |
| Windows 7 | Same |
| Windows XP SP3 | Same |
| Windows 98 | SafeDLLPath skips all (GetProcAddress returns nil) |
