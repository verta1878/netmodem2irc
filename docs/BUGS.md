# netmodem2irc — known fpc264irc bugs

Status as of r3.1 (20260718).

## BUG-001: paswstring.pas callback signature mismatch — ✅ FIXED r3.1

Callback signatures patched in cwstring.pp + paswstring.pas.
Added `cp: TSystemCodePage` parameter to Wide2AnsiMove, Ansi2WideMove,
Unicode2AnsiMove, Ansi2UnicodeMove.

## BUG-002: win32wsstdctrls.pp += operator — ✅ FIXED r3.1

Replaced `+=` with `:= ... +` for FPC 2.6.4 compatibility.

## BUG-003: PPU checksum cascade after git clone — ⚠️ OPEN

Git clone sets all source timestamps to clone time (newer than PPUs).
Compiler tries to recompile everything, cascades into checksum errors.
Needs build script fix (Phase 0). Workaround: `find bin/units
bin/lazarus/units \( -name "*.ppu" -o -name "*.o" \) -exec touch {} +`

## BUG-004: ActiveX/variants checksum cascade — ✅ FIXED r3.1

Fixed — 75 Win32 RTL PPUs consistent, Win32 LCL built (404 PPUs:
59 LazUtils + 213 LCL base + 27 widgetset). Interfaces + Forms
test compiles. Makefile has system.pp skip guard.

## BUG-005: No windres in toolchain — ✅ RESOLVED

Removed from compiler source. windres lives in downstream repos
(e.g. mingw binutils). netmodem2irc uses `i686-w64-mingw32-windres`.

## BUG-006: process.pp checksum mismatch — ✅ FIXED (partial)

Fixed for Darwin (fpvfork→fpfork). Other platforms use pre-built PPU.
Still triggers on cross-compile if system checksum doesn't match.
