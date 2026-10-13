# driver/src — NetModem VxD Source (Hardened)

Based on Dedrick Allen's original NetModem/32 virtual device driver (1997-2001),
with N4 hardening patches and N5 stub completion by wrench (2026-10-13).

NETMODEM.ASM — 5,823 lines, 0 warnings, 0 errors, 0 TODOs.

## Changes from Dedrick's original (5,712 lines)

- **N4 Patch 1** — Event callbacks (lpClientReadNotify + EV_RXCHAR) after IOCTL 0Eh RX
- **N4 Patch 2** — CTS+DSR default on PortOpen (MSR 00110000b)
- **N4 Patch 3** — SafeDec macro on all 34 FIFO decrement sites (race guard)
- **N4 Patch 4** — Clear 3 callbacks + event mask + MSR shadow on PortClose
- **N5** — ATI4-I7 info strings (szSettings, szStoredNum, szLinkDiag, szRevision)
- **JWasm compat** — OPTION NOKEYWORD, IRQ_Ready field fix, Short qualifiers removed

See docs/NETMODEM_VXD_HARDENING.md for full details and build results.

## Build

No MASM, no DDK binaries, no Wine needed. Linux native:

```bash
cd ../build
./build_vxd.sh
```

Requires JWasm (github.com/JWasm/JWasm) and wlink (Open Watcom v2).
JWasm-compatible DDK includes are in `../build/`.

## Files

| File | What |
|------|------|
| NETMODEM.ASM | 5,823L — hardened VxD source (N4+N5) |
| NETMODEM.INC | Main include (IRQ_Ready field added) |
| NETMODEM.DEF | Module definition (NETMODEM_DDB export) |
| NETMODEM.RC | Resource script |
| RESOURCE.H | Resource header |
| COPYING | GPLv3 |

16 files total. Windows 95/98 VxD target.
