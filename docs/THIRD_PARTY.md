# netmodem2irc — third-party libraries

## Ararat Synapse (TCP/IP library) — the one dependency

The NT-branch transport's real socket backend (NM_SynapseLink.pas) uses
**Ararat Synapse**, a Pascal TCP/IP library.

### License & cost — FREE, and bundle-legal
- **Free / open source**, under a **modified BSD-style license** (per the
  project's own download page). Copyright (c) 1999-2024 Lukas Gebauer.
- The modified-BSD license is **compatible with this repo's GPLv2** — so Synapse
  MAY be bundled into the repo (unlike Watt-32 in fpc264irc, whose licensing kept
  it reference-only). Bundling is legal here.

### Where to get it (verified)
- **Official repository (current):** https://github.com/geby/synapse
  (moved from SourceForge to GitHub in January 2024 — this is authoritative).
- **SourceForge (older):** the `synalist` project (older releases).

### Why it fits netmodem2irc
- "Not a components suite, but a group of classes and routines. No installation
  needed — just add the units to your uses clause." => trivial to bundle.
- Compiles with **FreePascal AND Delphi** (also C++Builder, Kylix) => matches
  both the fpc264irc toolchain and classic-Windows targets.
- **Blocking sockets** (with limited non-blocking mode) on Windows/Linux/POSIX;
  native **Telnet** support => exactly the model a modem<->TCP bridge wants.
- Core class used: **TTCPBlockSocket** (unit `blcksock`), the class the NetModem
  docs already specified.

### NOTE: no "FPC/Delphi equivalent" needed
Synapse IS the FreePascal/Delphi library — it's free and supports FPC natively,
so there is no need to substitute a different library. (An alternative, **lNet**,
exists and is also free, but it's event-driven/async; Synapse's blocking model is
the simpler fit for the pump-loop transport. Synapse is the primary choice.)

### Inclusion decision (bundle / reference / submodule)
Since license is NOT a blocker here, and the project values being self-contained
for "the person who can't chase dependencies":
- **Recommended: git submodule** pointing at github.com/geby/synapse — Synapse
  appears in-tree, stays current, one clone, no stale copy.
- **Alternative: bundle** a copy in e.g. `libs/synapse/` — fully self-contained,
  license-OK, but a stale-copy maintenance burden.
- **Minimum: reference** — document "install Synapse + build with -dHAS_SYNAPSE".
NM_SynapseLink.pas is written so the repo BUILDS WITHOUT Synapse (stub returns nil
from CreateSocketLink); define -dHAS_SYNAPSE + add Synapse to the unit path for a
real networked build.

## Everything else: no third-party dependencies
The emulation units (NM_UART16550, NM_Fossil, NM_ATCommand) and the transport
logic (NetTransport) depend only on the FPC RTL (SysUtils) and each other. Synapse
is the ONLY third-party lib, and only for the real socket backend.

---

## STATUS UPDATE: Synapse is now BUNDLED in the source

The real Ararat Synapse core units are bundled in **libs/synapse/**, cloned from
the official repo (github.com/geby/synapse). This makes the NT branch
self-contained — no separate Synapse download needed.

### What's bundled (libs/synapse/)
Core units needed by NM_SynapseLink + their dependencies:
  blcksock.pas   (TTCPBlockSocket — the class we use)
  synsock.pas    (socket layer)
  synautil.pas, synaip.pas, synafpc.pas, synacode.pas, synaser.pas
  all *.inc files (jedi.inc + platform selectors ssfpc/sswin32/sslinux/etc.)

### License (verified from the actual source headers)
Modified BSD: "Copyright (c)1999-2026, Lukas Gebauer ... Redistribution and use
in source and binary forms, with or without modification, are permitted..."
=> GPLv2-compatible, bundling is legal. Keep the copyright headers intact (they
are embedded in each .pas file — do not strip them).

### VERIFIED
- Stub build (no -dHAS_SYNAPSE): compiles, CreateSocketLink returns nil.
- Real build (-dHAS_SYNAPSE -Fu libs/synapse -Fi libs/synapse): NM_SynapseLink
  compiles clean against the bundled Synapse (14,524 lines). Our API usage
  (Connect/SendBuffer/RecvBufferEx/NonBlockMode/LastError/WSAEWOULDBLOCK/
  WSAETIMEDOUT/CloseSocket) matches real Synapse with no warnings.
- STILL PENDING: runtime test over a live TCP connection (compile-verified here,
  but actual send/recv against a real BBS must be tested on a real build).

### Build command for the real (networked) NT server
  fpc -Mobjfpc -dHAS_SYNAPSE -Fu libs/synapse -Fi libs/synapse <your program>
