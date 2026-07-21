# LZMA Decoder Object Files

Pre-compiled MinGW COFF .o files for LZMA decompression.
These replace the original Borland C++Builder .obj files that
FPC cannot link (COFF format incompatibility).

## Files

| File | Source | Purpose |
|------|--------|---------|
| ISLzmaDec.o | Lzma2/Decoder/ISLzmaDec.c | LZMA1 decoder (Setup.exe) |
| ISLzma2Dec.o | Lzma2/Decoder/ISLzma2Dec.c | LZMA2 decoder (Setup.exe) |
| LzmaDecodeInno.o | LzmaDecode/LzmaDecodeInno.c | Small decoder (SetupLdr.exe) |

## How they were built

```bash
# LZMA1 + LZMA2 (from issrc-is-5_6_1/Projects/Lzma2/Decoder/)
i686-w64-mingw32-gcc -c -O2 -I../C ISLzmaDec.c -o ISLzmaDec.o
i686-w64-mingw32-gcc -c -O2 -I../C ISLzma2Dec.c -o ISLzma2Dec.o

# Small decoder (from issrc-is-5_6_1/Projects/LzmaDecode/)
i686-w64-mingw32-gcc -c -O2 -D_LZMA_OUT_READ -D_LZMA_IN_CB LzmaDecodeInno.c -o LzmaDecodeInno.o
```

## Rebuilding

Only needed if the LZMA SDK source changes. Requires
`gcc-mingw-w64-i686` (`apt install gcc-mingw-w64-i686`).
The .o files are i386 COFF — platform-neutral, work on any
host OS with FPC's GNU ld.
