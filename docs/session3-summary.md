# Session 3 Summary — 2026-07-28

## Transcript
/mnt/transcripts/2026-07-28-15-15-14-netmodem2irc-session3-docs-serial-openolms.txt

## Projects Touched
- netmodem2irc (verta1878/netmodem2irc)
- OpenOLMS (verta1878/OpenOLMS)
- mterm (terminal + MOLMS offline mail client)
- serial v1.1 (serial + IRQ + FOSSIL driver)
- fpc264irc (verta1878/fpc264irc — verified, not modified)

## Team
verta1878 (lead), sysop/0 (compiler), kiddo (serial IRQ, protocols), wrench (docs/arch/OpenOLMS), evga (RIPView/Mystic)

---

## netmodem2irc

### Code Created
- dos/driver/serial.pas (203 lines) — sysop/0's real 16550 UART
- dos/driver/serial_irq.pas (195 lines) — kiddo's ISR + 4KB ring buffer
- dos/driver/fossil.pas (398 lines) — FOSSIL dispatch FSC-0015/0072
- dos/driver/netfosdl.pas (323 lines) — INT 14h hook, Keep, X00 params

### Decisions
- [DECISION] netfosdl based on Dedrick Allen's spec + X00 command line
- [DECISION] serial_irq.inc → serial_irq.pas (interrupt procs can't nest)
- [DECISION] X00-compatible params: /P:N /B:N alongside /port /baud /irq /fifo /nofifo
- [DECISION] driver/src (16 files) and libs/synapse (18 files) were missing from GitHub — now fixed
- [DECISION] M2 verified: dual-compiler (fpc264irc 2.6.4 + FPC 3.2.2), 18/18 units compile, NMServer links

### M2 Results
- FPC 2.6.4irc: engine (14) ✅, common (2) ✅, Win32 PE32 linking ✅
- FPC 3.2.2 + Lazarus 3.0: all 18 units ✅, NMServer links (5.1M ELF) ✅
- 6 warnings — all in Synapse (upstream deprecations), 0 in our code
- Win32 GUI binary: sysop/0 rebuilding LCL on his tree (lazbuild)

### Milestone Status
| Phase | Status |
|-------|--------|
| M0-M1 Engine + tests | ✅ 38 pass |
| M2 Builds on Windows | ✅ VERIFIED dual-compiler |
| M3 Live connection | ⬜ next |
| D1 Real 16550 UART | ✅ serial.pas |
| D2 FOSSIL function set | ✅ fossil.pas |
| D3 INT 14h + Keep | ✅ netfosdl.pas |
| D4 Conformance testing | ⬜ needs 386 |
| R1.1-R1.4 NM_Debug | ✅ |
| R1.5-R1.6 Debug panel GUI | ⬜ |
| R2.1-R2.5 Setup.exe AV | ⬜ |
| Inno 1-8 | ✅ |

### Docs Updated
- README.md — dos/driver/ layout, D1-D3 done, netfosdl status
- ROADMAP.md — D1-D3 marked done
- docs/index.htm — regenerated from GitHub clone, 74 docs, 29 phases, verified dirs

---

## OpenOLMS (verta1878/OpenOLMS)

### What It Is
Clean-room GPLv3 reimplementation of Peter Rocca's OLMS (Offline Mail System, 1994-1998). No original source code used. With author's permission.

### Source: 37 units, ~12,400 lines, 5 programs

#### Door (olms.exe, 276K go32v2) — v0.4, verta1878's code
25 olms_* units, 4,605 lines. Full round trip: dropfile, JAM+Hudson, QWK/QWKE/BlueWave, filtering, pointers, archiver, REP, files, networking, taglines, vacation, logging, multi-language. Config editor (config.exe, 237K) all 12 screens. SDL backend.

#### MOLMS (molms.exe, 442K Win32 FV) — v0.5, wrench's code
742 lines. Offline mail client: connect BBS via Telnet/Serial/FOSSIL, auto-login, Auto Mail Run, Zmodem download QWK, read offline, compose replies with spell check, upload REP. BBS address book. ANSI/RIP rendering.

#### Other Programs
- openolms_dos.exe (336K go32v2) — pure ANSI door
- olmsmnt.exe (129K go32v2) — CLI maintenance

### Shared Library (created this session)
- OL_QWK.pas (259) — QWK 128-byte blocks, CONTROL.DAT, NDX
- OL_Config.pas (176) — OLMS.CFG config records
- OL_DropFile.pas (275) — DORINFO1.DEF + DOOR.SYS parser
- OL_MsgCtl.pas (195) — MESSAGES.CTL 64-byte records
- OL_Users.pas (141) — per-user settings, pointer reset
- OL_Hudson.pas (328) — Hudson message base reader
- OL_JAM.pas (425) — JAM message base + CRC-32
- OL_Packer.pas (423) — QWK packer + REP unpacker
- OL_Filter.pas (275) — keyword filtering + twit list
- OL_BlueWave.pas (199) — BlueWave packet format
- OL_Transfer.pas (281) — auto connect/login/door/Zmodem bridge
- OL_Editor.pas (229) — reply editor, word wrap, quoting, spell check
- mt_spell.pas (134/179) — Hunspell dynamic loader
- OL_ANSI.pas (244) — pure DOS ANSI console
- OL_MDL.pas (225) — Mystic MDL interface stub

### Ported from mterm
- mtterm.pas (419) — ANSI CSI/SGR parser, scrollback
- mtrip.pas (267) — RIPscrip v1.54 dispatcher
- mtripgfx.pas (409) — 640×350 EGA pixel canvas
- mtconn.pas, mtserial.pas, mtphone.pas, mtxfer.pas, mtcapture.pas, mtconfig.pas
- m_prot_base.pas, m_prot_zmodem.pas (Int64 fix), m_protocol_xmodem/ymodem/kermit, m_protocol_queue.pas, m_crc.pas

### Docs Updated (all for v0.5)
- STATUS.md — 37 units, 5 programs
- CHANGELOG.md — v0.1-v0.5 complete history
- CREDITS.md — full team, kiddo credited for protocols (not g00r00)
- AUTHORS — team + specs + credits
- TODO.TXT — MOLMS items added
- INSTALL.TXT — MOLMS build/install
- WHATSNEW.TXT — v0.1-v0.5 (root + docs/ synced)
- gap_analysis.md — MOLMS section added
- LICENSE — GPLv3 with team copyright

### License Decisions
- [DECISION] Original OLMS: proprietary shareware, $25, 45-day trial
- [DECISION] OpenOLMS: GPLv3, clean-room from published docs
- [DECISION] No "pending license" language — removed everywhere
- [DECISION] Protocol code credited to kiddo, NOT g00r00
- [DECISION] g00r00 credited for Mystic BBS UI components only
- [DECISION] Headers: "GPLv3 — Copyright (C) 2026 verta1878, sysop/0, wrench, kiddo, evga"
- [DECISION] Mystic BBS is GPLv3 (confirmed: FIDOSOFT/mysticbbs on GitHub)

---

## mterm

### What It Is
DOS-first RIP/ANSI terminal emulator + MOLMS offline mail client.

### Files: 33 Pascal files, 11,721 lines, 3 binaries

### New This Session
- mtripgfx.pas (409) — RIP graphics pixel engine (NEW)
- keytest.pas (144) — keyboard test tool (NEW)
- mterm.pas — expanded Connect menu (Telnet/Serial/FOSSIL/Local), Ctrl-key binds
- mtphone.pas — default phonebook (Cosmo Castle RIP, Fluph BBS ANSI)
- mtterm.pas — view not selectable (keys route to app first)
- OL_Transfer.pas (281) — connection/Zmodem/QWK bridge (NEW)
- molms.pas (742) — full MOLMS client with real connections (REWRITTEN)
- MANUAL.md (180) — complete user manual (NEW)

### Binaries
- mterm.exe (430K Win32)
- molms.exe (442K Win32)
- keytest.exe (141K Win32)

---

## Packages Released

| Package | Size | What |
|---------|------|------|
| netmodem2irc-repo-20260726-FINAL.zip | 18M | Full repo, verified dirs |
| serial-v1_1-irq.zip | 15K | For kiddo + sysop/0 |
| openolms-repo-v05.zip | 1.8M | Full OpenOLMS repo for GitHub |
| openolms-complete.zip | 1.5M | Standalone release |
| mterm-v01-serial11.zip | 482K | mterm + serial + OLMS + binaries |

---

## Pending / Next Session

- M3 live Telnet connection — the milestone that makes it real
- D4 conformance testing — needs the 386
- R1.5-R1.6 debug panel GUI (TMemo)
- R2 Setup.exe + ISCmplr AV fix
- sysop/0 rebuilding LCL for Win32 (lazbuild)
- mterm ANSI/RIP editor viewer — verta1878 testing, will upload when done
- Wire mterm ANSI/RIP viewer into MOLMS message display
- MOLMS reply composer → full FV multi-line editor
- MOLMS search by keyword/sender/subject
- Peter Rocca's license preference response
- fpc264irc: FIONREAD + UDP + BuildDNSQuery

## Key Quotes
- sysop/0: "Nice repo. Clean-room reimplementation, Peter Rocca's permission, 37 units, 28 commits. Now let me rebuild LCL for Win32"
- verta1878 on Mystic: "openssl i think mystic was flatted now it need gplv3 license" → confirmed: Mystic BBS is GPLv3
