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
