# Changelog

## M1 — engine integrated (this update)
- Added the tested emulation engine (engine/): UART, FOSSIL, Telnet transport,
  AT commands, multinode, Synapse + named-pipe links, server bridge.
- NM_ServerBridge wires the engine to the server's CM_* messages and the
  driver TIOStruct byte IO (ServiceDriverIO).
- Bundled Ararat Synapse (libs/synapse/, modified-BSD).
- Preserved Dedrick Allen's original FILE_ID.DIZ (history/).
- Test suite: 11 programs, 0 failures, on FPC 2.6.4 + 3.2.2.
- Retired WIN32COM.PAS to attic/ (ELECOM author-deprecated).
- Full MainForm integration documented (docs/netmodem2irc_M1_COMPLETE.md).


All notable changes to NetModem/32 are recorded here. Format follows
[Keep a Changelog](https://keepachangelog.com/). This file has two parts: the
**revival history** (this repository's work) and the **original release history**
by Dedrick Allen, preserved from the recovered `WHATSNEW.TXT`.

---

## Revival history

### [Unreleased]
Revival of NetModem/32 as an open project buildable entirely from free tools.

#### Added
- Original MASM VxD driver source by Dedrick Allen (GPLv2), recovered from the
  Ecstasy BBS (xtcbox.org) forum database backup where he first released it.
- `common/NetModemVxD.pas` — Free Pascal interface to the driver's IOCTL and
  window-message protocol, reconstructed from the assembly source.
- Lazarus scaffolds for the Telnet server (`server/`) and configuration app
  (`config/`), rebuilt from the decompiled alpha-3 GUI blueprint.
- Documentation: driver interface spec, GUI blueprint, build guide, and a
  GitHub publishing walkthrough.
- Two-branch plan: `9x` (95/98/ME, original VxD) and `nt` (XP–11, user-mode
  com0com bridge — no kernel driver, no driver signing).

#### Changed
- Replaced the proprietary Absolute Solutions ShortcutBar (used by the original
  Delphi GUI) with free Lazarus controls, so nothing proprietary is required.

#### Notes
- Driver and GUI are not yet built into working binaries; that happens on a
  Windows 98 VM (driver) and via Lazarus (GUI). See `docs/BUILD.md`.

---

## Original release history (Dedrick Allen / Allen Software)

*These are the original author's releases, not this repository's. They are
summarized below from his original `WHATSNEW.TXT`, which is itself preserved
verbatim in the repo at [`docs/original/WHATSNEW.TXT`](docs/original/WHATSNEW.TXT)
in the classic BBS format sysops know. This `CHANGELOG.md` is the modern
(Keep a Changelog / GitHub) companion — it does not replace `WHATSNEW.TXT`;
both are kept.*

### [2.0-alpha3] — 2000-05-24
#### Added
- NetFOSSIL/32 v2.0: 32-bit Revision Level 5 FOSSIL driver with SuperSet
  functions (1Ch–21h) per Raymond L. Gwinn.
- More AT commands (see `ATCOMNDS.TXT`).
- Self clean-up code to deallocate resources in a timely, orderly fashion.
- Crash-guard code in the drivers to help prevent crashes and BSODs.
#### Changed
- Configuration utility now allows selecting FOSSIL emulation types.
#### Fixed
- An uploading issue with certain Telnet clients.
- Reconfiguring the drivers and server application from the config app.
- Several Comport/UART emulator problems.
#### Improved
- No longer requires a reboot after reconfiguring NetModem.
- Lower CPU utilization and memory requirements.
- Automatic recovery from connection errors.

### [2.0-alpha2] — 1999-08-30
#### Added
- Update configuration without rebooting (one reboot still needed after initial
  install).
- More AT command support (`ATCOMNDS.TXT`).
- Upload support; download support in the DEMO.
#### Changed
- New installer / uninstaller.
#### Fixed
- 16550 UART emulation problems.
- Echoing of all received characters from the remote end.
- Hardware flow-control problems that would halt I/O.
#### Improved
- DOS applications' CPU use during file transfers.
- Optimized I/O and threading code; general speed increase.

### [2.0-alpha1] — 1999-08-11
- First initial release of v2.0.

---

*A later 2.0 alpha 3 build (the recovered installer, dated 2000-05-24) is the
newest original release located so far. A "beta 4" was mentioned but has not been
found. If it surfaces, its notes belong above the alpha-3 entry.*

## Readability pass (in progress)
- Renamed the seam frame's `Node` field to `NodeIndex` and the handler variable
  `F` to `Frame` (self-explaining: `RingNode(Frame.NodeIndex)`).
- NM_UART16550: parameter/var `U` -> `Uart` consistently; the register record now
  documents all datasheet mnemonics (IER/LCR/LSR/...) once at its definition, and
  RX/TX carry explicit ReceiveRing/TransmitRing names. Datasheet names kept as the
  identifiers (so code matches any UART reference). 23 tests, 0 failures.
