# fpc264irc Sockets — Lifecycle, Exit, and What's Needed

Written 2026-07-26. For sysop/0.

## The exit pattern — it's the program's job

The sockets unit provides the tools:

```pascal
Function  InitWatt32: Boolean;   { init socket table, ARP cache, packet driver }
Procedure DoneWatt32;            { unhook the packet driver }
```

**The program decides when to call them.** The RTL does not force
cleanup in a `finalization` section, because:

1. The program may need to control shutdown order — close sockets
   before unhooking the driver, flush data before closing sockets
2. A TSR (`Keep`) never exits — calling `DoneWatt32` would unhook
   the packet driver while the program is still resident
3. Multiple units may depend on sockets — only the program knows
   when ALL consumers are done

This is standard Pascal: constructors and destructors are the
program's responsibility. The RTL provides primitives, not policy.

## The class pattern

Programs that use sockets should wrap the lifecycle in a class:

```pascal
type
  TNetworkApp = class
  private
    FInitialized: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
  end;

constructor TNetworkApp.Create;
begin
  inherited Create;
  FInitialized := InitWatt32;
  if not FInitialized then
    { HAZARD: on DOS, if InitWatt32 fails, the packet driver was
      not found. Do not call any socket functions — they will
      operate on uninitialized state. Fail visibly. }
    WriteLn('FATAL: no packet driver (run PKTDRV first)');
end;

destructor TNetworkApp.Destroy;
begin
  if FInitialized then begin
    { Close all open sockets BEFORE unhooking the driver.
      Order matters: DoneWatt32 calls PktDriverDone which
      restores the packet driver interrupt vector. Any socket
      operation after this point will send packets into a
      vector that no longer points at the driver. }
    DoneWatt32;
    FInitialized := False;
  end;
  inherited Destroy;
end;
```

Program entry:

```pascal
var
  App: TNetworkApp;
begin
  App := TNetworkApp.Create;
  try
    if App.Initialized then begin
      { ... use fpSocket, fpConnect, fpSend, fpRecv ... }
    end;
  finally
    App.Free;  { calls DoneWatt32 — packet driver unhooked cleanly }
  end;
end.
```

The `try/finally` guarantees cleanup even on an unhandled exception
or runtime error. The destructor guarantees `DoneWatt32` runs exactly
once. The `FInitialized` flag guarantees `DoneWatt32` is never called
if `InitWatt32` failed.

**For a TSR:** the constructor calls `InitWatt32`, but the destructor
is never called (the program goes resident via `Keep`). Cleanup
happens only on explicit unload, if the TSR supports it. This is
correct — a resident program that unhooks the packet driver on
`Destroy` would break networking for everything else in memory.

## Why NOT `finalization`

A `finalization` section in the sockets unit would call `DoneWatt32`
automatically when the unit unloads. This is wrong for three reasons:

1. **Order is uncontrolled.** FPC's finalization order depends on the
   `uses` clause chain. If another unit's finalization tries to send
   a final packet (e.g. a TCP RST or a goodbye message), the sockets
   unit may have already unhooked the driver.

2. **TSR programs never finalize.** `Keep` doesn't run finalizers.
   A `finalization` section would be dead code for the primary use
   case.

3. **Double-free.** A well-written program already calls `DoneWatt32`
   in its destructor. A `finalization` section would call it again.
   `PktDriverDone` restoring an already-restored vector is at best
   harmless, at worst it restores the wrong vector if something else
   hooked the interrupt between the two calls.

The pattern is: **the unit provides `Init`/`Done`, the program calls
them.** This is how `Watt-32` worked (`sock_init`/`sock_exit`), how
`WSAStartup`/`WSACleanup` works on Windows, and how DOS TSR programs
have always managed their interrupt vectors.

## What else the sockets unit needs

### 1. `FIONREAD` in `ioctlSocket` — one line

Currently `ioctlSocket` handles `FIONBIO` (non-blocking mode) but
ignores `FIONREAD`. Fix:

```pascal
Function ioctlSocket(Sock: TSocket; Cmd: cint; Arg: Pointer): cint;
Begin
  if (Sock >= 0) and (Sock < MAX_SOCKETS) and SockTable[Sock].InUse then begin
    if Cmd = LongInt(FIONBIO) then
      SockTable[Sock].NonBlock := (PLongInt(Arg)^ <> 0)
    else if Cmd = LongInt(FIONREAD) then
      PLongInt(Arg)^ := SockTable[Sock].RxLen    { <-- add this }
    ;
    Result := 0;
  end else Result := SOCKET_ERROR;
End;
```

Needed by any caller that wants a byte count rather than just
readability from `fpSelect`.

### 2. UDP send/recv — needed for DNS

Constants are defined (`SOCK_DGRAM`, `IPPROTO_UDP = 17`), but
`fpSocket` + `fpSend` only handle TCP (`SOCK_STREAM`).

What's needed:

- `fpSocket` with `SOCK_DGRAM`: allocate a socket entry with type
  flag set to datagram
- UDP send: build a UDP header (src port, dst port, length, checksum)
  + IP header, call `PktSendRaw`
- UDP receive: in the packet driver callback, demux by IP protocol
  field (`$11` = UDP), deliver to the matching socket's receive buffer

Smallest useful scope: enough to send a DNS query to port 53 and
parse the response. That unlocks `ResolveName` for real hostnames.

### 3. Wire `BuildDNSQuery` into `ResolveName`

`BuildDNSQuery` at line 724 already builds a proper DNS query packet
with header packing. `ResolveName` currently only does `inet_addr`
(dotted quad). Wire them together:

```
ResolveName("bbs.example.com")
  → BuildDNSQuery → UDP send to DNSIP:53
  → UDP recv → parse response → return TInAddr
```

The DNS server IP (`DNSIP`) needs to come from somewhere — either a
config file, a command-line argument, or DHCP. Watt-32 read it from
`WATTCP.CFG`. A simple `RESOLV.CFG` with one line (`nameserver
192.168.1.1`) would work.

### 4. `fpListen` / `fpAccept` — verify, not just declared

The declarations exist. If these are stubs that return `SOCKET_ERROR`,
note it — NMServer needs them for the i386 side (accepting incoming
Telnet), and any future DOS server would too.

### 5. Receive-path confidence

Comment at line 545: "Polling-mode packet driver doesn't work without
callback." The packet driver uses an interrupt-driven real-mode
callback to deliver received frames. This is the piece that can't be
tested without real hardware and a real packet driver loaded. If
sysop/0 has tested this on the 386, note the results. If not, it's
the highest-risk untested path.

## Summary for sysop/0

| Item | Effort | Impact |
|---|---|---|
| `FIONREAD` in `ioctlSocket` | 1 line | unblocks byte-count queries |
| UDP send/recv | medium | unblocks DNS, future UDP protocols |
| Wire DNS (`BuildDNSQuery` → `ResolveName`) | small (once UDP works) | hostname resolution |
| Verify `fpListen`/`fpAccept` | check | server-side sockets |
| Receive-path test on real hardware | hardware needed | confidence in the whole stack |

**Exit/cleanup is already correct as designed.** The program owns the
lifecycle. No changes needed to the RTL — just document the pattern
so every program using sockets follows it.
