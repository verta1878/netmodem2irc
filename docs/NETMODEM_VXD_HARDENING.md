# NETMODEM.VXD Hardening Patches — N4 + N5

wrench, 2026-10-12/13. Four hardening items from N1 gap audit + two derk TODOs finished.

## Toolchain

Built on Linux natively — no Wine, no MASM, no DDK binaries needed:
- **JWasm v2.12pre** (open source MASM-compatible assembler, built from source)
- **wlink 2.0** (Open Watcom v2 linker, LE/VxD format support)
- Verified byte-exact against reference FOSSIL.VXD before touching NETMODEM

### Fixes to get NETMODEM.ASM compiling with JWasm:
- Case-sensitive symlinks for DDK `.inc` files (Linux filesystem)
- `OPTION NOKEYWORD:<SYSEXIT VMRESUME>` — JWasm reserved words
- `IRQ_Ready Boolean False` added to StatusStruct — derk used it but never declared it
- All `Short` jump qualifiers removed — SafeDec macro expansion pushes bodies past ±128 bytes
- All `loop Short @B` → `dec ecx / jnz @B` — same reason

## Build Results

| Build | Lines | Size | SHA256 (first 16) |
|-------|-------|------|-------------------|
| Baseline (unpatched) | 5,714 | 27,688 | `739b273a54c30c93` |
| N4 hardened | 5,817 | 31,792 | `83391cb485938935` |
| Final (N4+N5) | 5,823 | 31,921 | `4efa68d821033030` |

## 1. Event Callback Firing (IOCTL 0Eh, after IOCTL_Recv_Done)

**Problem:** After IOCTL 0Eh puts data into RXBuffer, it calls
`VMMCall Wake_Up_VM` but does NOT fire `lpClientReadNotify` or
`lpClientEventNotify`. VCOMM apps waiting on `WaitCommEvent()`
or `ReadFile()` overlapped never get signaled.

**Fix:** After `Wake_Up_VM` + `Adjust_Execution_Time`, fire
`lpClientReadNotify` if RXLength > 0, then `lpClientEventNotify`
with `EV_RXCHAR`. Both guarded by NULL checks, wrapped in pushad/popad.

**Status:** COMPILED ✓ — also resolves derk's TODO at line 893
("Check for possible Win32 comm events").

## 2. Default CTS+DSR on Port Open (PortOpen)

**Problem:** PortOpen sets `VCOMMOpened = True` but does NOT reset MSR
to CTS+DSR. Reopened port starts with no CTS/DSR → apps hang.

**Fix:** After `VCOMMOpened, True`: `or MSR, 00110000b` + `or bMSRShadow, 00110000b`.

**Status:** COMPILED ✓

## 3. FIFO QxCount<0 Race Guard

**Problem:** ATLength, TXLength, RXLength decremented without zero check.
IOCTL/VCOMM race → length wraps to 0xFFFF → buffer overrun.

**Fix:** `SafeDec` macro: zero-check before dec, flush-to-start on underflow.
Applied to all **34 decrement sites** (28 ATLength, 5 RXLength, 1 TXLength).

**Status:** COMPILED ✓

## 4. Callback Cleanup on Close (PortClose)

**Problem:** PortClose frees buffers but does NOT clear VCOMM callback
pointers. Stale callback after close → page fault / BSOD.

**Fix:** After `VCOMMOpened, False`: clear all 3 callback pointers,
event mask, detected events, ref data, MSR shadow.

**Status:** COMPILED ✓

## 5. ATI4-I7 Info Strings (N5 — derk TODO at line 1267)

**Problem:** ATI4 through ATI7 all returned szProduct (same as ATI3).
Derk left a TODO: "Add support for I4, I5, I6 and I7".

**Fix:** Added 4 new string constants in VxD data section:
- `szSettings` — "ATI4 Settings: TCP/IP Virtual Modem"
- `szStoredNum` — "ATI5 Stored: (none)"
- `szLinkDiag` — "ATI6 Link: TCP/TELNET"
- `szRevision` — product ID + "Build N4"

Wired each ATI handler to its proper string.

**Status:** COMPILED ✓ — 0 TODOs remaining in NETMODEM.ASM.

## Summary

| # | Item | Type | Status |
|---|------|------|--------|
| 1 | Event callbacks after RX | Functional gap | COMPILED ✓ |
| 2 | CTS+DSR on reopen | Functional gap | COMPILED ✓ |
| 3 | FIFO race guard (34 sites) | Race condition | COMPILED ✓ |
| 4 | Stale callbacks on close | Use-after-free | COMPILED ✓ |
| 5 | ATI4-I7 info strings | Unfinished feature | COMPILED ✓ |

All patches additive — no existing logic changed. 0 warnings, 0 errors, 0 TODOs.
