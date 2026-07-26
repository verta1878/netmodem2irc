# FOSSIL Code Separation and Output Layout

Written 2026-07-25.

netmodem2irc contains **two different pieces of FOSSIL code** that are
easy to confuse because both are called "the FOSSIL driver". They face
opposite directions and must not share a directory or a build output
path.

## Names — read this first

Three programs, three names. They have been confused for each other
throughout this project's history.

| Name | Platform | Role | Network |
|---|---|---|---|
| **`netfosdl.exe`** | DOS, i8086 | FOSSIL driver — answers INT 14h over a **real UART** | **none** |
| **relay** | DOS, i8086 | moves bytes between real UARTs, direct port I/O | **none** |
| **`netfossl`** | Win32 / i386 | FOSSIL backed by **com0com + Synapse** | TCP |

**DOS and i386 are independent platforms, not stages of one pipeline.**
DOS solves the problem with real hardware and no network. i386 solves it
with a virtual comport and a socket. Neither feeds the other.

`netfosdl` — **d** for driver — is the DOS one. It is **standalone**:
not part of netmodem, no `NM_*` units, no SEAM protocol, no server link,
no registry config. A DOS BBS loads it and calls INT 14h, exactly as it
would load X00 or BNU. It links against `ppcross8086` and four RTL units
and nothing else.

`netfossl` is the Win32 side, where com0com provides the virtual comport
and Synapse provides TCP.

> **Collision resolved 2026-07-25.** `dos/bin/netfossl.exe` (the old
> 197K Watt-32 relay) has been removed. The `netfossl` name is now free
> for the Win32 program. The old binary is recoverable from git history
> if ever needed.

## The two FOSSIL code paths

Both **answer** INT 14h. Both are FOSSIL *providers*. The difference is
what sits underneath the FOSSIL layer: real hardware, or emulation.

| | Answers INT 14h | Sits on | Where |
|---|---|---|---|
| **DOS FOSSIL driver** (netfosdl) | yes | a **real UART** — 16550 hardware, port I/O. No TCP/IP. | `dos/` |
| **Virtual comport FOSSIL** | yes | an **emulated UART** — `NM_UART16550` | `engine/` |

### 1. DOS FOSSIL driver — `netfosdl.exe`

Real mode, i8086, 16-bit MZ binary.

netfosdl **answers** INT 14h. A DOS BBS or door issues `INT 14h`,
netfosdl services it, and the bytes move through a real 16550 UART.
This is the NetFoss-shaped role: netfosdl *is* the resident FOSSIL
driver, not a caller of one.

```
DOS BBS / door ──INT 14h──> netfosdl ──> real 16550 UART
                            (provides FOSSIL)
```

That is the entire DOS path. Nothing downstream of the UART belongs to
this platform.

### No TCP/IP

**netfosdl needs no TCP/IP stack.** It answers INT 14h and drives a real
16550. It does not open sockets, resolve names, or speak to a packet
driver.

That drops the entire mixed-link apparatus the current `dos/` build
carries:

| Dropped | What it was for |
|---|---|
| `wattcpwl.lib` (382K) | Watt-32 DOS TCP/IP stack |
| `clibl.lib` | Watcom C runtime, large model |
| `emu87.lib` | FPU emulation for the C library |
| `stubs.asm` | filler for symbols neither toolchain provided (`main_`, `_EFG_Format_`, `__cnvs2d_`, RTTI slots) |
| OMF fixups | `fixasm.py` + `nasm -f obj`, needed only to meet Watcom's object format |
| `omfinfo.py` dependency walk | resolving OMF archives |

What remains is `ppcross8086` plus the msdos RTL — `system`, `dos`,
`strings`, `objpas`. Port I/O, an IRQ handler and `Keep` are all plain
real-mode Pascal. No foreign toolchain, no foreign object format.

Note the naming trap: `dos/netmodem.pas` declares its socket calls as
`fpcirc_tcp_open`, `fpcirc_sock_read` and so on, but every one binds to
`external name '_w32_*'` — Watt-32 symbols. There is no separate "fpcirc
TCP/IP" stack; that name is a Pascal wrapper over Watt-32. FPC's
i8086-msdos `sockets` unit compiles but has no backend, as recorded in
`dos/fpc-sockets-request.md`.

### Standard and compatibility

netfosdl implements the **FTSC FOSSIL standard** — FidoNet FSC-0015
(FOSSIL rev 5) and FSC-0072. It is not a new interface; it is the same
documented API that DOS BBS software has called since the late 1980s.

It must be a **drop-in replacement** for the established FOSSIL drivers:

| Driver | Environment |
|---|---|
| **X00** | the reference DOS FOSSIL |
| **BNU** | DOS FOSSIL |
| **ADF** | DOS FOSSIL |
| **NetFoss** | Win32 FOSSIL for DOS BBS software |

The compatibility bar is behavioural, not merely structural: a BBS or
door that works against X00 must work against netfosdl without being
rebuilt, recompiled or reconfigured. That means the full documented
function set, the `$1954` init signature, the FSC-0015 status-word bit
layout, and the same semantics for the extended functions — not just
the subset the current code happens to exercise.

Conformance is measurable. `docs/netmodem2irc_FOSSIL_crossvalidation.md`
already establishes the method: answer an independent, period-correct
FOSSIL client's exact calls with the exact responses it expects.

### 2. Virtual comport FOSSIL — engine units

Same FOSSIL function set, no hardware beneath it.

`engine/NM_Fossil.pas` is a user-mode re-creation of the Rev.5 FOSSIL +
X00-superset services that Dedrick Allen's VxD dispatched through
`Int14_Table` in `NETMODEM.ASM`. It implements those services on top of
`NM_UART16550`, which is pure emulation — the unit states outright that
it has no OS calls, no sockets and no I/O ports. The TX/RX rings are
drained to a socket by the transport layer.

On NT there is no INT 14h trap, so the register model is a synthetic
frame (`TFossilRegs`) rather than real CPU registers; the virtual COM
layer or door shim calls `FossilDispatch` with a filled-in frame.

```
DOS door ──> virtual COM / shim ──> FossilDispatch ──> NM_UART16550
                                                       (emulated)
                                                            │
                                                       transport ──> socket
```

| Unit | Role |
|---|---|
| `NM_Fossil.pas` | FOSSIL function set, `FossilDispatch`, `FossilGetInfo` (Fn 1Bh) |
| `NM_FossilDriver.pas` | INT 14h register-frame dispatch |
| `NM_Int14ISR.pas` | `InstallInt14` / `RemoveInt14` — real vector hook, DOS build only |
| `NM_TSRResident.pas` | `Install` / `Pump` / `Unload` |
| `NM_TSR.pas` | resident-program skeleton |
| `NM_UART16550.pas` | the emulated 16550 the provider sits on |

### The legacy client in `dos/` — superseded

`dos/fossil_dos.pas` as it stands today is **not** a provider. It is a
FOSSIL *client*: every routine goes through `Intr($14, R)`, and it
contains no port I/O whatsoever. It expects X00, BNU or NetFoss to
already be resident, and consumes their services.

That is the opposite shape from what netfosdl is for, and it is the
source of the naming confusion this document exists to end. It is
superseded by the DOS FOSSIL driver work described above.

Verified 2026-07-25 by inspection: `fossil_dos.pas` contains 14 `Int14`
call sites and zero `inportb`/`outportb`/port constants.

## Why they must stay separate

They answer INT 14h for different machines. One drives real 16550
hardware in real mode; the other drives an emulated register file in a
user-mode process with a socket behind it. Sharing a directory invites a
build that links both into one binary, where two INT 14h providers would
either fight for the vector or silently shadow each other.

The superseded client in `dos/fossil_dos.pas` makes this sharper still:
link a client and a provider together and the program ends up calling
INT 14h into its own handler.

There is also an **unresolved architectural gap** worth recording here:
the provider units above are complete and tested, but they are *not
wired to netfossl*. `NM_Int14ISR.pas` already carries the real vector
hook and is marked DOS-build-only, yet it lives in `engine/` alongside
the NT-branch emulation — so the DOS provider machinery and the DOS
program that needs it are currently in different trees.

`FossilDispatch` already runs against an emulated `TUart16550` with
TX/RX rings, and the FOSSIL function set above it is target-independent.
For netfosdl the same dispatch sits on a real 16550 instead — the UART
layer is the substitution point. Wiring netfosdl to these units means
routing that layer to hardware port I/O rather than to the emulated
register file.

The i8086 real-mode target supports residency directly: the 16-bit msdos
RTL provides `Keep`, which is what a TSR FOSSIL driver needs. See
`docs/netmodem2irc_TSR_skeleton.md` and
`docs/netmodem2irc_i8086_TSR_finish_guide.md`.

## Output layout

Build products are separated by target architecture, one directory per
architecture. Nothing is shared.

```
out/
├── i386/     32-bit protected mode
├── dos/      16-bit real mode, i8086 — netfosdl.exe (FOSSIL driver)
└── win32/    i386-win32 PE — NMServer.exe, NMConfig.exe, NETMODEM.CPL, *.res
```

| Directory | Target | Contents |
|---|---|---|
| `out/dos/` | i8086 real mode, MZ | `netfosdl.exe` — DOS FOSSIL driver, real UART |
| `out/i386/` | i386-win32, PE | `NMServer.exe`, `NMConfig.exe`, `NETMODEM.CPL`, `NMServer.res`, `NMConfig.res` |
| `out/i386/` | i386 | *see open question below* |

The Inno Setup port keeps its own output in `InnoIRC561/out/` and is
not merged into `out/`. It is a separate toolchain with its own build
recipe.

### `out/i386/` — resolved

Contains the i386-win32 PE binaries: NMServer.exe, NMConfig.exe,
NETMODEM.CPL and .res files. `out/dos/` and `out/i386/`
are unambiguous; `i386` overlaps with `win32`, since the Win32 binaries
are already i386. Candidates:

1. Linux-native i386 builds of the engine test suite
2. i386 protected-mode builds, if any target ever needs them
3. A rename of `win32/`, making the split arch-only rather than
   arch+OS

Left empty with a `.gitkeep` until decided.

## Build script changes required

`dos/build.sh` previously copied to `dos/bin/netfossl.exe`, which has
been removed. The build script references a path that no longer exists
and is broken until Phase 5.

`build.sh` already writes Win32 output to `out/i386/` via `-FEout/i386`
and needs no change there, but two things do need attention:

- `build.sh clean` does `rm -rf out/`. If `netfossl.exe` moves from
  `dos/bin/` into `out/dos/`, clean will delete a tracked binary. Either
  stop tracking it or exclude `out/dos/` from clean.
- The `find` exclusion list in `build.sh` still references
  `./dos/bin/*`, which becomes stale on the move.

## See also

- `docs/netmodem2irc_i8086_TSR_finish_guide.md`
- `docs/netmodem2irc_fossil_getinfo.md`
- `docs/netmodem2irc_fossil_block_io.md`
- `DEFERRED-20260725.md` — open runtime issues
