# Concrete TServerLink (NM_ServerLink) — a real link for the TSR

The TSR (NM_TSR) talks to the server via a TServerLink (Send/Poll). It was only
exercised against a FAKE link in tests. This unit provides REAL implementations.

## TLoopbackServerLink (host-testable now)
An in-process byte-queue link. Send pushes bytes out (readable via ReadSent /
a paired peer's Poll); DeliverToPoll feeds this side's Poll. Backed by TByteQueue
(a growable FIFO with a read cursor, compacted when drained — no fixed cap, memory
bounded). Two links can PairWith each other (A's out = B's in) to model full duplex.
Lets the whole driver<->server loop run against a REAL link object, and is a genuine
transport for same-process wiring (e.g. an in-process server).

## TSynapseServerLink ({$IFDEF HAS_SYNAPSE})
A real TCP link over Ararat Synapse (TTCPBlockSocket): ConnectTo(host,port),
non-blocking Poll (CanRead(0) then RecvBufferEx), Send via SendBuffer. This is the
shape the i8086 TSR will use to reach the server over a socket.

## Verified (test_serverlink, 9/9)
- TByteQueue: order preserved, partial pull, remainder, drain.
- TSR against the REAL loopback link: Startup's smConnect goes out; guest "Hi" goes
  out as smData; a delivered "OK" frame flows into the guest's UART RX.
Full suite: 33 tests, 0 failures (FPC 2.6.4 + 3.2.2).

## Significance
The driver moves from "proven with a stub" to "proven with a real transport". With
the loopback link the full loop is exercised end to end against a concrete object;
the Synapse link is the real TCP path (compile-guarded, runtime-tested on the
Windows/Lazarus build). This was the last sandbox-buildable hardening item — the
Pascal core is now complete and airtight.
