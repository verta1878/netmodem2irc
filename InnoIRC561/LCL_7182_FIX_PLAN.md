# LCL Bug #7182 — Fix Plan

## The Bug (20 years unfixed)
https://gitlab.com/freepascal.org/lazarus/lazarus/-/issues/7182

LCL cannot be used in a DLL because unit initialization sections run
during DllMain(DLL_PROCESS_ATTACH) inside the Windows loader lock.

Three violations of Microsoft's DllMain rules:

1. **Interfaces unit** calls `CreateWidgetset(TWin32WidgetSet)` in
   its initialization section. The widgetset constructor may call
   CreateWindow and LoadLibrary — both forbidden inside DllMain.

2. **Graphics.pp** creates a `TCriticalSection` in its initialization.
   InitCriticalSection is technically safe, but downstream memory
   allocation may require locks that conflict with the loader lock.

3. **Forms.pp** creates `TApplication` in its initialization.
   TApplication.Create may touch the message queue, which requires
   the loader to finish first.

## Why It's Never Been Fixed
- LCL was designed for standalone .exe, not DLLs
- Every LCL app starts with `uses Interfaces, Forms` — the init
  model assumes the process is fully loaded
- Changing it would break the convenience pattern
- Nobody has proposed a backward-compatible fix

## How energye/lcl (Go) Solved It
https://github.com/energye/lcl

They compile LCL as a separate shared library (libenergy.dll).
The Go program loads it via LoadLibrary AFTER process init completes.
No DllMain involvement. Widgetset init happens on explicit call.

## Fix Plan — Lazy Initialization

**Principle:** No code should ever deadlock. All init must be deferrable.
If code can't run safely in DllMain, defer to first use.

### Step 1: Guard Interfaces unit
```pascal
// lcl/interfaces/win32/interfaces.pp
initialization
  if not IsLibrary then
    CreateWidgetset(TWin32WidgetSet);
```

For DLL users, explicit init after DllMain returns:
```pascal
procedure InitWidgetSetIfNeeded;
begin
  if WidgetSet = nil then
    CreateWidgetset(TWin32WidgetSet);
end;
```

### Step 2: Guard Graphics.pp
```pascal
// lcl/graphics.pp
var UpdateLockInitialized: Boolean = False;

procedure EnsureGraphicsInit;
begin
  if not UpdateLockInitialized then begin
    UpdateLock := TCriticalSection.Create;
    UpdateLockInitialized := True;
    // ... rest of current init code
  end;
end;

initialization
  if not IsLibrary then
    EnsureGraphicsInit;
```

### Step 3: Guard Forms.pp
Same pattern — defer TApplication.Create to first use if IsLibrary.

### Step 4: New unit — LCLDeferredInit
```pascal
unit LCLDeferredInit;
interface
  procedure InitLCL;
implementation
uses Interfaces, Forms;

procedure InitLCL;
begin
  if WidgetSet = nil then
    CreateWidgetset(TWin32WidgetSet);
  Application.Initialize;
end;

// NO initialization section — that's the whole point
end.
```

DLL developers use `LCLDeferredInit` instead of `Interfaces`.
Call `InitLCL` after DllMain returns (e.g. from an exported function).

### Step 5: Graceful failure
If any LCL function is called before init in a DLL context:
- Don't deadlock
- Don't crash
- Raise: `ELCLNotInitialized: 'LCL not initialized. Call InitLCL
  or Application.Initialize before using LCL components in a DLL.'`

## Backward Compatibility

| Scenario | Before | After |
|----------|--------|-------|
| .exe uses Interfaces | ✅ works | ✅ still works (IsLibrary = False) |
| .dll uses Interfaces (Wine) | ❌ deadlock | ✅ deferred init |
| .dll uses Interfaces (Windows) | ⚠️ sometimes works | ✅ deferred init |
| .dll uses LCLDeferredInit | N/A | ✅ explicit init |
| .dll calls LCL before init | ❌ crash/deadlock | ✅ meaningful error |

## Affected Files

| File | Change |
|------|--------|
| lcl/interfaces/win32/interfaces.pp | Guard CreateWidgetset with IsLibrary |
| lcl/graphics.pp | Defer TCriticalSection to EnsureGraphicsInit |
| lcl/forms.pp | Defer TApplication.Create if IsLibrary |
| lcl/lcldeferred.pp (NEW) | Deferred init convenience unit |
| lcl/interfacebase.pp | Add WidgetSetInitialized check |

## Scope
~50 lines changed in existing LCL units.
1 new unit (~30 lines).
No breaking changes for .exe programs.
All changes gated behind `IsLibrary` — which is a standard FPC
System unit variable, always False for programs, True for libraries.

## References
- Lazarus GitLab #7182: https://gitlab.com/freepascal.org/lazarus/lazarus/-/issues/7182
- Microsoft DllMain best practices: https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-best-practices
- Raymond Chen (loader lock): https://devblogs.microsoft.com/oldnewthing/20040128-00/?p=40853
- energye/lcl (Go workaround): https://github.com/energye/lcl
- Wine loader.c: https://github.com/wine-mirror/wine/blob/master/dlls/ntdll/loader.c
