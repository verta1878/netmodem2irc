# com0com + com2tcp source analysis — prior art and cross-validation

Analysis of the uploaded com0com-2.2.2.0 and com2tcp-1.3.0.0 SOURCE (both GPLv2,
vfrolov / the com0com project). Two big results: com2tcp is direct PRIOR ART for
netmodem2irc's architecture, and it gives us a THIRD independent Telnet
cross-validation.

## What they are (full source, GPLv2 — compatible with netmodem2irc)
- **com0com-2.2.2.0** — the kernel-mode null-modem driver (sys/ = the .sys driver
  in C; setup/setupc/setupg = install tools). This is the PRE-1607 version our
  research flagged as Secure-Boot-friendly. Full driver source present.
- **com2tcp-1.3.0.0** — a COM<->TCP redirector (Win32 app). With com0com, it lets
  COM-based apps talk to TCP/IP apps, incl. a remote serial port over TCP. Has a
  full Telnet layer (telnet.cpp/telnet.h).

## BIG FINDING 1 — com2tcp is direct prior art for our architecture
com2tcp's own ReadMe example: take a DOS terminal app (TERM95.EXE from Norton
Commander) and connect it to a TELNET SERVER by bridging COM<->TCP with Telnet:
    com0com makes a COM2 <-> CNCB0 pair
    com2tcp --telnet \\.\CNCB0 your.telnet.server telnet
    TERM95.EXE runs on COM2
That is ALMOST EXACTLY netmodem2irc's job (DOS app -> virtual serial -> Telnet ->
remote), solved via the com0com+com2tcp combo instead of a FOSSIL driver. So:
- It VALIDATES the whole netmodem2irc concept — this bridge is proven, shipped,
  used for 20+ years.
- It shows the VIRTUAL-COM fallback path in full: com0com (the pair) + com2tcp
  (the COM<->Telnet redirector) is a working, GPLv2 reference for Option B/C.
- Our FOSSIL-TSR path replaces BOTH pieces (driver + redirector) with one 16-bit
  TSR that needs no Windows signing — but com0com+com2tcp is the ready-made
  fallback for the rare raw-COM door, and now we have its source.

## BIG FINDING 2 — a THIRD independent Telnet cross-validation
com2tcp's telnet.cpp constants: cdSE=240, cdSB=250, cdWILL=251, cdWONT=252,
cdDO=253, cdDONT=254, cdIAC=255 — IDENTICAL to our NetTransport AND ELECOM TELNET.
And its changelog notes "Added missing IAC escaping"; the code escapes cdIAC (255)
— the SAME binary-safety (IAC doubling) our NetTransport independently implements.

So THREE independent Telnet implementations across ~25 years now agree with ours:
  1. our NetTransport (netmodem2irc)
  2. ELECOM TELNET (Maarten Bekers)
  3. com2tcp telnet.cpp (vfrolov / com0com project)
All three: same IAC/DO/DONT/WILL/WONT/SB/SE/BINARY values, same IAC-escaping for
8-bit-clean data. Our transport is now triple-cross-validated.

## Practical value
- com0com 2.2.2.0 source (incl. the .sys driver) is preserved here — the
  Secure-Boot-friendly fallback, with source for study/audit (GPLv2).
- com2tcp is a working COM<->Telnet redirector reference (GPLv2) — if the
  virtual-COM fallback is ever built out, this is the proven model, and its
  Telnet layer already matches ours.
- Neither displaces the FOSSIL-TSR primary path (no signing needed), but both are
  now understood, sourced, and license-compatible for the fallback.

## Attribution
com0com and com2tcp are (c) Vyacheslav Frolov, GPLv2. Any use in netmodem2irc's
fallback path must honor GPLv2 and credit the com0com project. netmodem2irc is
itself GPLv2, so this is compatible.
