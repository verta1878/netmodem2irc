# attic/watt32/ — the Watt-32 / Watcom mixed-link apparatus

Retired 2026-07-25. **netfosdl (formerly netfossl) needs no TCP/IP.**

All of this existed for one reason: `dos/netmodem.pas` was a
serial-to-TCP relay, real-mode DOS has no OS network API, FPC's
i8086-msdos `sockets` unit has no backend, and Watt-32 was the only
serious DOS TCP/IP stack. Linking a C stack into a Pascal program
dragged in a second toolchain and its object format.

The FOSSIL driver answers INT 14h and drives a real 16550. It opens no
sockets. None of this is needed.

## What is here

| File | What it was |
|---|---|
| `stubs.asm` | 40 lines of linker filler: eight zero bytes for FPC RTTI/INIT slots, plus `main_`, `_EFG_Format_` and `__cnvs2d_` — symbols the Watcom C runtime demanded that a Pascal program never provides |

## What was never in this repo

These lived in the toolchain, not in version control. Listed so the
dependency is recorded even though there is nothing here to retire:

| Artifact | Where it lived | What it was |
|---|---|---|
| `wattcpwl.lib` (382K) | `$FPCIRC/lib/watt32/` | Watt-32 DOS TCP/IP, 16-bit large model |
| `clibl.lib` | `/opt/watcom/lib286/dos/` | Watcom C runtime, large model |
| `emu87.lib` | `/opt/watcom/lib286/dos/` | FPU emulation for the C library |
| `fixasm.py` | `$FPCIRC/bin/tools/i8086-msdos/` | rewrote FPC's GNU-syntax `.s` output so nasm could assemble it |
| `omfinfo.py` | same | walked OMF archives to resolve which objects were needed |

## Why OMF mattered

Real-mode 8086 addresses are `segment:offset`. OMF has fixup records
that relocate the segment part independently of the offset; ELF and COFF
were built for flat address spaces and cannot express that. So Watcom's
libraries and linker spoke OMF, and FPC's output had to be converted to
meet them — `.s` -> `fixasm.py` -> `nasm -f obj` -> OMF. Object formats
are not interchangeable containers; they encode the machine's address
model.

Drop the C stack and the whole question disappears.

## What replaces it

`ppcross8086` plus four RTL units — `system`, `dos`, `strings`,
`objpas`. Port I/O, an IRQ handler and `Keep` are plain real-mode
Pascal. One toolchain, one object format, no stubs.

## Still live

`dos/netmodem.pas` (the old relay) still declares ten `external name '_w32_*'` bindings
and previously built `netfossl.exe` (now removed). Its fate is a maintainer
decision, not retired here. `dos/build.sh` still references
`stubs.asm` at the path it no longer occupies.

`dos/fpc-sockets-request.md` stays in place: it is the record of *why*
Watt-32 was necessary — FPC's i8086-msdos socket calls compile but have
no backend. Still unsubmitted upstream.
