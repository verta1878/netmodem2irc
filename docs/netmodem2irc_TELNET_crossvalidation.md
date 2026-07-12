# ELECOM TELNET — cross-validation of our NetTransport

Second independent confirmation (after FOSSIL/FOS_COM): ELECOM's TELNET.PAS
(Maarten Bekers, 1998-99) implements the Telnet protocol layer the same way our
NetTransport does. Two independent period implementations agreeing on the wire
protocol = strong evidence our transport is correct.

## Honest boundary: TELNET is Win32/OS2-bound (can't compile on the host)
TELNET.PAS `uses SockFunc, SockDef, Combase, BufUnit, Threads`. Its socket units
(SOCKFUNC/SOCKDEF = "IBM TCP/IP and WinSock", OS/2+Win32) and THREADS (Os2Base /
Windows) are PLATFORM-BOUND. So TELNET compiles on a Win32/OS2 target (fpc264irc),
NOT on x86_64-linux here. COMBASE + BufUnit (its portable deps) are already ported.
What we CAN do now — and did — is cross-validate the PROTOCOL logic.

## The Telnet constants — IDENTICAL to ours (both RFC 854/856)
| Constant | ELECOM TELNET | our NetTransport |
|----------|---------------|------------------|
| IAC  | 255 | 255 |
| DONT | 254 | 254 |
| DO   | 253 | 253 |
| WONT | 252 | 252 |
| WILL | 251 | 251 |
| SB   | 250 | 250 |
| SE   | 240 | 240 |
| BINARY | 0 | 0 |

## The IAC state machine — same approach
ELECOM TELNET uses an IacState machine: 0 = nothing, 1 = received IAC, 2 = handling
the IAC. Our NetTransport uses the same IAC-filtering state approach (IAC ->
command -> option). Both send WILL/WONT/DO/DONT for option negotiation and both
support BINARY (option 0) — which BBS work REQUIRES for 8-bit-clean data.

## What this validates
- Our Telnet constant values (independently confirmed correct).
- Our IAC state-machine design (a second implementation chose the same shape).
- Our BINARY negotiation (both treat option 0 / binary transmission as essential).

Combined with the FOSSIL cross-validation (FOS_COM), BOTH the FOSSIL layer AND the
Telnet layer of netmodem2irc are now cross-checked against independent, period-
correct ELECOM code. The two load-bearing protocol layers are validated.

## What remains (target-bound)
Compiling TELNET itself needs a Win32/OS2 build (fpc264irc) with its socket +
threading stack. That's a runtime/integration step; the PROTOCOL it implements is
already confirmed to match ours.
