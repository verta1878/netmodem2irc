# NM_ATCommand structural-sight audit — findings

Applied the qwkpoll/structural-sight sweep to NM_ATCommand (untrusted input: AT
command strings from the door).

## Checked and CLEAN (already well-guarded)
- FLine command buffer: a `string` (dynamic, no fixed-array overrun) AND capped at
  128 chars on append (line: `if Length(FLine) < 128 then FLine := FLine + Chr(B)`)
  — a door spamming bytes can't grow it unbounded. Backspace guarded against
  underflow on an empty line. Good discipline already in place.
- AmpParam: range-checked `(p >= 1) and (p <= Length(s))` before indexing s[p].

## FOUND + FIXED: ParseDial port wrap (the qwkpoll class)
Dialing `ATDT host:PORT` parsed the port as:
    APort := Word(StrToIntDef(Copy(...), FDefaultPort));
Word() wraps SILENTLY: `host:70000` -> Word(70000) = 4464, so the modem would dial
a DIFFERENT port than asked, with no error. No lower-bound check either (port 0).
Fix: parse into a wide LongInt first, range-check 1..65535, and fall back to the
default for out-of-range — never assign a wrapped value. Same discipline as the
config parser.

## Verified (test_at_dial_port, 9/9)
- valid: 1, 65535, 6667 parse; no port -> default.
- GHOST: 70000 does NOT wrap to 4464 -> falls back to default.
- 0, 99999, non-numeric -> default, never wrapped.
Full suite: 31 tests, 0 failures (FPC 2.6.4 + 3.2.2).

Added a TestParseDial accessor (thin public wrapper) so the private parser is
unit-testable.
