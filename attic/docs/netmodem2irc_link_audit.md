# Link units audit — NM_NamedPipeLink (structural-sight sweep)

Swept NM_NamedPipeLink for the qwkpoll class of ghost (buffer over/underrun,
byte-count math, untrusted-length handling).

## Finding: CLEAN — no ghost, nothing to fix
- ReadBytes / WriteBytes are thin delegations to the OS (ReadFile/WriteFile on a
  named pipe). Len is passed straight to the OS, which caps the transfer; the
  reported ReadCount/Written is exactly what the OS moved. No local accumulation
  buffer, no index arithmetic, no place to overrun — the OS owns the bounds.
- Non-blocking empty handled correctly: PIPE_NOWAIT + ERROR_NO_DATA -> ReadCount=0,
  Result=True (pipe open, nothing to read) vs. a real error/closed -> False.
- No fixed-size local buffers in the unit (no array[0..N] to overflow).
- Windows-guarded; the risky surface is the OS pipe, not our code.

## Audit coverage (whole byte path now swept)
- FOSSIL (NM_Fossil): DTR, block I/O, GET_INFO, flow control — fixed + tested.
- AT dialer (NM_ATCommand): port-wrap — fixed + tested.
- Transport (NetTransport): IAC-doubling bound — fixed + tested; inbound state
  machine audited clean.
- Seam (NM_SeamProtocol/Sender): LEN overflow, node bounds — fixed + tested.
- Switch (NM_Node): dangling-ref — fixed + tested.
- Config (NM_Config): range checks — clean + tested.
- Server link (NM_ServerLink): byte queue — clean + tested.
- Named-pipe link (NM_NamedPipeLink): CLEAN (this doc).
- Synapse link (NM_SynapseLink): ACTUALLY READ (closing the pattern-match gap).
  Found a REAL BUG: Send() assumed SendBuffer sends all (Sent:=Len) but in
  NonBlockMode a partial send silently DROPS the unsent tail. Fixed with a
  bounded partial-send tail buffer (FSendTail, cap NM_SEND_TAIL_MAX=65536,
  QueueTail/FlushTail preserving order, back-pressure at cap). Off-by-default
  debug instrumentation added ({$IFDEF NM_SOCKET_DEBUG}: bytes in/out, partials,
  connects, errors, tail peak + DebugSnapshot). test_synapse_tail 12/12.

Conclusion: the structural-sight sweep (for overflow/wrap/bounds/dangling-ref
bugs) covers netmodem2irc's byte-handling units, with one honest caveat:
NM_SynapseLink was pattern-matched to the pipe link, not read line-by-line. Real
ghosts were found + fixed where they lived (FOSSIL, AT, transport, seam, switch);
NM_NamedPipeLink was READ and is clean (thin OS delegation, no bounds of its own);
NM_SynapseLink was READ and a real bug was found + fixed (partial-send byte loss).
34 tests, 0 failures. "Audited" means "swept for this bug class by read + test",
not "provably bug-free" — other bug classes are out of this sweep's scope.
The audit gap (pattern-match vs read) is now CLOSED — every unit has been read.
