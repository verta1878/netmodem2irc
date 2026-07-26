# FOSSIL Fn 1Bh (GET_INFO) — wired to fill the struct via the buffer mechanism

## What was off
We HAD a correct FossilGetInfo() that fills the full TFossilInfo struct (StrSiz,
version 5.0, in/out buffer sizes+free, screen dims, baud), but the Fn 1Bh dispatch
arm did NOT call it — it only set CX + signature and deferred the real struct-fill
to a "separate shim call." Half-wired and inconsistent with how the other ES:DI
functions work.

## The fix (reuses the block-I/O Buf mechanism)
Fn 1Bh now fills the struct directly into the caller's buffer (ES:DI -> R.Buf),
respecting CX: copy min(CX, SizeOf(TFossilInfo)) and return AX = bytes transferred
(spec). Same Buf path added for Fn 18h/19h — one consistent mechanism for all
ES:DI functions. No buffer -> falls back to CX + signature in registers for callers
that only read registers.

## Verified (test_fossil_getinfo, 8/8) — boundary discipline
- big-enough buffer: full struct copied, AX = SizeOf, StrSiz/version/buffers correct.
- CX SMALLER than struct: copies only CX, AX = CX, and a guard byte past the buffer
  stays intact — NO OVERFLOW (the structural-sight catch for struct->buffer copies).
- no buffer: signature in AX, buffer size in CX.
Full suite after: 29 tests, 0 failures (FPC 2.6.4 + 3.2.2), no regression.
