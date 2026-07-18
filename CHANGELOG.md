# Changelog

## Current — full config GUI, global settings, installer

- ConfigMain: all 11 per-node fields + 25 global settings wired to GUI
  (5 tabbed pages: Comports, Server, Logging, Options, Features)
- NM_GlobalConfig: server-level settings (registry + NETCONFIG.CNF)
- NM_Listserv: BBS directory registration (designed by Dedrick, never finished)
- NM_AutoNews: periodic news broadcast (designed by Dedrick, never finished)
- Original NETMODEM.CPL (657KB, Delphi 5) preserved and shipped as-is
- Icons: 14 icons + 36 bitmaps extracted from original CPL
- Globe + splash bitmaps extracted from TForm1
- Inno Setup installer script (installer/netmodem2irc.iss)
- build.sh: win32/tests/fossil/resources/clean targets
- 38/38 tests, 0 failures
- fpc264irc r3.1+

## M1 — engine integrated

- Engine: UART 16550, FOSSIL INT 14h, Telnet transport, AT commands,
  multinode manager, Synapse + named-pipe links, server bridge
- NM_Config: all 11 per-node ComportStruct fields, 14 baud rates
- NM_DefaultConfig: factory defaults, registry read/write
- NMVxD: driver interface with {$IFDEF WINDOWS} guards
- SEAM protocol: driver↔server framed binary protocol
- TSR skeleton: FOSSIL resident-program framework
- Win32 cross-compile from Linux
- DOS i8086 FOSSIL bridge (netfossl.exe, 179KB)
- 38 test programs covering all engine units

## M0 — initial recovery

- Recovered Dedrick Allen's original NetModem/32 source
- VxD driver (NETMODEM.ASM/INC/DEF) — experimental
- Original distributions preserved (net32_b4, netmdb15)
- Original CPL binary + 6 decompiled DFM forms
