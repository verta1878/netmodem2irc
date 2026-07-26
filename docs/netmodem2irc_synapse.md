# Synapse — the bundled TCP library, the link unit, and its tests

Written 2026-07-25.

Ararat Synapse is the TCP/IP library NMServer uses on the i386 branch.
Lukas Gebauer, in development since 1999, modified BSD — compatible with
both GPLv2 and GPLv3, which is why bundling it was legal. Upstream:
`github.com/geby/synapse` (moved from SourceForge, January 2024).

**Synapse is not a TCP stack.** It is a Pascal wrapper over the
platform's stack — WinSock on Windows, BSD sockets on Unix. The kernel
runs the protocol; Synapse provides a clean interface to it. This is the
opposite of Watt-32, which *is* the stack and must be pumped by the
application. It is also why Synapse works on i386 and could never work
on DOS: it needs an OS with networking underneath it.

Only the DOS platform avoids it entirely. `netfosdl` is standalone and
has no network of any kind.

## `libs/synapse/` — what each file is

720K, 17 files, cloned from upstream. **Do not strip the per-file
copyright headers** — they are Gebauer's and the licence depends on
them. The GPLv3 headers added to netmodem2irc source in 2026-07 were
deliberately not applied here.

| File | Size | What it is |
|---|---|---|
| `blcksock.pas` | 135K | The core. `TTCPBlockSocket` lives here — the one class this project instantiates. Also UDP, proxies, TLS hooks. |
| `synsock.pas` | 4.2K | Platform selector. Tiny because it contains almost no logic: it includes one of the `.inc` files below depending on target. |
| `synaser.pas` | 73K | `TBlockSerial` — serial port support (SynaSer). **Unused in this project.** See below. |
| `synautil.pas` | 59K | Helpers: time/date formatting, string parsing, buffer utilities. |
| `synacode.pas` | 51K | Encoding — Base64, quoted-printable, UU/XX/yEnc, MIME charsets. |
| `synaip.pas` | 12K | IP address parsing and formatting, v4 and v6. |
| `synafpc.pas` | 7.3K | FreePascal compatibility shim — smooths Delphi/FPC differences. |
| `smtpsend.pas` | **0** | Placeholder — reserves the slot for the future mailing list server. Drop-in from upstream when needed. |
| `jedi.inc` | 99K | Compiler/version detection macros (JEDI project). |
| `sswin32.inc` | 56K | WinSock bindings. |
| `ssfpc.inc` | 28K | FPC `sockets` unit bindings. |
| `sslinux.inc` | 40K | Linux syscall bindings. |
| `ssposix.inc` | 36K | POSIX bindings. |
| `ssos2ws1.inc` | 61K | OS/2 bindings. |
| `ssdotnet.inc` | 35K | .NET bindings. |
| `kylix.inc` | 936 | Kylix compatibility. |
| `SYNAPSE_README.md` | 4.5K | Upstream readme, kept verbatim. |

### The `.inc` files are the point

`synsock.pas` being 4.2K against 250K of `.inc` files is the wrapper
nature made visible: a thin interface over per-platform bindings into
somebody else's stack. Those `.inc` files are where WinSock and BSD
sockets are actually called.

### Two files that are not what they look like

**`smtpsend.pas` is a zero-byte placeholder** — intentionally reserving
the slot for the future mailing list server feature. It is not broken or
missing; it is waiting for the feature to be built. The real Synapse unit
is a drop-in when fetched from upstream (same licence, same API).
`mimemess.pas` and `mimepart.pas`, also needed for the mailing list server,
are not yet present either. See the Roadmap in `README.md`: Auto-News
(periodic SMTP announcement) and BBS Listserv (mailing list
registration) were designed by Dedrick but never implemented.

**`synaser.pas` is unused.** 73K of `TBlockSerial` that could open a
virtual comport from Pascal — plausible-looking, given this project is
about COM ports. But `synaser` and `TBlockSerial` appear nowhere in
`engine/`, `server/`, `config/`, `common/` or `dos/`. NMServer reaches
the comport through the driver's IOCTL / `CM_*` message interface, not
by opening a port by name, so SynaSer was never needed. It is bundled
because it ships with Synapse.

## `engine/NM_SynapseLink.pas`

The real `ISocketLink` implementation, backed by `TTCPBlockSocket`.

**It is the only file in the project that touches Synapse.**
`NetTransport` talks solely to the `ISocketLink` interface, so this unit
can be swapped for an lNet or raw-sockets link without changing any
transport, AT-command, FOSSIL or UART logic. That is the seam that keeps
the dependency optional.

**Build guard.** Synapse is pulled in only under `-dHAS_SYNAPSE`:

```pascal
uses ..., {$IFDEF HAS_SYNAPSE} blcksock, synsock {$ENDIF};
```

Without the define the unit compiles to a stub that reports "not
available" and `CreateSocketLink` returns nil, so the repo builds where
Synapse is absent.

### Why it is more than a pass-through — the partial-send bug

Worth understanding before editing, because the unit looks like it
should be a thin delegation and is not.

`Connect` sets `NonBlockMode := True`, because the transport pumps
non-blocking so one slow node cannot stall the others — the switch
model. In non-blocking mode, **`TTCPBlockSocket.SendBuffer` can accept
fewer bytes than asked** when the kernel's send buffer is full. That is
normal TCP behaviour, not an error.

The earlier version did:

```pascal
FSock.SendBuffer(@Buf, Len);
Sent := Len;              // ASSUMES everything went out
```

Under load — a fast door dumping into a congested socket — the kernel
buffer fills, `SendBuffer` takes only part, and **the unsent tail was
silently dropped**. The caller was told all `Len` bytes were sent, so it
never retried. Nothing errored; throughput just quietly lost data.

**The fix: a bounded per-socket tail buffer.**

- capture `SendBuffer`'s actual return count
- stash whatever it did not take in `FSendTail`
- push `FSendTail` first on the next `Send` and on `FlushTail`, so the
  byte stream stays intact and in order
- cap it at `NM_SEND_TAIL_MAX = 65536`; beyond that, queueing returns 0
  and the caller gets back-pressure rather than unbounded growth

This is correctness buffering for a TCP reality, not switch-style
buffering.

## The two tests

Both live in `engine/test/` and run under `run-tests.sh`.

### `test_synapse_stub.pas` — 33 lines

Verifies the build guard, not the network. Calls `CreateSocketLink`
without `HAS_SYNAPSE` defined and checks it returns nil as designed.

Its value is guarding a property that is easy to break silently: the
repo must build and its tests must pass on a machine with no Synapse.
If someone makes the Synapse import unconditional, this test fails
immediately instead of the breakage surfacing on a clean clone months
later.

### `test_synapse_tail.pas` — 73 lines

Tests the partial-send tail buffer logic **without Synapse**, through
`NM_SOCKET_TEST` accessors. This is the more interesting one: it proves
the fix for the silent-byte-loss bug without needing a congested socket
to reproduce it against.

What it checks:

| Case | Assertion |
|---|---|
| queue 10 bytes `A`..`J` | all 10 accepted, `PendingTail = 10`, order preserved |
| socket accepts 4 on flush | 6 remain, front is now `E`, tail still `J` |
| drain the rest | `PendingTail = 0` |
| queue 70,001 bytes | exactly 65,536 accepted — the cap, not all of it |
| queue 10 more when full | 0 accepted — back-pressure, no unbounded growth |
| integrity at the cap boundary | first and last capped bytes correct |

The method is the one recorded in `testing_the_boundary.md`: prove a fix
without reproducing the real condition. You cannot easily force a kernel
send-buffer to fill on demand, so the test drives the tail buffer
directly and asserts the invariants that matter — order preserved,
nothing lost, growth bounded.

## Status

`THIRD_PARTY.md` records `NM_SynapseLink` as compile-verified against
the bundled Synapse with no warnings, API usage matching real Synapse.
**Runtime over a live TCP connection is still untested** — the one
outstanding item.

## See also

- `THIRD_PARTY.md` — bundling rationale and licence verification
- `LICENSES.md` — why Synapse keeps its own headers
- `testing_the_boundary.md` — the method behind the tail test
- `netmodem2irc_watt32_cleanup_phases.md` — why DOS gets no network at all
