# The TSR skeleton (NM_TSR) — the resident-program shell, i8086-ready

The top-level structure of the FOSSIL TSR: the resident program the DOS BBS loads
so its INT 14h calls become network traffic. It plugs together the three already-
built, already-tested pieces and completes the driver side of netmodem2irc.

## What it wires together
    1. UART (NM_UART16550)          — the emulated 16550 the guest talks to
    2. FOSSIL dispatch (NM_FossilDriver) — INT 14h calls -> UART activity
    3. seam sender (NM_SeamSender)   — UART activity -> frames -> server (byte sink)
    + a TServerLink abstraction      — the pipe/socket to the server (Send/Poll)

## The full loop it completes
    guest -> INT 14h -> FOSSIL dispatch -> UART TX ring -> Pump -> seam sender
      -> TServerLink.Send (pipe/socket) -> SERVER
    SERVER -> frames -> TServerLink.Poll -> Pump -> parser -> UART RX ring
      -> FOSSIL dispatch -> guest

## TNetModemTSR — the resident driver (one per served node)
- Startup:  reset UART, InstallFossil (hook INT 14h on DOS; no-op on host),
            send smConnect to the server.
- Pump:     one service tick — drain UART TX -> send as smData frames; poll the
            server link -> feed frames -> UART RX (+ carrier from smConnect/Carrier).
- Shutdown: send smDisconnect, RemoveFossil (restore INT 14h on DOS).
- UartPtr:  exposes the RESIDENT UART by pointer (the FOSSIL ISR must dispatch on
            the real UART, not a copy).

## Target-independent structure, guarded residency
The ORCHESTRATION (init, pump both directions, teardown) is plain Pascal, built and
TESTED on the host now. The real-mode RESIDENCY (INT 14h vector hook, TSR-resident,
the actual pipe/socket) is DOS-specific: InstallFossil/RemoveFossil have a DOS build
(real vector) and a host build (no-op), and the pipe/socket lives behind TServerLink.
=> When i8086 lands, only the thin real-mode wrapper is filled in: a real
   TServerLink (pipe/socket) + the i8086 INT 14h ISR (dos/fossil_dos.pas) + residency. The shape,
   the data flow, and every layer above are already here and proven.

## Verified (test_tsr, 8/8) — TSR SKELETON ORCHESTRATION VERIFIED
- Startup sends smConnect for the node.
- Guest writes UART TX -> Pump -> server receives smData "Hi".
- Server sends smData -> Pump -> lands in UART RX -> guest reads "OK".
- Server smConnect -> carrier raised.
- Shutdown sends smDisconnect.
Full suite: 24 tests, 0 failures (FPC 2.6.4 + 3.2.2).

## Design notes (compiler-driven, honest)
- InstallFossil/RemoveFossil were DOS-only; now declared for BOTH targets (host
  no-op) so the TSR orchestration builds/tests everywhere. The compiler caught the
  original DOS-only guard.
- UART exposed by pointer (UartPtr), not by value — the resident ISR needs the real
  UART. The compiler's "can't take address of a by-value property" pushed the right
  design.

## What remains for a live TSR (i8086, blocked on the backport)
- A concrete TServerLink over a real pipe/socket to the server.
- The i8086 INT 14h ISR (map CPU regs <-> TInt14Frame, call DispatchFrame) and
  TSR residency (keep-resident, restore vector on unload).
Both are thin wrappers over this proven shell.
