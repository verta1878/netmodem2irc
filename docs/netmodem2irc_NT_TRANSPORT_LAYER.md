# netmodem2irc — NT-branch transport layer (the user-mode replacement for Layer B)

## What this is (and an honest naming correction)
The `nt` branch has NO VxD. The NT kernel won't load a Win9x VxD, so Layer B (the
9x kernel plumbing — see netmodem2irc_DRIVER_MAP.md §B) does not exist on NT.
"NT Layer B" is therefore NOT a driver — it's the **user-mode component that takes
Layer B's place.** This doc designs that replacement.

Builds on (does not duplicate):
- netmodem2irc_DRIVER_MAP.md — the 3-layer split (A emulation / B kernel / C seam)
- docs/DRIVER_INTERFACE.md — recovery record + IOCTL spec + "two programs" model
- common/NetModemVxD.pas — the IOCTL constants ($00..$10) the server already speaks

## What Layer B did on 9x, and what must replace it on NT
On 9x, the VxD (Layer B) did three kernel-only jobs:
1. **Trap COM-port I/O** — intercept when a DOS/16-bit app touches COM port
   addresses, so reads/writes hit the emulated UART instead of real hardware.
2. **Run Ring-0 in VM context** — service that trapped I/O and inject virtual IRQs.
3. **Expose the driver to the user-mode server** via DeviceIoControl (Layer C).

On NT, there is no I/O-trapping VxD. The replacement is a **user-mode virtual COM
port** that presents a real COM device to applications, backed by our code:

```
  16-bit / console app  ── opens COMx ──►  virtual COM port (user-mode pair)
                                                   │
                                                   ▼
                                 Layer A emulation (UART/FOSSIL/AT) in Pascal
                                                   │
                                                   ▼
                                 Layer C byte-shuttle (TX/RX)  ──►  WinSock/Telnet
```

## The three NT-transport options (honest tradeoffs)

### Option 1 — com0com-style kernel COM pair + user-mode bridge (README's model)
Use an existing signed virtual-COM-port pair driver (com0com or similar). Our
Pascal server opens one end; the app opens the other. We run Layer A + C in Pascal
between our end and the socket.
- Pro: apps see a real COMx; no driver signing work by us (com0com is signed).
- Con: depends on an external driver being installed; on modern Win it must be a
  signed one.

### Option 2 — a small user-mode virtual serial provider we write
Provide the COM port ourselves via a user-mode serial framework.
- Pro: self-contained, no external driver.
- Con: presenting a *real* COMx from pure user mode on NT is limited; may need a
  minimal signed helper driver — driver-signing is a real burden. Heavier.

### Option 3 — direct socket mode (no virtual COM at all)
Skip presenting a COM port; the server just is a Telnet endpoint, and modern DOS/
BBS software connects via TCP directly (or via DOSBox's built-in modem emulation /
a FOSSIL-over-TCP shim).
- Pro: simplest; no driver, no signing. Fits DOSBox-based retro setups.
- Con: doesn't serve apps that truly require a hardware COMx.

**Recommendation (honest):** start Option 3 for the common modern case (DOSBox /
direct Telnet), because it needs ZERO kernel work and exercises Layer A + C + the
socket path end-to-end in pure Pascal — provable now with fpc264irc. Add Option 1
(com0com bridge) for apps that need a real COMx. Treat Option 2 (our own signed
driver) as last resort — signing cost is high and out of proportion for a revival.

## What's PASCAL (fpc264irc territory) vs. NOT

| Piece | NT-branch home | Language |
|-------|----------------|----------|
| Layer A: 16550 UART emulation | user-mode | **Pascal** (re-create from spec) |
| Layer A: FOSSIL / X00 / AT parser | user-mode | **Pascal** (re-create from spec) |
| Layer C: TX/RX byte-shuttle | user-mode | **Pascal** |
| Layer C: server protocol (IOCTL-equivalent) | user-mode | **Pascal** (common/NetModemVxD.pas already models it) |
| WinSock / Telnet | user-mode | **Pascal** (fpc264irc sockets) |
| Virtual COM port presentation | com0com (Opt 1) / helper (Opt 2) / none (Opt 3) | external / minimal / none |

So on NT, **everything except the actual virtual-COM-port presentation is Pascal** —
and the presentation is either delegated (com0com) or skipped (direct socket). This
is exactly why the NT branch is the FPC-friendly one: Layers A and C become
user-mode Pascal built with fpc264irc; only the OS COM-device seam is external.

## Design principles (carry from the fpc264irc work)
- **Shared GUI/core:** the Lazarus GUI + Layer A/C core is shared across 9x and nt
  branches; only the transport differs (per README). Keep that seam clean.
- **Spec-faithful emulation:** Layer A must match the 16550/FOSSIL/AT specs the 9x
  VxD implements — the DRIVER_MAP names the exact procs (IOHandler, ParseATCommand)
  to re-create. BBS doors are picky; faithfulness matters.
- **Prove end-to-end early:** Option 3 (direct socket) lets us prove UART+FOSSIL+AT
  emulation over a real Telnet connection with pure Pascal, no driver — the fastest
  path to "a byte typed in the app comes out the socket and back."

## Honest status
This is a DESIGN doc, not code. It defines what replaces Layer B on NT and which
pieces are Pascal. Next concrete step (when ready): implement Layer A's UART/FOSSIL
emulation in Pascal for Option 3 (direct socket), gated by a byte-fidelity test
(all 256 byte values survive app->emulation->socket->emulation->app), reusing the
binary-protocol-safety discipline from fpc264irc.
