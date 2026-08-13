# Watt-32 Cleanup and DOS FOSSIL Driver — Phase Plan

Written 2026-07-25.

Goal: `dos/` contains **two separate programs** with separate builds.
The FOSSIL driver links against nothing but the FPC msdos RTL. The relay
keeps Watt-32. Neither inherits the other's dependencies.

## Topology (decided 2026-07-25 by the maintainer)

**DOS — two programs, both on real hardware:**

```
BBS / door ──INT 14h──> netfossl ──> real 16550 ──> wire
                        (FOSSIL driver, no TCP)

           relay ──> real 16550 ──> TCP        (Watt-32)
                     (direct port I/O, not FOSSIL)
```

The relay moves from virtual comport to **real UART**: direct port I/O
rather than INT 14h calls. It is therefore no longer a FOSSIL client and
does not compete with netfossl at the FOSSIL layer.

**Win32 — the bridge:**

```
DOS BBS ──> virtual comport ──> NMServer ──> TCP
            (NETMODEM.VXD on 9x, com0com on NT)
```

### Hard rule: one owner per port

Each DOS program owns its UART exclusively. Two programs doing port I/O
on the same 16550 — one running an IRQ handler, one polling — corrupt
each other at the register level: stolen bytes from RBR, lost IIR
interrupt-cause reads, conflicting IER and FCR writes, and an EOI sent
by whichever got there first. This is below any arbitration layer; there
is no protocol that fixes it.

Enforcement is a configuration and documentation matter, not something
the hardware will do for you.

Related: `netmodem2irc_fossil_separation.md`.

## Topology — decided 2026-07-25

**There is no TCP on DOS.** Watt-32 is removed and not replaced; the DOS
programs become pure FPC Pascal against the msdos RTL.

### Two independent platforms

These are **separate deployments, not stages of one pipeline.** Each is
a complete solution on its own hardware. Nothing crosses between them.

#### DOS — standalone, real hardware, no network

**`netfosdl` is a standalone FOSSIL driver. It is not part of netmodem.**

It does not link any `NM_*` engine unit, does not speak the SEAM
protocol, has no server link, and knows nothing about NMServer, virtual
comports, registry config or `CM_*` messages. It is a FOSSIL driver in
the same sense X00 and BNU are: a DOS BBS loads it and calls INT 14h.

```
DOS BBS ──INT 14h──> netfosdl ──> real UART
```

`netfosdl` is the FOSSIL driver. The BBS calls INT 14h, netfosdl
services it against a real 16550, and the bytes go out the serial port.
That is the whole path. No TCP, no sockets, no packet driver.

Second, separate program on the same platform:

```
real UART <──> relay <──> real UART
```

The relay moves bytes between two real ports using direct port I/O. It
never calls INT 14h, so it does not contend with netfosdl for the FOSSIL
interface.

| Program | Role | Interface | Network |
|---|---|---|---|
| `netfosdl.exe` | FOSSIL driver for the BBS | **answers INT 14h** | none |
| relay | moves bytes between real UARTs | **direct port I/O** | none |

Both link against `ppcross8086` plus `system`, `dos`, `strings`,
`objpas`. Nothing else — no engine units, no netmodem code.

Self-contained means the DOS tree owns its whole stack: its own 16550
unit, its own FOSSIL function set, its own INT 14h hook, its own
residency. Nothing is imported from `engine/`.

#### i386 — the bridge

A different platform with a different answer. Here the comport is
virtual, not real, and TCP is present:

```
DOS BBS ──> virtual comport ──> NMServer ──> TCP
            (VxD 9x / com0com NT)   (Synapse)
```

| Platform | Virtual comport |
|---|---|
| Windows 9x | `NETMODEM.VXD` — Dedrick's original |
| Windows NT+ | com0com |

Synapse does the sockets. Already bundled in `libs/synapse/` and
compile-verified against `NM_SynapseLink`.

**The DOS platform does not feed the i386 platform.** DOS solves the
problem with real hardware; i386 solves it with a virtual comport and a
socket. Choosing one does not involve the other.

## Phases

### Phase 1 — Inventory ✅ DONE

Established what Watt-32 actually is in this tree, and how much of it is
in version control.

| Artifact | Location | In repo? |
|---|---|---|
| `stubs.asm` | `dos/` | **yes** |
| ten `_w32_*` externals | `dos/netmodem.pas` | **yes** |
| Watt-32 link logic | `dos/build.sh` | **yes** |
| `wattcpwl.lib` (382K) | `$FPCIRC/lib/watt32/` | no — toolchain |
| `clibl.lib`, `emu87.lib` | `/opt/watcom/lib286/dos/` | no — toolchain |
| `fixasm.py`, `omfinfo.py` | `$FPCIRC/bin/tools/i8086-msdos/` | no — toolchain |

Naming trap recorded: the Pascal declarations are named `fpcirc_*` but
every one binds `external name '_w32_*'`. There is no "fpcirc TCP/IP"
stack. That name concealed the Watt-32 dependency.

### Phase 2 — Retire the linker filler ✅ DONE

`dos/stubs.asm` moved to `attic/watt32/` with a README recording the
whole apparatus, including the toolchain pieces that were never tracked.

**Leaves `dos/build.sh:38` referencing a file that has moved. The DOS
build is broken until Phase 5.** Deliberate: the build should not
silently keep working while it is being dismantled.

### Phase 3 — Decide the relay's fate ✅ DECIDED

**The relay survives, converted to real UART.** Both programs live in
`dos/`, in separate directories with separate builds.

This resolves the contention problem in the current design. Today
`netmodem.pas` requires a FOSSIL driver resident and calls INT 14h on
the same port the BBS uses — two FOSSIL clients drawing from one receive
buffer, whichever polls first wins. Converting the relay to direct port
I/O removes it from the FOSSIL layer entirely.

The contention does not vanish, it moves: see "one owner per port"
above. Two programs on the *same* UART is still fatal, now at the
register level rather than the buffer level.

**No TCP on either program.** Watt-32 is removed and not replaced. Both
DOS binaries are pure FPC Pascal against the msdos RTL. TCP belongs to
the i386 bridge, not to DOS.

Layout:

```
dos/
├── driver/    FOSSIL driver — answers INT 14h over a real UART
├── relay/     moves bytes between real UARTs — direct port I/O
└── uart/      shared 16550 layer (Phase 6)
```

Both built with `ppcross8086` + msdos RTL. No Watcom, no OMF chain.

### Phase 4 — Split the tree, convert the relay ⬜ OPEN

`dos/netmodem.pas` moves to `dos/relay/`. All ten `_w32_*` externals are
**deleted**, along with the socket path they serve. Nothing replaces
them — there is no TCP on DOS.

The relay becomes a two-UART byte mover: one real port in, one real port
out. Its *shape* survives — the bounded non-blocking pump loop,
two-direction buffering, the carrier check — but every call in it
changes:

| Now | After |
|---|---|
| `Fossil_Init` / `Fossil_SetBaud` | direct LCR / divisor-latch programming |
| `Fossil_RxReady` / `Fossil_RecvByte` | LSR poll + RBR read, or IRQ-driven ring |
| `Fossil_SendByte` | LSR THRE check + THR write |
| `Fossil_Carrier` | MSR DCD bit |
| `Fossil_SetDTR` | MCR bit 0 |
| depends on `fossil_dos.pas` | depends on the Phase 6 UART unit |
| `fpcirc_tcp_open` / `sock_read` / `sock_write` / `tcp_tick` (10 externals) | **deleted** — second real UART instead |

`dos/fossil_dos.pas` — the FOSSIL client — has no consumer after this
and retires to `dos/retired/`.

Note the relay and the driver both need the Phase 6 UART unit, so
Phase 6 becomes a dependency of Phase 4, not a successor.

### Phase 5 — Two builds, not one ⬜ OPEN

`dos/build.sh` splits.

**`dos/driver/build.sh`** — two stages. `ppcross8086 -Tmsdos`, link
against `system`, `dos`, `strings`, `objpas`. No nasm, no OMF
conversion, no `wlink` libraries, no stubs. One toolchain.

**`dos/relay/build.sh`** — the existing five-stage chain, unchanged in
substance: `ppcross8086` → `fixasm.py` → `nasm -f obj` → `omfinfo.py`
→ `wlink` against `wattcpwl.lib`, `clibl.lib`, `emu87.lib`.

`stubs.asm` returns from `attic/watt32/` to `dos/relay/`. Retiring it
in Phase 2 was correct on the information available then; the decision
in Phase 3 reverses it.

Outputs land in `out/dos/` under distinct names. `netfossl.exe` should
name the driver, since that is what the name has always meant.

### Phase 6 — Real 16550 UART ⬜ OPEN — *shared by both programs*

**Does not exist anywhere in the repo.** Verified: zero `inportb`,
`outportb`, `Port[]` or hardware base addresses in `engine/`, `common/`,
`dos/`, `server/` or `config/`.

Needs:

- port I/O against a base address (`$3F8`, `$2F8`, `$3E8`, `$2E8`)
- RBR / THR / IER / IIR / FCR / LCR / MCR / LSR / MSR handling
- IRQ 3/4 handler with 8259 PIC mask and EOI
- interrupt-driven TX/RX ring buffers
- FIFO enable and trigger-level control
- divisor-latch baud programming

`engine/NM_UART16550.pas` is a useful reference for register semantics —
it models the same register file — but it is explicitly hardware-free
("no OS calls, no sockets, no I/O ports"), so nothing links against it.

### Phase 7 — FOSSIL function set, INT 14h, residency ⬜ OPEN

The FOSSIL layer sits on the Phase 6 UART.

- full FSC-0015 rev 5 function set plus FSC-0072
- `$1954` init signature
- FSC-0015 status-word bit layout
- INT 14h vector hook — `engine/NM_Int14ISR.pas` already has this,
  `{$IFDEF DOS_TARGET}`-guarded, but lives in the NT-branch tree
- residency via `Keep` from the 16-bit msdos RTL

**Resolved: nothing is shared with `engine/`.** netfosdl is standalone,
so the DOS tree gets its own INT 14h hook and its own residency code.

`engine/NM_Int14ISR.pas` and `NM_TSRResident.pas` carry `DOS_TARGET`
guards and were earlier flagged as "DOS code in the NT tree". They are
not misfiled — they belong to the virtual-comport side and stay there.
netfosdl does not use them.

`engine/NM_Fossil.pas` remains a useful *reference* for the FOSSIL
function semantics, in the same way `NM_UART16550.pas` is a reference
for register behaviour. Reference, not dependency.

### Phase 8 — Conformance ⬜ OPEN

Drop-in compatibility with **X00**, **BNU**, **ADF**, **NetFoss**. The
bar is behavioural: a BBS or door that runs against X00 runs against
this driver unmodified — no rebuild, no recompile, no reconfiguration.

Method already established in
`netmodem2irc_FOSSIL_crossvalidation.md`: answer an independent,
period-correct FOSSIL client's exact calls with the exact responses it
expects.

## Why the FPC substitution does not work

The obvious move — swap the ten `_w32_*` externals for FPC's own socket
calls and delete `external` — produces a program that compiles cleanly
and cannot connect to anything.

### 1. The `sockets` unit has no backend on i8086-msdos

From `dos/fpc-sockets-request.md`, the project's own upstream request:

> The sockets unit compiles for the i8086-msdos target and produces a
> valid PPU, but the BSD socket calls (fpSocket, fpConnect, fpSend,
> fpRecv, fpClose, TInetSockAddr) have no backend implementation.

Still unsubmitted. Nothing has changed.

### 2. fcl-net does not help

`fcl-net` is a wrapper over the platform's networking API, not an
implementation. Dumping `ssockets.ppu` shows its dependencies:

```
System, objpas, SysUtils, Classes, ctypes, Sockets, WinSock2, Windows, resolve
```

It sits on `Sockets` — the unit with no msdos backend — and on this
target also pulls in `WinSock2` and `Windows`. It needs `SysUtils` and
`Classes`, heavy for 16-bit real mode. FPC does not ship `fcl-net` for
DOS targets at all: present for `i386-win32`, absent for
`i386-go32v2`.

"Unified across platforms" means unified across platforms that have
TCP. DOS is not one of them.

### 3. Three calls have no equivalent, because the ownership model differs

| Watt-32 | FPC | Note |
|---|---|---|
| `_w32_tcp_open_` | `fpSocket` + `fpConnect` | maps |
| `_w32_sock_read_` | `fpRecv` | maps |
| `_w32_sock_write_` | `fpSend` | maps |
| `_w32_sock_close_` | `fpClose` | maps |
| `_w32_resolve_` | `TInetSockAddr` + resolver | maps |
| `_w32_tcp_tick_` | **none** | see below |
| `_w32_sock_established_` | blocking `fpConnect`, or `fpSelect` write-ready | different shape |
| `_w32_sock_dataready_` | `fpSelect`, or `FIONREAD` | different shape |
| `sock_init_` / `_w32_sock_exit_` | **none** | see below |

**`tcp_tick` has no counterpart.** Watt-32 is a polled userspace stack:
it only executes when called. `tcp_tick` is where the stack gets CPU
time to poll the packet driver, process incoming segments, send ACKs,
run retransmission timers and update windows. It returns 0 when the
connection is dead. Delete it and the handshake never completes.

BSD sockets assume a kernel stack running independently, so there is
nothing to pump. Porting is not renaming — the control flow inverts.

### `sock_init` / `sock_exit` — what they actually do

Correct that these are not standard C or FPC functions. They are
Watt-32's own lifecycle calls, and on DOS they carry real weight:

`sock_init()` reads `WATTCP.CFG`, locates the packet driver, sets IP /
netmask / gateway / DNS, allocates buffers, and **hooks the packet
driver's software interrupt**.

`sock_exit()` reverses it: closes sockets, frees buffers, and
**unhooks the packet driver, restoring the interrupt vector**.

That last part is not housekeeping. DOS has no process teardown — no
kernel reclaims resources when a program exits. A program that hooks an
interrupt vector and terminates without restoring it leaves the vector
pointing into memory that is about to be reused. The next program to
trigger that interrupt jumps into garbage. Skipping `sock_exit` does not
leak; it destabilises the machine until reboot.

FPC has no equivalent because there is nothing to tear down: on Unix and
Windows the OS owns the stack, and the kernel reclaims sockets on
process exit. The nearest analogue is `WSAStartup` / `WSACleanup` on
Windows, and even those are per-process bookkeeping, not vector
restoration.

**This generalises to the FOSSIL driver.** It also hooks an interrupt
vector — INT 14h — and it goes resident. The same discipline applies:
save the old vector on install, restore it on unload, and refuse to
unload if another program has hooked INT 14h after you. `sock_exit` is
the pattern to copy, not the function.
