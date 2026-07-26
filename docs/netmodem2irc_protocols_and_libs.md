# netmodem2irc — Protocols and Libraries Reference

One-stop reference for every protocol and library this project
implements, wraps, or depends on. Each entry says what the spec is,
where our implementation lives, and what milestone it applies to.

---

## Protocols we implement

### FOSSIL — FidoNet FSC-0015 rev 5 + FSC-0072

The serial driver API that DOS BBS software calls via INT 14h.
NetModem/32's entire reason to exist.

| | |
|---|---|
| Spec | FidoNet FSC-0015 (FOSSIL rev 5), FSC-0072 (extended) |
| Our implementation | `engine/NM_Fossil.pas` (function set), `engine/NM_FossilDriver.pas` (dispatch) |
| DOS driver (planned) | `netfosdl.exe` — standalone, real UART, FTSC-compliant |
| Init signature | `$1954` in AX on Fn $04 INIT |
| Conformance bar | drop-in for X00, BNU, ADF, NetFoss |
| Cross-validation | `docs/netmodem2irc_FOSSIL_crossvalidation.md` — verified against ELECOM FOS_COM |
| Milestones | M1 ✅ (engine tested), D2–D4 ⬜ (DOS driver) |
| Key docs | `netmodem2irc_fossil_separation.md`, `netmodem2irc_FOSSIL_driver_scoping.md`, `netmodem2irc_LAYER_A_SPEC.md` |

### NS-16550 UART

The register file the FOSSIL layer sits on. Two implementations: one
emulated for the virtual comport, one real for the DOS driver.

| | |
|---|---|
| Spec | National Semiconductor NS-16550 / NS-16550A datasheet |
| Registers | RBR, THR, IER, IIR, FCR, LCR, MCR, LSR, MSR, DLL, DLM |
| Emulated (i386) | `engine/NM_UART16550.pas` — pure logic, no I/O, no OS calls |
| Real (DOS, planned) | Phase D1 — port I/O at `$3F8`/`$2F8`/`$3E8`/`$2E8`, IRQ 3/4, 8259 PIC |
| Milestones | M1 ✅ (emulated, 14 tests), D1 ⬜ (real hardware) |
| Key docs | `netmodem2irc_LAYER_A_SPEC.md`, `netmodem2irc_DRIVER_MAP.md` §4 |

### Hayes AT command set

The modem command language. `ATDT host:port` is how a BBS dials out.

| | |
|---|---|
| Spec | TIA-602 (Hayes AT), extended with `ATDT host:port` for TCP |
| Our implementation | `engine/NM_ATCommand.pas` — parser + state machine |
| Milestones | M1 ✅ (parser tested, 12 tests), M3 ⬜ (live dial-out) |
| Key docs | `netmodem2irc_LAYER_A_SPEC.md`, `docs/original/ATCOMNDS.TXT` |

### Telnet (RFC 854 / 855 / 856 / 857)

The transport protocol. NetModem bridges FOSSIL to Telnet.

| | |
|---|---|
| Spec | RFC 854 (Telnet), RFC 855 (option negotiation), RFC 856 (BINARY), RFC 857 (ECHO) |
| Our implementation | `engine/NetTransport.pas` — IAC handling, BINARY mode, binary-safe |
| Cross-validation | `docs/netmodem2irc_TELNET_crossvalidation.md` — verified against ELECOM TELNET |
| Binary safety | critical — CP437 art and Zmodem must survive. IAC `$FF` must be doubled. |
| Milestones | M1 ✅ (12 tests), M3 ⬜ (live connection) |
| Key docs | `netmodem2irc_transport_audit.md` (found: outbound IAC-doubling was missing) |

### SEAM protocol

The framed binary protocol between the driver/TSR and the server.
Custom to NetModem, designed for the project.

| | |
|---|---|
| Spec | `docs/netmodem2irc_SEAM_protocol.md` (the spec IS the doc) |
| Our implementation | `engine/NM_SeamProtocol.pas`, `engine/NM_SeamSender.pas` |
| Frame format | `$A5` sync + length-prefixed, binary-clean |
| Milestones | M1 ✅ (tested), M3 ⬜ (live over a real link) |
| Key docs | `netmodem2irc_SEAM_protocol.md`, `netmodem2irc_overflow_audit.md` (found: LEN overflow) |

### Win9x VxD IOCTL / CM_* messages

The driver↔server boundary on Windows 9x.

| | |
|---|---|
| Spec | Dedrick's design — `NETMODEM.INC` defines the constants |
| Our implementation | `common/NMVxD.pas` (IOCTL codes + `ComportStruct`), `common/NetModemVxD.pas` |
| IOCTL codes | `$00`–`$10` (see `DRIVER_INTERFACE.md` §4.3) |
| Messages | `CM_CONNECT`, `CM_DISCONNECT`, `CM_BREAK`, etc. |
| Milestones | M4 ⬜ (virtual COM path) |
| Key docs | `DRIVER_INTERFACE.md`, `netmodem2irc_DRIVER_MAP.md`, `netmodem2irc_config.md`, `netmodem2irc_registry.md` |

---

## Libraries we use

### Ararat Synapse — TCP/IP wrapper (i386 only)

| | |
|---|---|
| Author | Lukas Gebauer |
| License | modified BSD — compatible with GPLv2 and GPLv3 |
| Upstream | `github.com/geby/synapse` |
| Bundled in | `libs/synapse/` (17 files, 720K) |
| What we use | `TTCPBlockSocket` from `blcksock.pas` via `engine/NM_SynapseLink.pas` |
| What we don't use | `synaser.pas` (serial), `smtpsend.pas` (placeholder for mailing list server) |
| Build guard | `-dHAS_SYNAPSE` — without it, builds to a stub returning nil |
| **Synapse is NOT a TCP stack** | it wraps WinSock / BSD sockets. The OS runs the protocol. |
| Milestones | M1 ✅ (compile-verified), M3 ⬜ (runtime over a live connection) |
| Key docs | `docs/netmodem2irc_synapse.md` (file-by-file), `THIRD_PARTY.md` |

### ELECOM — comms library (reference only)

| | |
|---|---|
| Author | Maarten Bekers (EleBBS) |
| License | freeware, ELECOM terms — credit and send changes back |
| Status | **reference, not linked**. Used to cross-validate our FOSSIL and Telnet. |
| Files in repo | `attic/WIN32COM.PAS` (retired unit) |
| Cross-validation | `FOS_COM.PAS` tested against our `NM_Fossil` — 9/9 pass |
| Key docs | `netmodem2irc_FOSSIL_crossvalidation.md`, `netmodem2irc_TELNET_crossvalidation.md`, `elecom_modernization.md` |

### com0com — virtual COM port (NT family)

| | |
|---|---|
| Author | Vyacheslav Frolov |
| License | GPLv2 — any fork stays GPLv2 |
| Status | **external dependency, not bundled**. Provides virtual COM pair on NT/2K/XP–Win11. |
| Open questions | GPLv2 fork licensing, Win9x `.inf` is NT-only |
| Milestones | M4 ⬜ |
| Key docs | `netmodem2irc_com0com_notes.md`, `netmodem2irc_com2tcp_findings.md` |

### FPC 2.6.4irc (fpc264irc) — the toolchain

| | |
|---|---|
| Author | sysop/0 |
| What it is | Patched Free Pascal 2.6.4 fork — the shipping compiler |
| Why not stock FPC | Win98 LCL patches, `Ctl3D`/`ParentCtl3D`, `OEMConvert`, 3-param `paswstring`, pure Pascal DOS sockets |
| PPU counts | 619 i386-win32, 113 i8086-msdos |
| Smart linking | 100% — zero pre-compiled binary blobs |
| Dual-compiler policy | every unit must compile under both fpc264irc and FPC 3.x |
| Key docs | `ROADMAP.md` (dual-compiler policy), `BUGS.md` |

### FPC 3.2.2 — the verification compiler

| | |
|---|---|
| What it is | Stock Free Pascal, the syntax/logic check |
| Why both | two compilers with different strictness catch different bugs |
| Limitation | Lazarus 2.2.6 calls Unicode Win32 APIs absent on Win9x without MSLU — binaries are NOT shippable to Win98 |
| Binaries | ~20MB vs fpc264irc's ~3.6MB — useful as verification only |

---

## Milestone coverage

| Protocol/Lib | M0 | M1 | M2 | M3 | M4 | M5 | D1–D4 |
|---|---|---|---|---|---|---|---|
| FOSSIL | | ✅ tested | | ⬜ live | | | ⬜ DOS real UART |
| 16550 UART | | ✅ emulated | | | | | ⬜ real hardware |
| Hayes AT | | ✅ parser | | ⬜ dial | | | |
| Telnet | | ✅ tested | | ⬜ live | | | |
| SEAM | | ✅ tested | | ⬜ live | | | |
| VxD IOCTL | | | | | ⬜ | | |
| Synapse | | ✅ compile | ⚠️ | ⬜ runtime | | | |
| com0com | | | | | ⬜ | | |
| fpc264irc | ✅ | ✅ | ⚠️ | | | | ⬜ DOS |

---

## See also

- `ROADMAP.md` — master roadmap, order of work
- `netmodem2irc_LAYER_A_SPEC.md` — the detailed spec map
- `netmodem2irc_DRIVER_MAP.md` — functional map of Dedrick's ASM
- `docs/original/` — Dedrick's own documentation
