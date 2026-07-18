# Retired Code

## netfossl.pas
Copy of `fossil_dos.pas` with the unit renamed from `Unit fossil_dos` to
`Unit netfossl` to match the original NetModem naming (NETFOSSL.EXE).
Retired because we kept the `fossil_dos` name to match the PPU already
in the fpcirc repo. The active version is `../fossil_dos.pas`.

## netmodem_fossil.pas
FOSSIL-only test build — no TCP/IP. Used during development to verify
the FOSSIL INT 14h driver worked before the TCP side was ready.
Successfully compiled and linked to a 32KB nm.exe. Retired because
`../netmodem.pas` now has both FOSSIL and TCP in one program.
