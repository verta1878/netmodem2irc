# FOSSIL/COM audit — parked (resume here later)

Continuing the FOSSIL contract audit (the check that found the Fn 06h DTR bug).
Paused mid-audit. This note records what was found so far so it's not lost.

## Status: PARKED — one real finding recorded, not yet acted on.

## Finding to investigate when resumed
**Fn 18h (READ_BLOCK) and Fn 19h (WRITE_BLOCK) are NOT specifically implemented** —
they fall through to the `else` no-op arm in NM_Fossil's dispatch.

Why this matters: block read/write are the HIGH-THROUGHPUT FOSSIL functions. Many
doors don't move data byte-by-byte (Fn 01h/02h); they call Fn 18h/19h to transfer
whole buffers at once (file transfers, bulk output). A door that relies on block
I/O could be slow or non-functional if these are no-ops.

BUT — this needs honest verification before "fixing":
- Confirm against the FOSSIL spec (Raymond Gwinn X00) exactly what 18h/19h expect
  (ES:DI buffer pointer, CX count, return actual-transferred count).
- Check how ELECOM FOS_COM / mSyncFos handle block I/O (the reference oracle).
- Decide: on our NT/host model, block I/O maps to draining/filling the rings in
  bulk — but the ES:DI real-mode buffer pointer is a DOS-side concern (the i8086
  TSR wrapper territory), so part of this may belong in the real-mode shim, not the
  host dispatch. Don't fix blindly — figure out which layer owns it.

## Functions confirmed IMPLEMENTED (spec-checked)
INIT(04h), DEINIT(05h), TX_WAIT(01h)/TX_NOWAIT(0Bh), RX_WAIT(02h), PEEK(0Ch),
GET_STATUS(03h) [bits $01/$20/$40 = RDA/THRE/TSRE, spec-correct], SET_DTR(06h)
[FIXED this session — both directions], FLUSH_OUTPUT(08h), PURGE_OUTPUT(09h),
PURGE_INPUT(0Ah), GET_INFO(1Bh), SET_BAUD(00h).

## Functions no-op'd (recognized, in-range, return Handled=true)
Screen/cursor/console functions (11h-17h etc.) — correctly no-op'd since they're
console concerns, not comms; a real driver still owns them so doors don't fault.

## Also noted earlier (documented, not a bug)
Fn 02h RX_WAIT returns AL=0 for "no char" which collides with a valid 0x00 byte;
correct for the NT/event model (non-blocking) but a semantic difference from real
blocking FOSSIL. Left as-is, documented in netmodem2irc_fossil_dtr_fix.md.

## Resume point
Start by verifying Fn 18h/19h against the spec + ELECOM/mSyncFos reference, and
decide the host-vs-realmode-shim ownership question before implementing.
