# Full boundary audit — applying structural sight to the whole seam/switch path

After the maintainer's two lessons (see the ghost; test the boundary), a
systematic sweep of netmodem2irc's seam + switch code for the qwkpoll class of
bug: values crossing writer->reader boundaries, for-loops trusting their bounds,
and untrusted wire values used as indices. Done BEFORE adding features.

## What was checked and found
1. **Seam LEN field (16-bit Word on the wire)** — FOUND + FIXED last pass:
   BuildFrame would silently truncate LEN past 65,535 while copying full payload
   -> reader desync. Guarded (refuse > $FFFF). Proven byte-exact at the boundary
   (test_seam_boundary_roundtrip, incl 65,535-byte round-trip).

2. **Writer/reader checksum bound (mirror pair)** — SAFE: writer
   `for i := 1 to 4 + PayloadLen` and reader `for i := 1 to 4 + len` use the same
   formula; len is bounded 0..65535 by the LEN guard. Mirror-correct.

3. **Node index range checks** — SAFE: AddNode, RemoveNode, NodeByIndex, and
   MarkActive all range-check (0 <= idx < NM_MAX_NODES) before indexing FNodes[].
   (Verified by reading each, not assuming.)

4. **Wire NODE field trust boundary (Byte 0..255 vs NM_MAX_NODES=99)** — SAFE +
   NOW TESTED: HandleSeamFrame consumes F.Node (straight off the wire) via
   RingNode/OnDisconnectNode/OnSendRemoteBreak/MarkActive/NodeByIndex — every one
   clamps through a bounds check. A frame with NODE=200/255/150 is safely IGNORED,
   never indexes out of bounds. Locked in by test_seam_node_bounds (5/5) so a
   future change can't silently drop the guard.

## The discipline demonstrated
- Traced values across writer->wire->reader boundaries (LEN, checksum, NODE).
- Checked every for-loop's bound for sanity (the "for-loop trusts its bounds" rule).
- Treated wire values as UNTRUSTED — proved out-of-range inputs are clamped, not
  indexed. (A busy or hostile driver link could send anything; the reader must not
  trust it.)
- Where safe, PROVED it with a test rather than only reading — so the guarantee
  survives future edits.

## Result
Full suite: 23 tests, 0 failures (FPC 2.6.4 + 3.2.2). The seam/switch boundaries
are now audited, guarded where needed, and proven at the exact values where the
qwkpoll class of bug lives. Running was not seeing; the sweep saw (and locked down)
the boundaries before new features go on top.
