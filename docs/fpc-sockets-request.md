{ ===========================================================================
  This file is a historical record, not an active feature request.
  =========================================================================== }

# FPC i8086-msdos Sockets Backend — Feature Request (historical)

Written mid-2026. **Resolved by fpc264irc r3.1 (2026-07-25).**

## The original problem

FPC's `sockets` unit compiles for the i8086-msdos target and produces
a valid PPU, but the BSD socket calls (`fpSocket`, `fpConnect`,
`fpSend`, `fpRecv`, `fpClose`, `TInetSockAddr`) have no backend
implementation. They are stubs that work only on Unix/Linux targets.

This meant the only way to do TCP/IP from real-mode DOS was to link
against Watt-32, a C library compiled with OpenWatcom. That dragged in:

- `wattcpwl.lib` (382K) — the TCP/IP stack itself
- `clibl.lib` — Watcom C runtime, large model
- `emu87.lib` — FPU emulation
- `stubs.asm` — filler for symbols neither toolchain provided
- OMF object format conversion (`fixasm.py` + `nasm -f obj`)
- `omfinfo.py` — dependency walker for OMF archives

A five-stage build for what should have been `uses Sockets`.

## The request (never submitted)

Planned for FPC GitLab: implement the BSD socket calls on i8086-msdos
by linking against a packet driver via INT calls, the same approach
Watt-32 uses internally but in Pascal.

## Resolution

**sysop/0 did it inside fpc264irc instead of upstream.**

fpc264irc r3.1 (commit `5cf0495a`, 2026-07-25) rewrote `sockets.pp`
for both go32v2 and i8086:

- go32v2: rewritten from C (Watt-32, 27 externals) to pure Pascal
  using the `go32` unit (960 → 1,271 lines)
- i8086: ported from go32v2 using `Dos.Intr()` (1,268 lines)
- Full TCP/IP: ARP resolve, IP/TCP header building, RFC 793 checksums,
  DNS query builder/parser
- TCP state machine: SYN_SENT → ESTABLISHED, data → recv buffer, FIN
  handling, RST

The entire Watt-32 / Watcom / OMF apparatus is now unnecessary for
programs that need TCP/IP on DOS. For netfosdl specifically it was
never needed — the DOS FOSSIL driver has no network — but for any
future DOS program that does need sockets, the dependency is gone.

## See also

- `netmodem2irc_watt32_cleanup_phases.md` — the cleanup plan
- `netmodem2irc_fossil_separation.md` — why netfosdl has no TCP
- `attic/watt32/README.md` — what was retired
