# ELECOM — modernization for modern FPC / NT (progress + method)

Carrying Maarten Bekers' ELECOM v1.03 (EleBBS comms library, 1998-2001, written
for Virtual Pascal + early FPC 0.99.x) forward to modern FPC so it can support
netmodem2irc and Mystic. Same "compile it, find real breakage, fix at the right
layer, document" discipline as the netmodem NT stack.

## Context: the Virtual Pascal heritage
ELECOM was written to compile on Virtual Pascal (VP) AND early FPC. VP lost
support in the early 2000s; FPC became the successor. The VP-era code has
`{$IFDEF VirtualPascal}` forks (e.g. `uses Use32;`) that are dead on modern FPC
(the guards correctly skip them) and a `WINDEF.FPC` include that made old-FPC's
Win32 API match VP/Delphi (likely redundant on modern FPC). Untangling the VP
layer is the core of the port.

## Verified environment
Stock FPC 2.6.4 (x86_64), TP mode (-Mtp), against 2.6.4 RTL.

## Unit-by-unit status
| Unit | Status | Fixes needed |
|------|--------|--------------|
| BUFUNIT.PAS | COMPILES CLEAN | none |
| ELEDEF.PAS  | COMPILES (fixed) | see below |
| COMBASE.PAS | pending | uses Use32 (VP-guarded, OK) |
| FOS_COM.PAS | pending | uses Dos, Combase |
| TELNET.PAS  | pending | uses SockFunc/SockDef/Combase/BufUnit/Threads |
| W32SNGL.PAS | pending (Win32) | uses Windows + WINDEF.FPC |
| W32SOCK.PAS | pending (Win32) | WinSock |
| WIN32COM.PAS| RETIRED -> attic | author-deprecated, replaced by W32SNGL |

## Fixes applied to ELEDEF.PAS (the DLL interface unit)
ELEDEF declares the exported Com_* DLL API. Two calling-convention issues that
Virtual Pascal tolerated but modern FPC rejects:

1. **External declarations missing `stdcall`.** VP inherited the convention from
   the interface; FPC requires it restated. Fix: every
   `... external ComNameDLL index N;` becomes
   `... stdcall; external ComNameDLL index N;`
   (stdcall BEFORE external).

2. **One interface declaration missing `stdcall` (latent bug in the original).**
   `Com_ReadyToSend` (interface, ~line 40) lacked `stdcall` while its
   implementation had it -> "Calling convention doesn't match forward." Every
   sibling function had stdcall; this one was omitted in the original source. VP
   silently tolerated the mismatch; FPC does not. Fix: add `stdcall;` to the
   interface decl so it matches.

Result: ELEDEF compiles clean (101 lines) on FPC 2.6.4.

## The pattern (for the remaining units)
VP->FPC breakage so far is calling-convention strictness. Expect similar in the
other DLL-interface/Win32 units. The Win32 units (W32SNGL/W32SOCK) will also need
the WINDEF.FPC question resolved (keep vs drop on modern FPC). None of it is
obsolete-API breakage — the Win32 serial + WinSock APIs ELECOM uses are still
current on Win10/11.

## Honest boundaries
- Win32 units can't be fully built on x86_64-linux; they need a Windows FPC build
  (or win32 cross). Portable units (BUFUNIT, ELEDEF, COMBASE-logic) checked here.
- These fixes are verified to COMPILE; runtime behavior on real NT serial/socket
  hardware is a Windows-build test.
