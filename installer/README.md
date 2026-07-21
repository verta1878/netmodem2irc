# Inno Setup 5.6.1 — FPC Port

Inno Setup 5.6.1 ported to FPC 2.6.4irc for Win98 compatibility.
Uses real LCL (no VCL stubs). Requires fpc264irc r3.1 Phase 9.

## Contents

```
innosetup-5.6.1-src.tar.gz       — original Delphi source
innosetup-5.6.1-fpc-src.tar.gz   — FPC-patched source
netmodem2irc.iss                  — installer script for NetModem/32
INNO_FPC_PORT.md                  — phases, build instructions, status
INNO_FPC_WORKMAP.md               — detailed audit (original vs ours)
INNO_FPC_PORT_FEATURES_LIST.md    — what's missing per phase
INNO_HOLLOW_FEATURES.md           — hollow features detail
out/                              — compiled Win32 binaries
```

## Compiled Binaries (i386-win32)

| File | Size | Status |
|------|------|--------|
| ISCC.exe | 437KB | ✅ Command-line compiler |
| ISCmplr.dll | 749KB | ✅ Compiler DLL |
| Setup.exe | 14MB | ✅ Compiles (runtime hollow) |
| SetupLdr.exe | 313KB | ✅ Setup loader |

## Phase Status

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | ISCC.exe (console compiler) | ✅ Done |
| 2 | Compression libraries | ✅ Done |
| 3 | LCL integration | ✅ Done |
| 4 | LZMA decompression | Next — C source in-tree, MinGW cross-compile |
| 5 | Windows resources | fpcres in fpc264irc, .rc files in-tree |
| 6 | DFM → LFM forms | lazres + lrstolfm in fpc264irc |
| 7 | PascalScript [Code] | Full source in fpc264irc (35,000 lines) |
| 8 | Compil32.exe (IDE) | 5 ScintEdit fixes |
| 9 | SetupCompat + runtime test | Build netmodem2irc installer |

All toolchain support for Phases 4-8 confirmed in fpc264irc Phase 9.
See INNO_FPC_PORT.md for details.
