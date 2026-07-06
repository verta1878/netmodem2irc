# NetModem/32 v2.0

A 32-bit virtual COM port / FOSSIL driver and Telnet server for classic Windows,
letting DOS and 16-bit BBS door games talk over TCP/IP as if through a modem.

Originally written by **Dedrick Allen** (Allen Software), 1997–2001, and released
under the GNU General Public License v2. This repository preserves his original
driver source and revives the project with a new, open GUI built in Free Pascal /
Lazarus — replacing the proprietary component the original GUI depended on, so the
whole thing can be built from free tools.

> **Credit where it's due.** NetModem/32 is Dedrick Allen's work. This repo exists
> to keep it alive, not to claim it. The driver source here is his, unchanged in
> authorship and copyright, under the GPLv2 he chose for it.

---

## The story

NetModem/32 came out of the late-90s BBS scene, when sysops wanted to keep running
DOS door games and BBS software over the internet instead of dial-up. It works by
emulating modem hardware (a 16550 UART with true FOSSIL services) in a Windows 9x
Ring-0 VxD, while a user-mode server application does the actual WinSock TCP/Telnet
connection and shuttles bytes between the two.

Dedrick released the driver source on the Ecstasy BBS forum (xtcbox.org) in the
early 2000s. Years later those files — and the compiled GUI from the alpha-3
installer — were recovered from a forum database backup and an old setup package,
and reassembled into this repository. One of the maintainers was an alpha / main
beta tester who worked directly with Dedrick developing NetModem on Windows 98 back
in the day. *(More of that history to be added over time.)*

## Repository layout

```
driver/src/     Dedrick Allen's original MASM VxD source (NETMODEM.VXD) — GPLv2
common/         NetModemVxD.pas — Pascal interface to the driver (IOCTL + messages)
server/         Lazarus rewrite of the Telnet server app (was NETMODEM.EXE)
config/         Lazarus rewrite of the configuration app (was NETMODEM.CPL)
docs/           DRIVER_INTERFACE.md, GUI_BLUEPRINT.md, BUILD.md, GitHub walkthrough
docs/original/  Dedrick's original WHATSNEW.TXT / README.TXT / ATCOMNDS.TXT (verbatim)
CHANGELOG.md    Revival history + preserved original release history
LICENSE         GNU General Public License v2
```

## Branches

The project targets two eras, split along the real technical fault line — the
Windows driver model:

* **`9x`** — Faithful revival for **Windows 95 / 98 / ME**. Uses Dedrick's original
  Ring-0 VxD (`NETMODEM.VXD`) plus the new Lazarus GUI. This is the historical
  restoration and runs on real 9x or in a VM (86Box / PCem / VirtualBox).

* **`nt`** — Forward port for **Windows XP through 11**. The VxD cannot load on the
  NT kernel, so this branch pairs the same Lazarus GUI with a user-mode virtual COM
  port bridge (com0com-style) that talks to WinSock — no kernel driver, no driver
  signing required.

The GUI codebase is shared; only the driver/transport layer differs between branches.

## Building

See [`docs/GUI_BLUEPRINT.md`](docs/GUI_BLUEPRINT.md) and the build notes. In short:

* **Driver (9x branch):** MASM 6.14 + Win9x DDK on a Windows 9x host/VM. Assemble
  `NETMODEM.ASM` and link as a VxD using `NETMODEM.DEF`. (Replace `VMM.INC` with the
  clean copy from the DDK — the bundled one is slightly truncated.)
* **GUI (both branches):** Free Pascal / Lazarus. Open the `server/` and `config/`
  projects and compile. The forms are rebuilt from the original layouts documented
  in `docs/GUI_BLUEPRINT.md`.

## Status

Recovery complete; rebuild in progress. The original driver source, the driver
interface spec, and the full original GUI blueprint are all in place. The Lazarus
GUI is being rebuilt against them.

## License

GNU General Public License v2 — see [`LICENSE`](LICENSE). Original driver
Copyright © 1997–2001 Dedrick Allen / Allen Software. New Lazarus GUI and revival
work © the NetModem revival contributors, also under GPLv2.
