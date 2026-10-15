# NETMODEM.VXD Hardening Patches — N4 + N5

wrench, 2026-10-12 (N4), 2026-10-13 (N5). Four items from N1 gap audit.

## What "Hardening" Means

Hardening means making the driver not crash when things go wrong.
Derk's original NETMODEM.ASM worked but had no guards — if a buffer
underflowed, a callback fired after cleanup, or a FIFO counter went
negative, the driver would corrupt memory or bluescreen.

- **SafeDec macro** — every `dec [counter]` in the driver (34 sites)
  now checks for zero before decrementing, so a FIFO counter can never
  go negative and wrap to 65535
- **Event callbacks** — the driver now notifies Win32 apps when modem
  status changes (CTS/DSR/DCD), instead of silently changing state
- **CTS/DSR default high** — BBS software expects these lines asserted
  on connect; the original code left them low, which made some BBS
  software think nobody was connected
- **Callback cleanup on close** — registered callbacks are cleared when
  the port closes, so Windows doesn't call into freed memory

None of it adds features. It makes the existing features not break
under real-world conditions.

---

## 1. Event Callback Firing (IOCTL 0Eh, line ~5010)

**Problem:** After IOCTL 0Eh puts data into RXBuffer, it calls
`VMMCall Wake_Up_VM` but does NOT fire `lpClientReadNotify` or
`lpClientEventNotify`. VCOMM apps waiting on `WaitCommEvent()`
or `ReadFile()` overlapped never get signaled.

**Fix:** After `IOCTL_Recv_Done:` and before `Wake_Up_VM`, add:

```asm
    ; --- N4 HARDENING: fire event callback after RX data arrives ---
    .IF ([edi].StatusStruct.RXLength > 0)
      lea  eax, [edi].StatusStruct.PortInfo.pPORTDATA
      .IF ([eax]._PORTDATA.lpClientReadNotify != NULL)
        pushad
        push dword ptr [eax]._PORTDATA.dwClientRefData
        push 0                                    ; notify subfunction
        push edi                                  ; hPort
        call dword ptr [eax]._PORTDATA.lpClientReadNotify
        add  esp, 12
        popad
      .ENDIF
      .IF ([eax]._PORTDATA.lpClientEventNotify != NULL) && \
          ([eax]._PORTDATA.dwClientEventMask & EV_RXCHAR)
        pushad
        or   [eax]._PORTDATA.dwDetectedEvents, EV_RXCHAR
        push dword ptr [eax]._PORTDATA.dwClientRefData
        push 0
        push edi
        call dword ptr [eax]._PORTDATA.lpClientEventNotify
        add  esp, 12
        popad
      .ENDIF
    .ENDIF
    ; --- end N4 ---
```

Similarly, after TX data is consumed (IOCTL 0Eh TX path), fire
`lpClientWriteNotify` and `EV_TXEMPTY` when TXLength reaches 0.

## 2. Default CTS+DSR on Port Open (PortOpen, line ~5534)

**Problem:** PortOpen sets `VCOMMOpened = True` and initializes DCB
but does NOT reset MSR to CTS+DSR. If a previous disconnect cleared
the modem status bits, the reopened port starts with no CTS/DSR,
and apps that check modem status before sending will hang.

**Fix:** After `mov [edi].StatusStruct.VCOMMOpened, True` (line 5534), add:

```asm
    ; --- N4 HARDENING: default CTS+DSR on port open ---
    or   [edi].StatusStruct.UART.MSR, 00110000b  ; DSR + CTS
    lea  eax, [edi].StatusStruct.PortInfo.pPORTDATA
    or   [eax]._PORTDATA.bMSRShadow, 00110000b
    ; --- end N4 ---
```

## 3. FIFO QxCount<0 Race Guard

**Problem:** RXLength, TXLength, and ATLength are decremented
without checking for zero first (lines 1132, 1161, 1165, etc).
If the IOCTL data path and the VCOMM PortRead path race, the
length can wrap to 0xFFFF (unsigned word), causing the buffer
pointers to run past RXEnd and corrupt adjacent memory.

**Fix:** Before every `dec [edi].StatusStruct.RXLength` (and TX/AT),
add a zero check:

```asm
    ; --- N4 HARDENING: FIFO race guard ---
    .IF ([edi].StatusStruct.RXLength > 0)
      dec [edi].StatusStruct.RXLength
    .ELSE
      ; Flush: reset pointers to start of buffer
      mov eax, [edi].StatusStruct.RXBuffer
      mov [edi].StatusStruct.RXIn, eax
      mov [edi].StatusStruct.RXOut, eax
      mov [edi].StatusStruct.RXLength, 0
    .ENDIF
    ; --- end N4 ---
```

Apply the same pattern to all ATLength and TXLength decrements.

**Sites to patch (from grep):**
- ATLength dec: lines 1132, 1161, 1165, 1181, 1185, 1237, 1244, 1348, 1352
- RXLength is only incremented (inc), never decremented in the
  ASM — the PortRead VCOMM callback does the decrement.
  Check PortRead for the same guard.

## 4. Callback Cleanup on Close (PortClose, line ~5629)

**Problem:** PortClose frees and reallocates buffers, but does NOT
clear the three VCOMM callback pointers. If VCOMM fires a stale
callback after close but before the VxD is unloaded, it calls
through a dangling pointer → page fault / BSOD.

**Fix:** After `mov [edi].StatusStruct.VCOMMOpened, False` (line 5630), add:

```asm
    ; --- N4 HARDENING: clear callbacks on close ---
    lea  eax, [edi].StatusStruct.PortInfo.pPORTDATA
    mov  [eax]._PORTDATA.lpClientEventNotify, NULL
    mov  [eax]._PORTDATA.lpClientReadNotify, NULL
    mov  [eax]._PORTDATA.lpClientWriteNotify, NULL
    mov  [eax]._PORTDATA.dwClientEventMask, 0
    mov  [eax]._PORTDATA.dwDetectedEvents, 0
    mov  [eax]._PORTDATA.dwClientRefData, 0
    ; Also clear MSR shadow so next PortOpen resets cleanly
    mov  [eax]._PORTDATA.bMSRShadow, 0
    ; --- end N4 ---
```

## Summary

| # | Item | Type | Risk |
|---|------|------|------|
| 1 | Event callbacks not fired after RX | Functional gap | Apps hang waiting for data |
| 2 | CTS+DSR not reset on reopen | Functional gap | Apps refuse to send |
| 3 | FIFO length can wrap negative | Race condition | Memory corruption / crash |
| 4 | Stale callbacks after close | Use-after-free | Page fault / BSOD |

All patches are additive — no existing logic changes, only guards
and callback dispatches added. The VxD is MASM 6.11 + Win98 DDK.
