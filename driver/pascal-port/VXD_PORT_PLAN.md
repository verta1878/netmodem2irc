# NETMODEM.VXD → Pascal Port Plan

## Overview

Port Dedrick Allen's Win9x VxD (5,712 lines MASM) to Free Pascal.
The VxD runs at Ring-0 in the Windows 9x kernel — that can't be
replicated in user-mode. But the LOGIC can be ported to user-mode
Pascal and tested against the original behavior.

## Why Port?

- MASM 6.11 + Win98 DDK required to build — nobody has this
- The VxD only runs on Win9x (not NT/2000/XP/Vista/7/8/10/11)
- We already have 80% of the logic in Pascal (engine/*.pas)
- A Pascal port runs everywhere FPC compiles

## Architecture Mapping

| VxD Component | Lines | Pascal Equivalent | Status |
|---------------|-------|-------------------|--------|
| IOHandler00-07 (UART) | ~800 | NM_UART16550.pas | ✅ loopback fixed (P-1) |
| INT14 00-21h (FOSSIL) | ~1200 | NM_Fossil.pas | ✅ X00 20h/21h/7Eh/7Fh added |
| AT command parser | ~600 | NM_ATCommand.pas | ✅ exists |
| IOCTL 00-10h (control) | ~400 | NMVxD.pas | ✅ exists |
| Ring buffers (AT/TX/RX) | ~300 | NM_Node.pas | ✅ exists |
| StatusStruct (per-node) | ~200 | TNetModemNode | ✅ exists |
| VCOMM port hooks | ~500 | NM_ServerBridge.pas | ✅ exists |
| Registry config | ~200 | NM_Config.pas | ✅ exists |
| VxD framework (VMM/VxD) | ~1400 | N/A (kernel-only) | skip |

## What's Actually Missing

The VxD-specific parts that CAN'T be ported:
- Declare_Virtual_Device macro → not needed (user-mode)
- VMMCall, VxDCall → replaced by FPC API calls
- V86 memory allocation → replaced by heap allocation
- VPICD IRQ virtualization → not needed (no physical IRQ)
- VxD Control_Proc dispatch → replaced by event loop

## Port Phases

### P1: Header Port (NETMODEM.INC → NM_VxD_Types.pas)
Port all data structures:
- StatusStruct → TVxDNodeStatus (packed record)
- ComportStruct → TComportConfig (packed record, SizeOf=24)
- UARTStruct → already TUart16550
- FOSSILStruct → already TFossilInfo
- CommandStruct → already TATModemState
- IOStruct → TVxDIO (packed record)
- DriverInfo → TVxDDriverInfo (packed record)
- InitStruct → TVxDInitInfo (packed record)
Validate: packed record sizes match ASM STRUC sizes.

### P2: IOCTL Port (verify NMVxD.pas covers all 17)
VxD has 17 IOCTLs (IOCTL00-IOCTL10):
```
00  Get driver version
01  Get driver information
02  Unload port config
03  Reload port config
04  Unvirtualize IRQ
05  Virtualize IRQ
06  Startup
07  Shutdown
08  Register server window
09  Get initialization information
0A  Reset node
0B  Ring node
0C  Answer check
0D  Disconnect node
0E  Input/Output (the main data path!)
0F  BREAK received
10  Get word length (BINARY mode)
```
NMVxD.pas has constants for all of these. Verify dispatch.

### P3: FOSSIL Extended Functions (INT14 1Ch-21h)
VxD has 34 INT 14h functions — 7 more than FSC-0015:
```
1Ch  Install external application handler
1Dh  Remove external application handler
1Eh  Extended FOSSIL info
1Fh  Extended line control
20h  Extended baud rate (high speeds)
21h  Extended modem control
```
NM_Fossil.pas has 27 (FSC-0015). Add the X00 extensions.

### P4: Ring Buffer Verification
VxD uses 3 separate ring buffers per node:
- ATBuffer (AT command accumulation)
- TXBuffer (transmit to remote)
- RXBuffer (receive from remote)
Each has In/Out/End pointers + Length counter.
Verify our NM_Node buffer management matches.

### P5: AT Command Response Strings
VxD has exact response strings. Verify ours match:
```
OK              → "OK"
BUSY            → "BUSY"
RING            → "RING"
ERROR           → "ERROR"
NO ANSWER       → "NO ANSWER"
NO CARRIER      → "NO CARRIER"
NO DIAL TONE    → "NO DIAL TONE"
CONNECT 300     → "CONNECT 300/ARQ/TELNET"
CONNECT 1200    → "CONNECT 1200/ARQ/TELNET"
CONNECT 2400    → "CONNECT 2400/ARQ/TELNET"
CONNECT 9600    → "CONNECT 9600/ARQ/TELNET"
```

### P6: Integration Test
Full end-to-end: IOCTL startup → config load → AT handshake →
FOSSIL init → data transfer → FOSSIL deinit → IOCTL shutdown.

## Compiler Differences

| Issue | MASM | FPC | Fix |
|-------|------|-----|-----|
| Struct alignment | STRUC BYTE = packed | packed record | match |
| Struct alignment | STRUC DWORD = aligned | record | match |
| Boolean | DB (0/1) | Boolean (0/1, 1 byte) | match |
| String | DB "text",0 | PChar / shortstring | use PChar |
| Bit ops | AND/OR/XOR/SHR/SHL | and/or/xor/shr/shl | match |
| Pointer | DD NULL (32-bit) | Pointer (32 or 64) | use PtrUInt |
| Segment regs | CS:/DS:/ES: | N/A (flat model) | skip |
| INT 21h | direct | N/A (user-mode) | FPC RTL |

## Test System

`vxd_port_test.pas` — 7-phase test harness:
1. UART register emulation (reset, THR, baud, MCR, FCR)
2. FOSSIL dispatch (init, set baud, status, deinit)
3. AT command parser (AT, ATE0, ATZ)
4. Ring buffer (fill, overflow, drain, wrap, peek)
5. IOCTL dispatch constants
6. Status struct layout (packed record sizes)
7. Compiler differences (byte/word/longint/boolean/packed)

## Credits
- Dedrick Allen — original NETMODEM.ASM (1997-2001)
- verta1878 — NMVxD.pas, NetModemVxD.pas (Pascal wrappers)
- wrench — port plan, test harness
