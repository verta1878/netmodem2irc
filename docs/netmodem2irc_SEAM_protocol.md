# netmodem2irc — driver<->server seam protocol

The framed protocol the DOS FOSSIL TSR and the Windows server speak over their
pipe/socket link (NM_SeamProtocol.pas). Target-independent: built + TESTED now;
the future i8086 TSR uses this exact framing unchanged.

## Frame format (length-prefixed, binary-clean)
  byte 0    : SYNC = $A5
  byte 1    : TYPE (smData/smConnect/smDisconnect/smCarrierUp/smCarrierDn/smBreak/smKeepAlive)
  byte 2    : NODE (0..98)
  byte 3..4 : LEN (payload length, little-endian)
  byte 5..  : PAYLOAD (LEN bytes, ANY value)
  last      : CHECK = XOR of bytes 1..(4+LEN)

## Why length-prefixed (not delimiter-based)
The payload can contain ANY byte, including $A5 (SYNC), because the parser reads
exactly LEN bytes instead of scanning for a terminator. This is 8-bit-clean by
construction — the seam equivalent of the transport's Telnet IAC-doubling.
Binary safety is REQUIRED (Zmodem/CP437/binkp carry every byte value).

## TSeamParser — incremental, handles real link conditions
- Split reads: frame fed one byte at a time reassembles (pipe data arrives in
  arbitrary chunks).
- Back-to-back frames in one read.
- Resync on garbage (scans to next SYNC, checksum-validates).

## Verified
test_seam: 14/14 PASS — "SEAM PROTOCOL VERIFIED", incl. all-256-byte binary
safety (with $A5 in the payload), single-byte split feeds, two frames per read,
resync past garbage, zero-payload control frames. On FPC 2.6.4 + 3.2.2.

## Where it fits
DOS FOSSIL TSR  <--NM_SeamProtocol frames over NamedPipeLink/socket-->  server
The TSR wraps INT 14h data/control into seam frames; the server unwraps them into
TNodeManager operations (data -> node rings, smConnect -> RingNode, smDisconnect
-> disconnect, etc.). Both sides use this one unit, so the wire format can't drift.

---

## UPDATE: the driver-side SENDER completes the loop (NM_SeamSender)

The seam now has BOTH halves, built and tested:
- SERVER receive: TServerBridge.FeedDriverBytes (raw bytes -> frames -> node ops).
- DRIVER send:   NM_SeamSender (FOSSIL/UART activity -> frames -> a byte sink).

NM_SeamSender wraps the TSR's activity into frames and pushes them to a TByteSink
callback (the real TSR points this at its pipe/socket write; tests point it at a
buffer). Methods: SendData/SendByte (smData), SendConnect, SendDisconnect,
SendBreak, SendKeepAlive. Target-independent — the i8086 TSR reuses it unchanged.

### Full-loop verification (test_seam_roundtrip, 6/6)
Driver sender emits frames -> exact bytes fed to the server -> correct node ops:
- SendConnect -> server rings the node.
- SendData("HELO") -> reaches the node -> queued to the wire.
- ALL 256 byte values (incl 0xA5 SYNC) survive the full loop — binary-clean e2e.
- SendBreak -> server handles remote break.
- SendDisconnect -> server removes the node.
"FULL DRIVER<->SERVER SEAM LOOP VERIFIED."

### What this means for i8086
The FOSSIL TSR's network conversation is now fully built and proven. When i8086
lands, the TSR plugs its real pipe/socket write into the TByteSink callback; every
layer above is already tested. The only new code left is the thin real-mode
ISR/residency wrapper — the driver<->server messaging is done.

---

## Naming for readability (tremedy2c)

The frame's fields and the frame variable are named to explain themselves, so the
code reads in plain language instead of cryptic shorthand:
- `TSeamFrame.NodeIndex` (was `Node`) — it is an ADDRESS (which comport/node the
  message is for, 0..98), not a node object. Naming it `NodeIndex` matches the
  functions that consume it (`NodeByIndex(Frame.NodeIndex)`) and stops readers
  wondering whether it holds a node.
- The handler parameter is `Frame` (was a bare `F`) — no more guessing whether
  `F` meant "fossil" or something else; it is the seam frame being handled.

Now the routing reads as plain intent, e.g.:
  `RingNode(Frame.NodeIndex);`  /  `node := FNodes.NodeByIndex(Frame.NodeIndex);`

Reminder of the terms:
- **seam / joint** — the boundary where the two separate pieces meet and hand off:
  the FOSSIL driver (DOS / INT 14h) and the server (network / Telnet). A seam is a
  clean, visible join, not a tangle.
- **seam frame** — one complete message passed across that boundary (SYNC, TYPE,
  NodeIndex, LEN, PAYLOAD, CHECK). It is a MESSAGE ABOUT a node, not a node itself.
