# FOSSIL Fn 06h (SET_DTR) fix — found by checking against ELECOM/SyncFos

The maintainer's call: don't adopt Synchronet's FOSSIL, but use the SyncFos +
ELECOM references to CHECK our own FOSSIL and fix it if broken. Doing that surfaced
a real gap.

## What was checked
Compared our NM_Fossil INT 14h dispatch against:
- the canonical FOSSIL/X00 spec (Raymond Gwinn),
- ELECOM ComBase (Com_SetDtr(State: Boolean) — DTR is STATEFUL, both directions),
- SyncFos's use of the ELECOM Com_* abstraction.

## The bug (Fn 06h only lowered DTR)
Our handler was:
    FN_SET_DTR: if R.AL = 0 then UartSetCarrier(U, False);
It handled AL=0 (lower DTR / hangup) but did NOTHING for AL=1 (raise DTR). Per the
FOSSIL spec and ELECOM's stateful Com_SetDtr, DTR is settable BOTH ways. A door
that lowers then raises DTR to reset the line would find nothing happened on the
raise. Real behavioral gap vs. the contract.

## The fix
    FN_SET_DTR:
      if R.AL = 0 then begin
        U.MCR := U.MCR and (not MCR_DTR);   // DTR low
        UartSetCarrier(U, False);           // hangup
      end else
        U.MCR := U.MCR or MCR_DTR;           // DTR high (ready)
- DTR now reflected in the MCR bit (where it belongs).
- Lowering DTR still hangs up (drops carrier).
- Raising DTR marks the line ready but does NOT fabricate carrier (carrier comes
  from a real connection, not from asserting DTR) — the honest semantic.

## Verified (test_fossil_dtr, 6/6) + no regression
- carrier up; DTR low -> hangup + MCR DTR bit cleared;
- DTR high -> MCR DTR bit set, carrier NOT falsely created;
- toggle again -> hangup still works.
Full suite after fix: 27 tests, 0 failures (FPC 2.6.4 + 3.2.2), including the
existing FOSSIL cross-validation (test_fossil_client) — the fix COMPLETED the
contract without breaking it.

## Note on Fn 02h (RX_WAIT) — considered, left as-is (documented)
Fn 02h returns AL=0 when no char, but 0x00 is a valid data byte, so a caller can't
distinguish "null byte" from "nothing". On real FOSSIL Fn 02h BLOCKS until a char
arrives (so it never returns "nothing"); our non-blocking return is correct for the
NT/event model where blocking is the caller's job (the code comment says so). This
is a semantic difference, not a clear bug — documented here, not changed. If a real
door ever misbehaves on null handling, revisit.

## Credit
The gap was found by checking against Maarten Bekers' ELECOM ComBase (stateful
Com_SetDtr) surfaced via the mSyncFos/SyncFos archive the maintainer found on his
HDD. Reference material doing its job: a working sibling implementation as a test
oracle for our own. (We did NOT adopt Synchronet's FOSSIL — we fixed ours.)
