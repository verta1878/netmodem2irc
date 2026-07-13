# FOSSIL Fn 18h/19h block read/write — gap found by the audit, now implemented

The FOSSIL/COM audit found that Fn 18h (READ_BLOCK) and Fn 19h (WRITE_BLOCK) were
NOT implemented — they fell through to the no-op else arm. These are the
HIGH-THROUGHPUT functions: many doors (file transfer / Zmodem, bulk output) move
whole buffers via 18h/19h rather than byte-by-byte (01h/02h). A no-op there means
bulk transfers silently do nothing. Real functional gap — now closed.

## The contract (FOSSIL/X00)
- Fn 18h READ_BLOCK:  ES:DI -> buffer, CX = max bytes; returns AX = bytes actually
                      read (0..CX). Non-blocking: take only what's available.
- Fn 19h WRITE_BLOCK: ES:DI -> buffer, CX = bytes; returns AX = bytes actually
                      written (0..CX). Non-blocking: write only while room exists.

## Implementation
- Added a Buf: PByte field to TFossilRegs — the host analog of the real ES:DI far
  pointer (the DOS/i8086 ISR maps ES:DI to it). Nil when no buffer.
- Fn 18h: read from RX ring into Buf, up to CX, stop when RX empty; AX = count.
- Fn 19h: write from Buf into TX ring, up to CX, stop when TX full; AX = count.
- Bounds discipline: never transfer past CX; never over/under-run the ring; the
  RETURNED COUNT is always the true number moved (the qwkpoll lesson — in block I/O
  the count is what breaks, so test the count at its boundaries).

## Verified (test_fossil_block, 10/10)
- write 5 -> AX=5; read CX=64 with only 5 available -> AX=5 (not 64).
- CX < available -> reads exactly CX; the rest STAYS in RX (not lost).
- write > TX room -> truncates to room, reports honest count.
- nil buffer (both dirs) -> 0, no crash. empty RX -> 0.
Full suite after: 28 tests, 0 failures (FPC 2.6.4 + 3.2.2), no regression (the
FOSSIL cross-validation test_fossil_client still passes).

## Note
On the DOS/i8086 build, the INT 14h ISR will set R.Buf from ES:DI before calling
FossilDispatch. On the host, tests/callers set Buf directly. Same dispatch code
both targets.
