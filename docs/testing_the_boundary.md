# Testing the boundary — proving a fix without reproducing the real condition

The Mystic maintainer's testing ladder (taught via "how do you test the qwkpoll fix
without a live 4MB QWK message?"), recorded as method and applied to netmodem2irc.

## Core move: test the NUMBER, not the megabytes
The bug isn't about QWK packets (or seam frames) — it's about a number overflowing
a variable. So don't reproduce the whole real-world input; test the MATH at the
sizes where the type flips. "A 4MB message is just a number bigger than 32,767
blocks." Reframe the huge input as the small number at the boundary.

## The ladder (cheapest -> strongest)
- L1  Boundary analysis (no code): find the exact flip points (65,536 bytes for a
      Word; 32,768 blocks ~= 4MB for a SmallInt). Test just BELOW / AT / ABOVE.
      Turns "test a 4MB message" into "check ~6 numbers."
- L2  Isolate the calculation: pull the formula into a standalone function, feed it
      numbers directly. The bug lives in the arithmetic, so test the arithmetic.
- L3  Independent oracle: compute the expected answer a DIFFERENT way than the code
      under test. If you derive truth with the same logic as the code, you repeat
      the bug and your test passes on a broken program. A good test derives truth
      independently.
- L4  Synthetic minimal fixture: don't hunt a real huge input — fabricate one
      (StringOfChar('X', 4200000), or a header claiming a huge count). Controlled,
      instant, reproducible. A synthetic input built to hit the boundary beats a
      real one that happens to be big.
- L5  Round-trip / property test (strongest): write N, read N back, assert equal,
      looping N across the boundaries. The property "what I wrote == what I read"
      IS the oracle (no hand-calculation). Catches export/import MIRROR bugs
      together.

## Applied to netmodem2irc's seam LEN field (test_seam_boundary_roundtrip, 10/10)
- L1: exercised at the flip points — 255/256 (Byte boundary), 65408/65535 (16-bit
      LEN boundary) — not random sizes.
- L3: an independent OracleFrameSize (payload+6), derived differently than the
      unit's FrameSize, so a shared bug can't hide.
- L5: write payload of size N -> parse back -> assert BYTE-FOR-BYTE equal, at the
      boundary (a 65,535-byte payload round-trips byte-exact).
- Plus: 65536 refused under the round-trip harness (guard holds).
Full suite: 22 tests, 0 failures (FPC 2.6.4 + 3.2.2).

## Honest self-correction
The earlier test_seam_roundtrip only round-tripped at SMALL sizes and used the
unit's own size logic. This test adds the boundary sizes AND an independent oracle
(L3) AND byte-exact round-trip AT the boundary (L5) — strictly stronger. The
maintainer's ladder is why the gap was visible.

## Takeaway
You almost never test a bug by reproducing the literal real-world scenario. You:
find the boundary where the type changes behavior, isolate the small piece of logic
that broke, feed it controlled values right at that boundary, and check against an
independently-derived answer. Test the number, not the megabytes.

## Credit
Method taught by the Mystic maintainer (qwkpoll fix testing walkthrough). Pairs
with seeing_the_structure.md (finding the ghost) — this is proving it's dead.
