# Cyclades CD1400 FOSSIL — Integration Plan

## Overview

Integrate evga's Cyclades CD1400 FOSSIL driver into netmodem2irc.
The driver supports Cyclom-Y multiport serial boards — up to 32
ports per card, enabling 8-node (or larger) BBS systems on one machine.

All 12 bugs fixed. Audited by hexadecimal + sysop/0. Ready to ship.

## Components

| File | Lines | What | Author |
|------|-------|------|--------|
| cyfossil.asm | 1,129+ | DOS FOSSIL over CD1400 | evga |
| cd1400.h | ~293 | Register definitions | evga |
| cyisr.c | ~960 | Windows WDM ISR | evga |
| cyserial.c | ~681 | Windows WDM main driver | evga |
| cyioctl.c | ~1,208 | Windows IOCTL dispatch | evga |
| cyenum.c | ~1,023 | PnP bus enumeration | evga |
| cypdo.c | ~520 | Physical device objects | evga |
| cypower.c | ~460 | Power management | evga |
| cyread.c | ~273 | Read path | evga |
| cywrite.c | ~283 | Write path | evga |
| cylog.c | ~396 | Event logging | evga |
| cytest.c | ~205 | Hardware detect test | evga |
| cystress.c | ~511 | Stress test | evga |
| cyloopback.c | ~563 | Loopback test | evga |
| cyinstall.c | ~839 | Driver installer | evga |
| CYFOSSIL_AUDIT.md | — | Full audit + patches | hexadecimal + sysop/0 |

Total: ~12,000 lines (unique)

## Integration Phases

### CY-P1: Source Import
- Create `fossil/cyclades/` directory
- Copy cyfossil.asm + cd1400.h (DOS FOSSIL)
- Copy CYFOSSIL_AUDIT.md (audit + patches)
- Add to fossil/README.md
- Update main README.md directory tree

### CY-P2: Verify Patches Applied
- Confirm all 12 bug patches are in the source:
  - CY-1 through CY-4: idle calls + DCD checks
  - CY-5: non-destructive peek via ring buffer
  - CY-6: block read from ring buffer (no HW access)
  - CY-7: init bounds + double-init protection
  - CY-8: flush idle
  - CY-9: buffer info reports RING_SIZE
  - CY-10: EOSRR on every ISR exit
  - CY-11: AH range check before dispatch
  - CY-12: CAR register race CLI/STI
- Run CYFTST (DOS FOSSIL test) if DOSBox available

### CY-P3: Windows Kernel Driver Import
- Create `fossil/cyclades/kernel/` directory
- Copy all cy*.c + cy*.h files
- Copy cyinstall.c (installer)
- Copy test suite (cytest, cystress, cyloopback)
- Verify against hexadecimal's WDM audit (0 bugs found)

### CY-P4: Register Definitions Pascal Port
- Create `fossil/cyclades/cd1400_regs.pas`
- Port all CyXXX register offsets from cd1400.h
- Port baud rate tables (25MHz + 60MHz)
- Port SRER, SVRR, RIVR/TIVR/MIVR interrupt registers
- Port COR1/COR2/COR3 configuration registers
- Verify packed record sizes match C structs

### CY-P5: FOSSIL Bridge Unit
- Create `fossil/cyclades/cy_fossil_bridge.pas`
- Bridge between cyfossil.asm and netmodem2irc engine
- Maps CD1400 ring buffer to NM_UART16550 ring buffer
- Routes DCD/DTR/RTS through ISocketLink
- XON/XOFF flow control via COR2 IXM

### CY-P6: Multi-Port Node Manager
- Update NM_Node.pas for 8+ concurrent nodes
- Map CD1400 channels (0-31) to netmodem2irc node IDs
- Per-channel config: baud, flow control, buffer size
- Shared IRQ handling across channels

### CY-P7: Test Suite
- Port cytest.c assertions to Pascal test framework
- Add CD1400 register emulation tests
- Add ring buffer stress test (matches cystress.c)
- Add loopback test (matches cyloopback.c)
- Target: 50+ tests, 0 failures

### CY-P8: Documentation
- Update fossil/README.md with Cyclades section
- Add fossil/cyclades/README.md with:
  - Hardware requirements (Cyclom-Y board)
  - DOS setup (CYFOSSIL.SYS /MD400 /P8 /B3)
  - Windows setup (cyinstall /install)
  - Multi-port configuration
  - Baud rate tables
  - Troubleshooting (EOSRR, ring buffer, DCD)
- Update docs/BUGS.md
- Update CHANGELOG.md

## Dependencies

- evga delivers patched cyfossil.asm (all 12 bugs fixed)
- evga delivers Windows kernel driver (audited clean)
- DOSBox or real DOS for CYFTST testing
- Cyclom-Y hardware for end-to-end (or emulation)

## Architecture

```
Phone lines → 8 modems → Cyclom-Y card (CD1400 chip)
  → cyfossil.asm (DOS FOSSIL, INT 14h)
    → ring buffer (1024 bytes, ISR-drained)
      → PCBoard / Mystic / Renegade (8 nodes)

Telnet callers → NMServer (TCP)
  → cy_fossil_bridge.pas
    → NM_UART16550 (register emulation)
      → NM_Fossil (FOSSIL dispatch)
        → BBS software
```

## Bug Audit Summary (ALL FIXED)

| Bug | Severity | Fix | Auditor |
|-----|----------|-----|---------|
| CY-1 | High | RX idle + DCD check | wrench → hexadecimal |
| CY-2 | Critical | 1024-byte ISR ring buffer | wrench → hexadecimal |
| CY-3 | High | DTR Fn06 via MSVR1+MSVR2 | wrench → hexadecimal |
| CY-4 | High | TX idle + DCD check | wrench → hexadecimal |
| CY-5 | Critical | Peek from ring buffer | wrench → hexadecimal |
| CY-6 | Critical | Block read from ring buffer | wrench → hexadecimal |
| CY-7 | Medium | Init bounds + double-init | wrench → hexadecimal |
| CY-8 | High | Flush idle | wrench → hexadecimal |
| CY-9 | Medium | Report actual RING_SIZE | wrench → hexadecimal |
| CY-10 | Blocker | EOSRR on every ISR exit | wrench → hexadecimal |
| CY-11 | Medium | AH range check | sysop/0 |
| CY-12 | Medium | CAR register race CLI/STI | sysop/0 |

## Credits

| Who | What |
|-----|------|
| evga | CD1400 driver (DOS + Windows), all patches applied |
| hexadecimal | FSC-0015 audit, 10 bug patches, baud tables, XON/XOFF |
| sysop/0 | pcbfoss cross-reference audit, CY-11 + CY-12 |
| wrench | Initial 10-bug audit, architecture review |
