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
- `common/NMVxD.pas` — Free Pascal interface to the driver's IOCTL and
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

## README refreshed
- Status updated to reflect current state: 26 tests (was 11), server+driver sides
  complete, new units listed (seam protocol/sender, TSR skeleton, config/apply).
- Credit, story, and history sections left intact.
- Synapse (modified-BSD, GPLv2-compatible) confirmed as the optional real TCP
  backend (-dHAS_SYNAPSE) and kept bundled.

## Housekeeping: retired superseded duplicate
- Moved netmodem2irc_CREDITS.md (early, shorter credits) to attic/ — superseded by
  the fuller root CREDITS.md, not referenced anywhere.
- Deliberately KEPT in place: docs/original/ (Dedrick's original NetModem docs —
  primary source), referenced milestone docs, history/. attic/README.md logs why.

## Core hardening complete (audit + concrete link)
- NetTransport audit: fixed a latent IAC-doubling bound (was safe only by one slot
  of incidental slack; now explicitly reserves room for the doubled byte). Inbound
  Telnet state machine audited clean (hostile SB/escaped-FF/unknown handled safely).
- NM_ATCommand audit: fixed ParseDial port wrap (Word() cast silently wrapped
  e.g. 70000->4464; now range-checks 1..65535, falls back to default).
- FOSSIL audit (earlier this cycle): Fn 06h DTR both directions; Fn 18h/19h block
  I/O implemented; Fn 1Bh GET_INFO wired to fill the struct; Fn 0Fh flow control
  honest return.
- NM_ServerLink: concrete TServerLink — TLoopbackServerLink (host-testable, real
  link object for the full driver<->server loop) + TSynapseServerLink (real TCP,
  HAS_SYNAPSE). Driver now proven against a real transport, not just a fake.
- Whole byte path audited end to end: door -> FOSSIL -> seam -> transport -> wire.
- 33 tests, 0 failures (FPC 2.6.4 + 3.2.2). Pascal core complete and airtight.

## Config format decision: text file is canonical
- netmodem2irc standardizes on a plain TEXT config file (node <index> <host>
  <port>), parsed + validated by NM_Config (tested). Chosen over the registry
  because newer Windows adds registry access-flag/ACL complexity (WOW64
  redirection, UAC virtualization) that a text file avoids — the text format works
  identically from NT4 onward, is portable, and is directly inspectable by a sysop.
- The original NETMODEM.CPL used HKLM\Software\Allen Software\NetModem. Registry
  mirroring (for the original IOCTL-03 reload behavior) may be added LATER, once
  the text-file path is fully tested. Text file is the source of truth.
- Added design-stage i8086 TSR scaffolds (NM_Int14ISR, NM_TSRResident) + the
  M2/NT4 build runbook and CPL config design docs. 33 tests, 0 failures.
