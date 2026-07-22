20260722: BUG-029 patched — fpc_ansistr_setlength sub eax,8 → sub eax,12

Root cause found and patched in system.o:
  fpc_ansistr_setlength (section 268, offset +0x10a)
  sub eax, 8 → sub eax, 12 (file offset 0x1A92C)
  
The function passes (string_ptr - 8) to FreeMem instead of
(string_ptr - 12). TAnsiRec header is 12 bytes (CodePage 2 +
ElementSize 2 + Ref 4 + Len 4) but the code only backed up 8,
missing CodePage + ElementSize. Every SetLength on an AnsiString
freed at the wrong address → heap corruption → eventual AV.

fpc_ansistr_decr_ref was correct (uses sub edx,8 for refcount
access, sub eax,12 for FreeMem). Only fpc_ansistr_setlength
had the bug. Confirmed by scanning all FREEMEM relocations.

All 5 Inno targets recompiled against patched system.o.
Binaries included — test on Win98 and Win11.

Binaries (patched system.o, Win98 PE headers):
  ISCC.exe      436KB  CONSOLE
  ISCmplr.dll   1.9MB  compiler DLL + PascalScript
  Setup.exe     3.7MB  GUI — should no longer AV
  SetupLdr.exe  323KB  GUI
  Compil32.exe  3.3MB  GUI + isscint.dll
