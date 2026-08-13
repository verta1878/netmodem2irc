# netmodem2irc — Known Bugs

Updated: 2026-08-12

## FIXED

| ID | Description | Fix |
|----|-------------|-----|
| BUG-001 | paswstring.pas callback signature | ✅ patched cwstring.pp |
| BUG-002 | win32wsstdctrls.pp += operator | ✅ replaced with := + |
| BUG-003 | PPU checksum cascade after clone | ✅ touch workaround + cycle-build |
| DEP-001 | ISCmplr.dll AV (c0000005) | ✅ MarkModuleCodeExecutable |
| DEP-002 | TColor range (Lazarus 2.2.6) | ✅ Lazarus 3.0 full LongInt range |
| WINE-001 | FPC 2.6.4 critical section deadlock | ✅ InitSystemThreads moved |
| WINE-002 | SafeDLLPath LoadLibrary in DllMain | ✅ IsLibrary guard |
| FPC-001 | FPC Lo(200) returns nibble not byte | ✅ use (V and $FF) |
| FOSSIL-001 | ASYNC_SETPORT wrong signature | ✅ (long baud, int databits) |
| FOSSIL-002 | Missing PCBoard globals in Pascal | ✅ added 13 globals |
| DOS-IDLE | netfosdl CPU hog — no idle call | ✅ DosIdle INT 2Fh/1680h |
| LCL-7182 | LCL DLL loader lock deadlock | ✅ patch + LCLDeferredInit |
| WINE-GUI | Setup.exe hangs under Wine headless | ✅ same fix as LCL-7182 |
| L-1 | FillChar on AnsiString record | ✅ individual assignment |
| L-2 | NM_Listserv LoadFromFile no try | ✅ {$I-} + try/finally |
| L-3 | NM_Listserv SaveToFile no try | ✅ {$I-} + try/finally |
| A-1 | NM_AutoNews LoadNewsText no try | ✅ {$I-} + try/finally |
| G-1 | NM_GlobalConfig LoadFromFile no try | ✅ {$I-} + try/finally |
| G-2 | NM_GlobalConfig SaveToFile no try | ✅ {$I-} + try/finally |
| P-1 | MCR loopback not wired | ✅ THR→RX when MCR bit 4 set |
| P-2 | XON/XOFF not intercepted in TX | ✅ SetSoftFlow + Pump filter |
| P-3 | X00 Fn20h extended RX — no-op | ✅ UartGuestToNet read |
| P-4 | X00 Fn21h RX inject — no-op | ✅ UartNetToGuest write |
| P-5 | INT14 7Eh/7Fh signature — missing | ✅ returns 1954h + BL=AL |

## ARCHITECTURE NOTES (not bugs)

| ID | Description | Status |
|----|-------------|--------|
| P-6 | Ring buffer thread safety | OK single-threaded; add locks for MT |
| P-7 | TX full yield | ISocketLink handles backpressure |

## DEFERRED (hardware-dependent)

| ID | Description | Needs |
|----|-------------|-------|
| M4 | Virtual COM path (VxD/com0com/UMDF2) | real hardware |
| R4.1 | Win9x VxD test | Win98 VM |
