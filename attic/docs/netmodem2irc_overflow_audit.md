# Structural-sight audit: the seam LEN overflow ghost (found + fixed)

Applying the Mystic maintainer's signed-vs-unsigned masterclass (the qwkpoll
Word/SmallInt overflow) to netmodem2irc's own code. Method: trace a value across
the writer->wire->reader boundary, check its type against its threshold, and TEST
PAST THE BOUNDARY, not just the sizes that work today.

## The boundary audited
The seam protocol's LEN field (payload length) is a 16-bit little-endian Word on
the wire (bytes 3..4, max 65,535). It crosses a writer->reader boundary:
- WRITER: BuildFrame encodes LEN from PayloadLen (an Integer / 32-bit).
- READER: TSeamParser reads len := FBuf[3] or (FBuf[4] shl 8), then consumes it in
  a counted loop (for i := 1 to 4 + len) and a copy of len bytes.

## The ghost (same class as qwkpoll's Word)
BuildFrame wrote only the low 16 bits of PayloadLen:
  d[3] := Byte(PayloadLen and $FF);
  d[4] := Byte((PayloadLen shr 8) and $FF);
but copied the FULL payload (for i := 0 to PayloadLen-1). So if PayloadLen ever
exceeded 65,535, LEN would be SILENTLY TRUNCATED to 16 bits while the full payload
was written -> the reader would read the wrong (small) LEN, then desync exactly
like qwkpoll: "writer does too much, header says too little, reader misaligns and
cascades." The reader's for-loop trusts len completely (the qwkpoll lesson: a
for-loop never asks if its bound is sane).

## Was it firing? No — but it was LATENT
Today NM_SeamSender caps/chunks payloads at 2040, so PayloadLen never exceeds
65,535 and the ghost cannot fire. BUT that is a CALLER-side guarantee, not a
structural one. Any future caller (or the i8086 TSR) calling BuildFrame with
PayloadLen > 65535 would corrupt silently. Latent mirror bug waiting past the
tested threshold — exactly what the maintainer warned about.

## The fix (structural, not caller-dependent)
BuildFrame now REFUSES to encode a payload that won't fit the 16-bit LEN field:
  if (PayloadLen < 0) or (PayloadLen > $FFFF) then begin Result := 0; Exit; end;
It returns 0 (invalid) instead of silently truncating. The overflow can no longer
fire regardless of caller. This is "writing the safety the for-loop doesn't have."

## Verified PAST the boundary (test_seam_overflow, 6/6)
- exactly 65535 payload: encodes OK (full frame).
- 65536 payload: REFUSED (returns 0, no silent truncation).
- 100000 payload: refused.
- negative length: refused.
- normal frame still round-trips, payload intact incl $A5 (no regression).
Full suite after fix: 21 tests, 0 failures (FPC 2.6.4 + 3.2.2).

## Credit / method
The hunting method is the Mystic maintainer's, taught via the qwkpoll signed-vs-
unsigned overflow (Chunks: Word wraps small-positive -> corruption; Chunks:
SmallInt wraps negative -> for-loop runs zero times -> omission; both fixed by
widening to LongInt). Recorded in seeing_the_structure.md. Lesson applied here:
follow the value writer->wire->reader, guard the boundary the loop trusts blindly.

## Note (an honest process catch)
The new test first "failed" in the suite runner only because its final line didn't
contain the runner's success keyword "VERIFIED" (the logic passed 6/6 standalone).
Fixed the wording; not a logic error. Worth noting so the next person doesn't
misread it.
