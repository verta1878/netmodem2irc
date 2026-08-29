# netmodem2irc — Release Notes: netfosdl v1.0 completion (2026-08-29)

Author: wrench (transport / FOSSIL)
Merged into: full clone of github.com/verta1878/netmodem2irc
             (base commit bd68df05, 2026-08-13)
Scope: DOS FOSSIL driver (dos/driver/) finished to v1.0. No other
       subsystems touched.

## Summary of today's work

The DOS FOSSIL TSR (netfosdl) was at ~70%: core INT 14h functions worked
and were proven in DOSBox-X, but the receive path was polled-only and
several FSC-0015 functions were grouped no-op stubs. Today closed the
remaining ~30% and merged the finished driver into dos/driver/.

1. Interrupt-driven receive — wired. serial_irq.pas (4KB ring buffer +
   UART ISR, by kiddo/sysop/0) existed but was never connected. Now Fn04
   hooks the RX interrupt (SerEnableIRQ), Fn05 unhooks it and restores
   the PIC mask (SerDisableIRQ), and receive consumers (Fn02/0C/18/03)
   route through FossilRxAvail/FossilRxByte — ring buffer when the IRQ is
   active, polled fallback otherwise.

2. Newly implemented (were no-op stubs): Fn0F flow control (honors the
   CTS/RTS hardware bit; remembers XON/XOFF mode), Fn10 Ctrl-C check
   (returns 0 = no abort), Fn17 warm reboot (BIOS 0040:0072=1234h then
   far-jmp FFFF:0000, unhooks the IRQ first).

3. Correctness fix: Fn18 read-block now delivers a pending Fn0C peek byte
   first, so peek-then-block-read never loses that byte.

4. Documented safe defaults (intentional): Fn11/12 cursor, Fn13 ANSI,
   Fn14 watchdog, Fn15 char, Fn16 timers, Fn0D/0E keyboard — local
   console/watchdog functions, N/A for a remote serial FOSSIL, return
   well-formed no-ops.

## Coverage & verification
18 FSC-0015 rev-5 functions with real behavior + 8 documented defaults.
Signature AX=1954h, BX=0521h. Built with the fpc264irc i8086
cross-compiler from inside the merged tree; DOSBox-X (386/FPU/dummy COM1):
TSR loads, hooks INT 14h, AX=1954h; Fn04/03/00/05 round-trip; Fn0F/Fn10
exercised, no hang.

## Not covered by sandbox
Real UART hardware + live modem/null-modem link — the CTS flow-control
gating wants a real CTS line. Logic complete, INT 14h contract confirmed;
on-metal validation remains.

## Relationship to the engine FOSSIL
engine/NM_Fossil.pas (FOSSIL-over-TCP) is a separate, already-complete
implementation and was intentionally not changed.
