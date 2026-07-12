# com0com (virtual-COM fallback) — how it works on modern Windows

Research into the Option B/C virtual-COM fallback: what com0com uses and how to
make it run on modern 64-bit Windows. Bottom line: it works via PRE-1607 signed
builds, but it carries a kernel-driver-signing dependency the FOSSIL-TSR path
avoids — so it stays the FALLBACK.

## What com0com is
A **kernel-mode virtual serial port driver** (GPLv2, by vfrolov; official home =
SourceForge). Creates virtual COM port PAIRS (CNCA0 <-> CNCB0) that act as a
null-modem cable: data into one port appears instantly on the other. Configured
via setupc.exe (CLI) or SetupG.exe (GUI); ports renameable to COMx.

## The problem on modern Windows
Because it's KERNEL-MODE, com0com hits the exact signing wall we documented:
- The official 3.0.0.0 (2017) signed build uses an old SHA-1 cert that Win10/11
  security (HVCI, Driver Signature Enforcement) no longer trusts -> **Code 52**
  ("cannot verify the digital signature").
- Root cause = policy: since **Windows 10 build 1607**, Windows won't load any NEW
  kernel-mode driver unless signed via Microsoft's Dev Portal. Self-signing a
  kernel driver is effectively dead (matches netmodem2irc_driver_signing_notes.md).

## Working approaches on modern Windows (cleanest first)
1. **Pre-1607 signed 3.0.0.0 build** — signed before the 1607 cutoff, so Win11
   still accepts the cert "to this day" (reported working on Win11 23H2). Cleanest:
   no Secure Boot disable, no Test Mode. Inconsistent for some users, though.
2. **Older 2.2.2.0 signed build** — installs on Win10/11 without disabling Secure
   Boot. Tradeoff: ports appear under a "com0com - serial port emulators" category
   in Device Manager (not under "Ports"); lacks some 3.0 features.
3. **Test Mode** (`bcdedit /set testsigning on`) — works with unsigned build, but
   Test Mode watermark, weakened security, FAILS with Secure Boot on, and breaks
   anti-cheat/some software.
4. **Windows Update search** in Device Manager sometimes pulls a valid signed
   driver. Hit or miss.

## Provenance caution
A third-party site (com0com.com) advertises a "2026 signed build" signed by a
different entity ("FuJian Newland"). This is NOT the official SourceForge project.
For a preservation project that values clean provenance, VERIFY the source and
signature independently before trusting any third-party-signed kernel driver. Use
the official SourceForge project + its known-good pre-1607 builds as the reference.

## How this maps to netmodem2irc (reinforces our architecture)
| Path | Signing situation |
|------|-------------------|
| FOSSIL TSR (PRIMARY) | 16-bit TSR runs INSIDE the VM -> NO Windows signing needed |
| com0com virtual-COM (FALLBACK) | kernel driver -> full signing wall (pre-1607 build or Test Mode) |

com0com is exactly the kind of dependency the FOSSIL-TSR path lets us AVOID.
Leaning on it means inheriting its signing baggage (fragile pre-1607 cert, or Test
Mode compromise). That is precisely why FOSSIL is primary and virtual-COM is the
fallback for the rare door that needs a raw COM port instead of FOSSIL.

## Practical answer to "make it work on modern OSes"
Use the official SourceForge **pre-1607 signed com0com** (3.0.0.0, or 2.2.2.0 if
3.0 fails) — no Test Mode required. Good enough for the fallback path. But it is a
dependency-with-baggage we don't control, so it does not displace the FOSSIL TSR.
