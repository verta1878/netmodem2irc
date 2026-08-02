# FPC 2.6.4 Wine Deadlock — Root Cause and Fix

## The Bug
FPC 2.6.4-compiled Win32 executables deadlock under Wine 9.0.
Critical section at address inside the .exe hangs with
`blocked by 0000` (no owning thread).

## Root Cause
`system.pp` initialization order. FPC 2.6.4 initializes the
thread manager (which sets up critical section functions)
AFTER other init code that may use critical sections:

```
FPC 2.6.4 (src/rtl/win32/system.pp):
  InitHeap;                 ← line 666
  SysInitExceptions;        ← line 667
  fpc_cpucodeinit;          ← line 669
  SysInitStdIO;             ← line 670   ← may use CS
  setup_arguments;          ← line 672
  InitSystemThreads;        ← line 677   ← CS functions registered HERE
```

FPC 3.2.2 fixed this by moving InitSystemThreads early:

```
FPC 3.2.2 (rtl/win32/system.pp):
  InitHeap;                 ← line 621
  InitSystemThreads;        ← line 622   ← CS functions registered FIRST
  SysInitExceptions;        ← line 624
  fpc_cpucodeinit;          ← line 626
  SysInitStdIO;             ← line 629   ← safe, CS is ready
```

On real Windows: works by accident because Windows critical section
APIs are always available regardless of FPC's thread manager state.

On Wine: the uninitialized thread manager causes deadlock because
Wine's CS implementation is stricter about initialization order.

## Fix for fpc264irc
In `src/rtl/win32/system.pp`, move `InitSystemThreads` to right
after `InitHeap`:

```pascal
  { Setup heap }
  InitHeap;
  { threading — must be before anything that uses critical sections }
  InitSystemThreads;         ← MOVED HERE (was after setup_arguments)
  SysInitExceptions;
  { setup fastmove stuff }
  fpc_cpucodeinit;
  SysInitStdIO;
  { Arguments }
  setup_arguments;
```

Then rebuild ppc386 + all RTL PPUs.

## Verification
```
FPC 2.6.4 ISCC.exe under Wine: DEADLOCK
FPC 3.2.2 ISCC.exe under Wine: WORKS
```

Same source code, different compiler. The only difference is
the init order in system.pp.

## References
- FPC 3.2.2 src/rtl/win32/system.pp line 621-631
- FPC 2.6.4 src/rtl/win32/system.pp line 666-685
- Wine 9.0 ntdll/loader.c
