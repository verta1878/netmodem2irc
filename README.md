# netmodem2irc

Revival of Dedrick Allen's **NetModem/32** (32-bit FOSSIL Telnet server, 1997-2001)
for modern Windows, with a portable, tested Pascal modem-emulation engine.

## Status: server + driver sides complete and tested (sandbox)

Both the server side and the driver side are built and tested in Pascal. The
emulation engine, server bridge, FOSSIL driver logic, driver<->server seam
protocol (both directions), the TSR resident-program skeleton, and per-node
configuration are all done and covered by tests:
**34 test programs, 0 failures, verified on stock FPC 2.6.4 and FPC 3.2.2.**

Remaining work is outside the pure-Pascal core: the Windows/Lazarus GUI build (M2).
The i8086 DOS FOSSIL↔TCP bridge (netfossl.exe) is built and linked — see dos/.

```
engine/        the emulation engine (Pascal) — UART, FOSSIL, Telnet transport,
               AT commands, multinode (switch-style), Synapse + named-pipe links,
               server bridge, driver<->server seam protocol + sender, TSR
               skeleton, per-node config
engine/test/   the test suite (run: sh engine/test/run-tests.sh)
libs/synapse/  bundled Ararat Synapse (modified-BSD, GPLv2-compatible)
server/        Lazarus GUI (LCL) — wire per docs/netmodem2irc_M1_COMPLETE.md
config/        Lazarus config tool
common/        driver interface (NMVxD, TIOStruct, CM_* messages)
dos/           i8086 DOS FOSSIL↔TCP bridge (netfossl.exe, fpcirc cross-compile)
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
- **NM_ServerBridge** — wires the engine to the server's CM_* + TIOStruct IO;
  switch-style node servicing (services active nodes, not a full-slot sweep)
- **NM_SeamProtocol / NM_SeamSender** — the driver<->server seam: framed,
  binary-clean, node-addressed messages; sender wraps driver activity into frames
- **NM_TSR** — the FOSSIL TSR resident-program skeleton (Startup/Pump/Shutdown),
  wiring UART + FOSSIL dispatch + seam sender; i8086 fills in the real-mode wrapper
- **NM_Config / NM_ConfigApply** — per-node comport/host/port config: parse,
  validate (bounds-checked), and apply to the server

### Build (GUI) — Lazarus 1.2.6 + LCL
Add engine/ and libs/synapse/ to the project unit path. Build the server with
`-dHAS_SYNAPSE` for real sockets. See **docs/netmodem2irc_M1_COMPLETE.md** for the
exact MainForm wiring, and **docs/BUILD.md** for the original build notes.

### Roadmap
M1 (engine integrated) DONE. Driver side (seam + TSR skeleton) and config: DONE,
tested. DOS i8086 FOSSIL↔TCP bridge (netfossl.exe): DONE, linked. Next: M2
(builds on Windows/Lazarus), M3 (it connects — live Telnet session), M4 (virtual
COM: Option A driver), M5 (installer + release).
See **docs/netmodem2irc_RELEASE_ROADMAP.md**.

### Honest status
The Pascal core (engine, bridge, switch, seam both directions, TSR skeleton,
config) is tested — compile + behavior — on FPC 2.6.4 and 3.2.2. The full
driver<->server seam loop is proven end to end with a fake link. The DOS i8086
FOSSIL↔TCP bridge (dos/netfossl.exe, 179KB) is built and linked via the fpc264irc
cross-compiler. The Synapse networked path is optional (-dHAS_SYNAPSE) and
compile-verified but needs a live runtime test. What remains: the Windows/Lazarus
GUI build and live testing on real DOS/DOSBox. The 9x VxD (driver/src) is Dedrick's
original, experimental.

---

# NetModem/32 v2.0

A 32-bit virtual COM port / FOSSIL driver and Telnet server for classic Windows,
letting DOS and 16-bit BBS door games talk over TCP/IP as if through a modem.

Originally written by **Dedrick Allen** (handle **mag69**, Allen Software),
1997–2001, who gave the source to this project's maintainer (a NetModem beta
tester) to carry forward. Released
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
common/         NMVxD.pas — Pascal interface to the driver (IOCTL + messages)
server/         Lazarus rewrite of the Telnet server app (was NETMODEM.EXE)
config/         Lazarus rewrite of the configuration app (was NETMODEM.CPL)
dos/            i8086 DOS FOSSIL↔TCP bridge (netfossl.exe, fpcirc cross-compile)
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

## Configuration

netmodem2irc is configured with a plain text file, one node per line:

    node 3 bbs.example.com 23
    node 4 chat.example.org 6667

`NM_Config` parses and validates it (node index 0–99, port 1–65535, host
non-empty; bad lines rejected). Text is the canonical config format — it avoids the
registry access-flag/ACL complexity of newer Windows and works identically from
NT4 onward. A Lazarus config utility (config/, rebuilt from Dedrick's original
NETMODEM.CPL) provides a GUI; a Control Panel (.cpl) applet is planned (see
docs/netmodem2irc_cpl_config_design.md). Registry mirroring may be added later,
once the text path is fully tested.
