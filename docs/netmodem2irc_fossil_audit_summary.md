# FOSSIL/COM audit — summary of findings and fixes

Using the ELECOM ComBase + mSyncFos references (found on the maintainer's HDD) and
the FOSSIL/X00 spec as oracles, we checked our INT 14h dispatch (NM_Fossil) function
by function — not "does it run" but "is it right against the contract." Findings:

## Fixed
1. Fn 06h SET_DTR — only LOWERED DTR; raise (AL=1) did nothing. ELECOM's stateful
   Com_SetDtr revealed the gap. Now handles both; DTR in MCR bit; lower = hangup,
   raise = ready without fabricating carrier. (test_fossil_dtr, 6/6)
2. Fn 18h/19h READ_BLOCK/WRITE_BLOCK — NOT implemented (no-op). These are the
   high-throughput functions (file transfer / bulk). Now implemented via a Buf
   pointer (host analog of ES:DI), non-blocking, honest returned count, bounds-safe.
   (test_fossil_block, 10/10)
3. Fn 1Bh GET_INFO — "half-wired": FossilGetInfo existed but the dispatch never
   called it. Now fills the struct into the caller's buffer via the same Buf
   mechanism, min(CX,SizeOf), no overflow. (test_fossil_getinfo, 8/8)
4. Fn 0Fh FLOW_CONTROL — was a no-op leaving AL undefined. Now honestly returns
   AL=0 (no byte-level flow control over TCP; the transport self-paces). A door
   reads this to learn what it got. (test_fossil_flow, 3/3)

## Checked and CORRECT (no change needed)
- Fn 03h GET_STATUS — AH bits RDA/THRE/TSRE (01/20/40) and AL MSR layout
  (DCD=80, CTS=10, DSR=20) match spec. CTS/DSR held asserted (virtual modem always
  ready); DCD tracks carrier; RI tracks ring. Correct.
- Fn 02h RX_WAIT — returns AL=0 when empty; a semantic (blocking) difference from
  real FOSSIL, but correct for the NT/event model. Documented, not changed.
- Fn 04h INIT signature $1954, BX $0521 (maxfunc 21h, rev 5) — correct.

## The pattern
Three real functional gaps (DTR direction, block I/O, GET_INFO wiring) plus one
honesty fix (flow control) — each would have bitten a real door, each now locked in
by a boundary-disciplined test. Running was not seeing; checking against the
reference + spec saw them. Full suite: 30 tests, 0 failures (FPC 2.6.4 + 3.2.2).
