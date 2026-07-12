# attic/ — retired files (kept, not deleted)

Files retired from active use but deliberately preserved. Nothing here is built
or shipped; kept so history and dead-ends stay visible. See the rule below.

## Rule for retiring a file
Record: what it was, when/why retired, what replaced it. Keep content intact
(it's an artifact — don't "fix" it here).

## Retired files
| File | Retired | Reason | Replaced by |
|------|---------|--------|-------------|
| WIN32COM.PAS | (ELECOM) by author, ~2000-01 | Author (Maarten Bekers) deprecated it: the unit's own header says "This unit is not supported anymore... The next release of EleCOM will not include WIN32COM.PAS anymore." Retired to keep the ELECOM source clean. | W32SNGL.PAS |

## Historical note — the Virtual Pascal → Free Pascal migration
ELECOM (and much of the BBS/FidoNet Pascal world) was written to compile on BOTH
**Virtual Pascal** (VP/VPC — a 32-bit OS/2+Win32 Pascal compiler by Vitaly
Miryanov / Allan Mertner, very popular for OS/2 and BBS software) AND early
**Free Pascal** (0.99.x). Around FPC 0.99.x / 1.0 (late 1990s–early 2000s),
Virtual Pascal lost active development, and Free Pascal became its successor —
32-bit, multi-platform, TP-dialect-compatible, and able to target OS/2 + Win32 as
VP did. That is why ELECOM's source is full of `{$IFDEF VirtualPascal}` forks and
the `WINDEF.FPC` include (which made FPC's Win32 API declarations match what VP
and Delphi expected).

Relevance to porting: the `{$IFDEF VirtualPascal}` blocks are effectively DEAD
CODE for a modern FPC build and can eventually be simplified away once the FPC
path is confirmed working. WINDEF.FPC in particular may be redundant/harmful on
modern FPC (whose stock `Windows` unit is now correct) — untangling it is the
central task of getting ELECOM building on modern NT.

## NOT retired (explicitly kept in active source)
- driver/src/VMM.INC (netmodem 9x) — was briefly SUSPECTED corrupt but is VALID
  (CRLF line endings, not corruption). Stays in active source.
