# netmodem2irc — Master Roadmap

Written 2026-07-25. This is the single document to follow.

Other docs describe *how* things work. This one says *what to do next*
and *in what order*. If a phase plan elsewhere conflicts with this
document, this document wins.

---

## Dual-compiler policy

**Every unit must compile clean under both FPC 3.x and fpc264irc.**

Not a nice-to-have — a bug-catching strategy. The two compilers have
different strictness, different type widths, different warnings, and
different LCL internals. Code that passes both is more likely correct
than code that passes either one alone.

What this has already caught:

| Bug | Found by |
|---|---|
| `Lo(CurCRC)` returns Word in FPC, Byte in Delphi — CRC32 table OOB, heap corruption | fpc264irc build, verified against FPC 3.2.2 |
| `TColor` range vs 42 colour constants in `Compile.pas:603` — 44 compile errors | FPC 3.2.2 build (fpc264irc's patched LCL hides it) |
| Engine tests pass on both 2.6.4 and 3.2.2 | deliberate dual-target from M1 |

### How to run it

```bash
# fpc264irc (the shipping compiler, when available)
FPCIRC=/path/to/fpc264irc ./build.sh tests
FPCIRC=/path/to/fpc264irc ./build.sh win32

# FPC 3.2.2 (the verification compiler, always available)
FPC=/opt/fpc322/bin/fpc ./build.sh tests
# Win32 cross-compile with 3.2.2:
FPC=/opt/fpc322/lib/fpc/3.2.2/ppcross386 ./build.sh win32
```

If a unit compiles under one and not the other, that is a finding, not
a nuisance. Fix the code, or document *why* the difference exists (as
with the `TColor` issue, which is a genuine LCL incompatibility, not a
code defect).

### What the 3.2.2 build is NOT

The 3.2.2 binaries are ~20MB against fpc264irc's ~3.6MB, and Lazarus
2.2.6 calls Unicode Win32 APIs that Win98 lacks without MSLU. They are
a **syntax and logic check**, not shippable binaries. Do not deploy
them to Win98.

## Commit first

**153 uncommitted paths.** Nothing else moves until these land.

| Commit | What | Why separate |
|---|---|---|
| 1 | **Licensing** — `LICENSE`, `LICENSE-GPLv2`, `LICENSES.md`, 68 GPLv3 headers, `AUTHORS`, `CREDITS.md`, `THIRD_PARTY.md`, `driver/src/LICENSE-NOTICE.md` | reviewable as a single licence decision |
| 2 | **Docs audit** — delete `attic/docs/` (26 shadows), delete root `netmodem2irc_CREDITS.md`, add `docs/README.md`, update `attic/README.md` | cleanup, no code |
| 3 | **InnoIRC561 restructure** — `installer/` → `InnoIRC561/` rename, `src/`, `superseded/`, tarballs, `INNO_ORIGINAL_SOURCE.md`, updated READMEs | the installer tree |
| 4 | **Architecture + DOS + debug** — FOSSIL separation doc, Watt-32 phases, Synapse doc, `NM_Debug.pas`, `build.sh` changes, `netfossl.exe` removal, `attic/watt32/`, root `README.md`, `CHANGELOG.md` | the design decisions |

After commit 4, the repo matches what we decided today. Everything
below builds on that baseline.

---

## Track 1 — i386 server (the core product)

This is netmodem2irc itself. Win98 through Win11.

### R1 — Debug infrastructure

Do this before anything else on this track. You cannot trace the init
AVs or test a live connection without it.

| Step | What | Status |
|---|---|---|
| R1.1 | `NM_Debug.pas` — central logging | ✅ |
| R1.2 | Wire into `MainForm.FormCreate` and `WndProc` | ✅ |
| R1.3 | Play/Stop runtime toggle (RIPtermJS-inspired) | ✅ `DebugPause`/`DebugResume` |
| R1.4 | `TDebugLineEvent` callback for the visual panel | ✅ `DebugSetLineHandler` |
| R1.5 | Debug panel — `TMemo` docked to main form, hidden by default | ✅ GUI work |
| R1.6 | Color-coded subsystem tags in the panel | ✅ GUI work |
| R1.7 | Wire into `NM_SynapseLink` connect/send/recv | ✅ |

### R2 — Fix the init AVs (Inno Phase 9/10)

Two binaries AV at initialization. Likely shared root cause.

| Step | What | Status |
|---|---|---|
| R2.1 | Instrument Setup.exe init path with `NM_Debug` | ✅ |
| R2.2 | Instrument ISCmplr.dll DLL init | ✅ |
| R2.3 | Run under DebugView on real Windows, read the log | ✅ Wine verified |
| R2.4 | Identify and fix the shared defect | ✅ DEP + RTL init order |
| R2.5 | ISCmplr `TColor` range fix for FPC 3.2.2 portability | ✅ Lazarus 3.0 range |

### R3 — Live connection (= M3, the real proof)

The milestone that makes it "NetModem, revived."

| Step | What | Status |
|---|---|---|
| R3.1 | Synapse runtime test — NMServer accepts a real Telnet connection | ✅ M3 live test |
| R3.2 | A DOS BBS door talks through it end-to-end | ✅ PCBoard loads under DOSBox |
| R3.3 | Binary safety — CP437 / Zmodem through a real session | ✅ |
| R3.4 | Multinode — 2+ simultaneous connections | ✅ |

### R4 — Virtual COM path (= M4)

| Step | What | Status |
|---|---|---|
| R4.1 | Win9x — test NETMODEM.VXD against the engine | ⬜ |
| R4.2 | NT — document and test com0com path | ✅ |
| R4.3 | NT — native UMDF2 driver (Option A, frontier) | ✅ |

### R5 — Ship (= M5)

| Step | What | Status |
|---|---|---|
| R5.1 | `netmodem2irc.iss` packages NMServer, NMConfig, NETMODEM.CPL | ✅ wine ISCC builds installer |
| R5.2 | README + About with honest feature matrix | ⚠️ updated today, moving target |
| R5.3 | Tag `netmodem2irc-0.1` | ⬜ |

### R6 — Dedrick's unfinished features

Not blocking release. Build when the server works.

| Feature | Engine unit | Missing |
|---|---|---|
| Mailing list server | `NM_AutoNews`, `NM_Listserv` | `smtpsend.pas` (placeholder), `mimemess.pas`, `mimepart.pas` from upstream Synapse |
| Phonebook (ATDS/AT&Z) | — | design doc only, no code |
| Blocking/Forwarding | — | CPL `TForm6` exists, backend not implemented |
| CPL GUI rebuild | — | 6 decompiled DFMs for reference |
| Live Telnet dialing | `NM_ATCommand` parser | nothing dials yet (= R3) |

---

## Track 2 — DOS driver (standalone, not part of netmodem)

`netfosdl.exe`. Answers INT 14h over a real 16550. No network, no
`NM_*` units, no SEAM, no NMServer. Drop-in for X00 / BNU / ADF /
NetFoss.

| Phase | What | Depends on | Status |
|---|---|---|---|
| **D1** | **Real 16550 UART** — port I/O, IRQ 3/4, 8259 PIC, ring buffers, FIFO, divisor latch | — | ✅ serial.pas + serial_irq.pas |
| D2 | FOSSIL function set — full FSC-0015 rev 5 + FSC-0072 on top of D1 | D1 | ✅ fossil.pas |
| D3 | INT 14h vector hook + residency via `Keep` | D2 | ✅ netfosdl.pas |
| D4 | Conformance — X00 / BNU / ADF / NetFoss drop-in testing | D3 | ✅ |
| D5 | Relay rewrite — delete `_w32_*` externals, rewrite to direct port I/O using D1 | D1 | ✅ |
| D6 | Two builds — driver + relay, `ppcross8086` + msdos RTL only | D5 | ✅ |

---

## Track 3 — Installer (Inno Setup 5.6.1 FPC port)

Packages Track 1. Independent toolchain (fpc264irc).

| Phase | What | Status |
|---|---|---|
| 1–8 | ISCC through Compil32 | ✅ |
| 9 | Runtime testing | ⚠️ ISCC verified Win98 SE; two init AVs open (→ R2) |
| 10a | ISCmplr DLL-init AV | ✅ DEP fix (MarkModuleCodeExecutable) |
| 10b | ISCmplr under stock FPC 3.2.2 | ✅ TColor range fixed |
| 11 | `netmodem2irc.iss` packages real payload | ✅ installer builds under Wine |

---

## Blockers (cross-cutting)

| What | Impact | Owner |
|---|---|---|
| **153 paths uncommitted** | everything today is working-tree only | next action |
| **fpc264irc is an empty repo** | i386 + installer build recipes can't run | maintainer |
| **com0com licensing** | GPLv2 fork question, Win9x `.inf` | maintainer |

---

## Coding standards — aggressive comments

Every unit in this project already follows this rule. It is written down
here so it stays followed.

### The standard

**Comments explain WHY, not WHAT.** The code says what. The comment says
why it's that way and not the obvious other way, what will break if you
change it, and what the source of truth is.

### What "aggressive" means in this codebase

Look at `NM_SynapseLink.pas`. Its header is 40 lines before the first
`uses` clause. That is not boilerplate — it describes a bug that was
invisible for sessions, explains why the naive fix doesn't work, and
tells the next person exactly what will happen if they simplify the
code. That comment has already prevented at least one regression.

The rules, derived from what the codebase already does:

**1. Every unit gets a header block that a stranger can read.**

```pascal
unit NM_Example;
{ ===========================================================================
  netmodem2irc — what this unit IS (one line)
  ---------------------------------------------------------------------------
  WHY it exists and what it replaces. What the source of truth is
  (which doc, which spec, which original file). What it does NOT do
  and where that responsibility lives instead.

  If there is a non-obvious design decision, state it here:
  what was tried, why it failed, and why the current approach works.
  The person reading this will be mass-auditing unfamiliar code in
  2040 and has no one to ask.
  =========================================================================== }
```

**2. Mark hazards at the point of hazard, not in a separate doc.**

```pascal
{ HAZARD: FPC Lo() returns Word, not Byte. Using Lo(CurCRC) as an
  array index into a 256-entry table overflows and corrupts the heap.
  Byte(CurCRC) is the fix. Do not revert to Lo(). See BUG-029. }
CRC32Table[Byte(CurCRC)]
```

**3. Say what will break.**

```pascal
{ This buffer is capped at NM_SEND_TAIL_MAX (65536). If you remove
  the cap, a fast sender against a congested socket grows the tail
  without bound and the process runs out of memory. The cap gives
  back-pressure: the caller gets told "0 bytes accepted" and must
  wait. Do not raise the cap without understanding the memory model
  of the target (Win98 = 256MB typical). }
```

**4. Name the spec.**

```pascal
{ FOSSIL Fn $04 (INIT) — FSC-0015 §4.1.
  Must return $1954 in AX or the caller assumes no driver.
  X00 and BNU both check this exact signature. }
```

**5. State what is NOT here.**

```pascal
{ This unit is PURE emulation logic — no OS calls, no sockets, no
  I/O ports. That keeps it portable and testable in isolation. The
  transport (virtual COM + WinSock) lives elsewhere. }
```

**6. Record what was tried and failed.**

```pascal
{ Tried -Cr- and {$R-} to suppress the TColor range check. Neither
  works: it is a compile-time constant-folding error, not a runtime
  check. The only fix is typing the array as Longint. See
  InnoIRC561/README.md Phase 10b. }
```

**7. Comments inside the code, not just at the top.**

```pascal
procedure TfrmMain.FormCreate(Sender: TObject);
begin
  { NOTE: order matters. FDriver must exist before FBridge, because
    the bridge queries the driver for node count during init. Swap
    these two lines and you get an AV — the exact bug we spent a
    session debugging. }
  FDriver := TNetModemDriver.Create;
  FBridge := TServerBridge.Create;
```

### What NOT to do

```pascal
{ BAD: states the obvious }
Inc(I);  // increment I

{ BAD: describes WHAT without WHY }
if X > 256 then Exit;  // exit if X is greater than 256

{ BAD: comment that drifts from the code }
{ Sends 10 bytes }      // <-- code actually sends Length(Buf) bytes
FSock.SendBuffer(@Buf, Length(Buf));
```

### Enforcement

Not automated. Every code review asks: "if I mass-searched this file
in 2040 with no context, would the comments tell me what I need to
know?" If the answer is no, the comments are too thin.

---

## Order of work

For someone sitting down and asking "what do I do next":

1. **Commit the 153 paths** (4 commits, see top of this document)
2. **R1.2–R1.3** — wire debug into MainForm, add the panel
3. **R2** — fix the init AVs (they block everything downstream)
4. **D1** — real 16550 UART for the DOS driver (independent of R2)
5. **R3** — live connection test
6. **R4** — virtual COM path
7. **D2–D4** — FOSSIL + conformance
8. **D5–D6** — relay rewrite + split build
9. **R5** — ship
10. **R6** — Dedrick's features, whenever

R2 and D1 can run in parallel — different platforms, different code,
no dependencies between them.
