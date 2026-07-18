# NetTransport structural-sight audit — findings

Swept NetTransport (the Telnet layer — untrusted network bytes, IAC escape math),
the last un-swept byte-handling unit.

## FOUND + FIXED: outbound IAC-doubling bound (fragile-by-accident)
In Telnet BINARY, a literal 0xFF must be sent doubled (IAC IAC). The send loop:
    while (n < High(outbuf)) and UartGuestToNet(FUart^, b) do begin
      outbuf[n] := b; Inc(n);
      if b = TELNET_IAC then begin outbuf[n] := TELNET_IAC; Inc(n); end;
    end;
One iteration can write TWO bytes, but the bound only guaranteed room for one. It
did not overflow — but ONLY incidentally: High(outbuf)=1023 left exactly one slot
of slack, so the doubled write landed on the last valid index. Any change (buffer
decl, bound to SizeOf, a third escape byte) would have reintroduced an overrun. The
safety was accidental, not guaranteed.
Fix: bound n <= High(outbuf)-1 — require room for BOTH bytes before writing, so the
doubling can never run off the end. Safe by design, not by luck.

## Checked and CLEAN (inbound state machine — the higher-risk, untrusted side)
The net->guest Telnet parser (TTelnetState machine) handles hostile remote input
safely:
- reads exactly `got` bytes (while i < got; b := inbuf[i]; Inc(i)) — no index overrun.
- proper state machine, no unbounded buffer accumulation.
- SB subnegotiation (variable length, remote-controlled): waits in tsSB/tsSBIAC for
  IAC SE, DISCARDING content — an endless SB just discards bytes, cannot overflow
  (the classic Telnet-parser overflow spot, handled correctly here).
- escaped IAC (FF FF) -> one FF to guest; unknown 2-byte commands swallowed safely.

## Verified (test_transport_iac_bounds, 4/4)
- a full ring of all-0xFF -> 1024 bytes sent, all FF, EVEN count (every FF doubled,
  none split at the edge), sent chunk within bounds, no overflow/crash.
Full suite: 32 tests, 0 failures (FPC 2.6.4 + 3.2.2).

## Audit thread complete
The whole byte path is now swept: door -> FOSSIL -> seam -> transport -> wire.
Findings across the thread: FOSSIL (DTR, block I/O, GET_INFO), AT dialer (port
wrap), transport (IAC bound). Each a real or latent ghost, each fixed + tested.
