# netmodem2irc

Revival of Dedrick Allen's **NetModem/32** (32-bit FOSSIL Telnet server, 1997-2001)
for modern Windows, with a portable, tested Pascal modem-emulation engine.

## Status: M1 COMPLETE — engine integrated

The tested emulation engine is wired into the server. Full data path
(CM_* messages + driver TIOStruct byte-glue) is built and TESTED:
**11 test programs, 0 failures, verified on stock FPC 2.6.4 and FPC 3.2.2.**

```
engine/        the emulation engine (Pascal) — UART, FOSSIL, Telnet transport,
               AT commands, multinode, Synapse + named-pipe links, server bridge
engine/test/   the test suite (run: sh engine/test/run-tests.sh)
libs/synapse/  bundled Ararat Synapse (modified-BSD, GPLv2-compatible)
server/        Lazarus GUI (LCL) — wire per docs/netmodem2irc_M1_COMPLETE.md
config/        Lazarus config tool
common/        driver interface (TNetModemDriver, TIOStruct, CM_* messages)
driver/src/    Dedrick's original 9x VxD source (experimental branch)
history/       Dedrick's original FILE_ID.DIZ + facts
attic/         retired files (kept, not deleted)
docs/          engineering docs, specs, milestone, roadmap
```

### Engine (tested)
- **NM_UART16550** — 16550 UART emulation
- **NM_Fossil** — FOSSIL INT 14h (init signature $1954)
- **NetTransport** — Telnet transport, IAC/BINARY, binary-safe (0xFF via IAC IAC)
- **NM_ATCommand** — Hayes AT, ATDT<host> dial
- **NM_Node** — per-node object + multinode manager (comports 3-99, as the original)
- **NM_SynapseLink** — real Synapse TCP socket link (compile-verified)
- **NM_NamedPipeLink** — named-pipe link (virtual-COM driver seam)
- **NM_ServerBridge** — wires the engine to the server's CM_* + TIOStruct IO

### Build (GUI) — Lazarus 1.2.6 + LCL
Add engine/ and libs/synapse/ to the project unit path. Build the server with
`-dHAS_SYNAPSE` for real sockets. See **docs/netmodem2irc_M1_COMPLETE.md** for the
exact MainForm wiring, and **docs/BUILD.md** for the original build notes.

### Roadmap
M1 (engine integrated) DONE. Next: M2 (builds on Windows), M3 (it connects —
live Telnet session), M4 (virtual COM: Option A driver), M5 (installer + release).
See **docs/netmodem2irc_RELEASE_ROADMAP.md**.

### Honest status
The emulation engine is tested (compile + behavior). The Synapse networked path
and named-pipe real I/O are compile-verified but need a Windows runtime test.
The 9x VxD (driver/src) is experimental (needs the DDK + 9x linker work).

---

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
