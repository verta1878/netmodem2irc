20260722: BUG-029 audit — only i386-win32 affected, other targets clean

Full audit of fpc_ansistr_setlength across all four targets:

  i386-win32:   BUG at 0x1A92C — patched (08 → 0C) ✅
  i386-linux:   ALL sub eax,12 — not buggy ✅
  i386-freebsd: ALL sub eax,12 — not buggy ✅
  i386-go32v2:  ALL sub eax,12 — not buggy ✅

The author's offsets for other targets were false positives:
  0x1037C (linux)    → lands in fpc_dynarray_copy, not setlength
  0xFAE8  (freebsd)  → lands in fpc_dynarray_copy, not setlength
  0xEE88  (go32v2)   → lands in fpc_dynarray_copy, not setlength

If those offsets were patched, they should be REVERTED — they're
legitimate sub eax,8 instructions in dynarray code, not string code.

Binaries compiled against patched i386-win32 system.o.
Win98 PE headers, GUI subsystem, DEP/ASLR/TS off.
