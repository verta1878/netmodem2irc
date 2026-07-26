# netfossl.exe

> **HISTORICAL — predates the 2026-07-25 architecture decision.**
>
> This document describes the original design where netfossl sat on an
> emulated 16550 backed by TCP via Watt-32. That design was replaced:
> **netfosdl** (renamed, d=driver) is now a standalone FOSSIL driver on
> a **real UART** with **no network**. Watt-32 was removed entirely.
> See `netmodem2irc_fossil_separation.md` for the current architecture.
>
> Kept as the record of what the design was before it settled.

A FOSSIL driver that has no serial port behind it.

BBS software calls INT 14h believing it is driving a modem on a COM port.
netfossl answers those calls from an emulated 16550 whose receive and transmit
rings are fed by a TCP socket instead of a UART. No comport, no X00 or BNU, no
Watt-32, and no C anywhere in the build.

> **STATUS: UNTESTED ON HARDWARE.** Everything below compiles and links
> cleanly for i8086-msdos. None of it has run on a real machine or against a
> real packet driver. Treat this as a specification of intent, and instrument
> before trusting it. The two places most likely to fail first are the
> interrupt-time receiver in `pktdrv.pas` and the residency/unload path.

---

## Lineage: where this sits relative to NetModem/32

netfossl is not a new idea in this project. It is the DOS-native counterpart of
what NetModem/32 already did, and the two are worth comparing because the
differences are not all improvements.

Dedrick Allen's NetModem/32 v2.0 alpha3 (28 May 2000) described itself as a
*32-bit FOSSIL Telnet Server for Windows 95/98* that "emulates a modem via
FOSSIL services." So the original was already a FOSSIL provider — the same
trick, on a different platform. `history/netmdb15/WHATSNEW.TXT` has Allen
discussing optimising that FOSSIL driver for speed and testing it against more
BBS packages.

|  | NetModem/32 v2.0a3 | netfossl |
|---|---|---|
| Host | Windows 95/98 | DOS, real mode |
| TCP/IP from | Windows WinSock | own Pascal stack on a packet driver |
| Direction | **inbound** (accepts Telnet connections) | **outbound** (dials out) |
| Nodes | multinode, comports 3–99 | one connection, one comport |
| Modem emulation | FOSSIL services | FOSSIL services |

Two things follow from that table.

**netfossl implements the direction the original never shipped.** Alpha3 was
inbound only; its FILE_ID.DIZ promised "Dial-Out coming soon" and that release
never came. netfossl is dial-out — a BBS or terminal program uses it to reach
out to a host. It cannot currently accept an incoming call, which is precisely
what the original *could* do.

**Single-connection is a regression against the original's headline feature.**
"Multinode versions are now available" was the banner line of the 2000 release,
and up to 97 virtual comports were supported. `tcpcore` holds one TCB. Widening
it is mechanical — make the TCB an array and key it by comport index, which is
what `NM_Int14ISR`'s `ResidentUarts[0..99]` table already anticipates — but it
is not done, and any claim of parity with the original should account for it.

---

## Two variants, one of which is not written yet

The FOSSIL interface a BBS sees is identical either way. What differs is what
sits behind the UART:

| | real UART | emulated 16550 |
|---|---|---|
| Backed by | 16550 hardware at 3F8h/2F8h, IRQ 4/3 | a TCP socket |
| Equivalent to | a conventional FOSSIL (X00, BNU) in Pascal | the netmodem trick |
| Must be resident | yes | yes |
| Status | **not written** — no I/O-port code exists in the tree | this document |

Both must be TSRs. A FOSSIL driver that is not resident before the BBS loads is
not a FOSSIL driver: the BBS probes INT 14h function 04h, gets no `1954h`
signature back, and falls through to its own internal comms.

`dos/netmodem.pas` is sometimes mistaken for the real-UART variant. It is not.
It is a foreground bridge — no `Keep`, no `SetIntVec`, a `Repeat…Until Done`
loop that exits — and it *consumes* a FOSSIL rather than providing one, so it
needs X00 or BNU already loaded in front of real hardware. Useful as a utility,
but it cannot serve a BBS.

Unload (`/u`) should be common to both variants when the second one exists;
the INT 2Fh multiplex protocol below is written to be shared rather than
duplicated.

---

## Known design corrections outstanding

These are settled decisions not yet reflected in the code. Documented here so
the current CLI is not mistaken for the intended one.

**1. The command line is wrong.** It currently takes
`<myip> <mask> <gw> <dns> <host> [port] [comport]`. It should take:

```
netfossl [comport]
netfossl /u
```

*Why the IP arguments go:* addressing is configuration, not invocation. DOS
convention is a config file (Watt-32 reads `WATTCP.CFG` for `my_ip`, `netmask`,
`gateway`, `nameserver`), and this project already has `NM_Config`, written by
the CPL and applied at install — see `NM_Int14ISR`'s header.

*Why `<host>` goes:* **a modem is not told where to call at load time; it is
dialled.** `NM_ATCommand` already implements this and already compiles for
i8086 — `TATModem` with `mmCommand`/`mmOnline` modes, `ATFeed`, and a
`ParseDial` accepting `ATDT bbs.example.com` (port 23 default) or
`ATDT bbs.example.com:2323`. Connecting at install makes this a hardwired
leased line: the BBS can never dial a second destination without unloading.

**2. `comport` and `port` are unrelated things sharing a word.**

| | `comport` | `port` |
|---|---|---|
| Means | which COM the BBS sees | TCP port on the remote host |
| Range | 0–99 (`NM_MAX_PORTS`), 0 = COM1 | 1–65535 |
| Appears in | `DX` of every INT 14h call | `ATDT host:2323` |
| Set | once, at install | per call, by the BBS |

The comport is *local identity*; the TCP port is *remote destination*. Only the
comport belongs on the command line.

**3. The TCP/IP layer exposes the wrong API.** `tcpcore` presents
`TcpConnect`/`TcpRead`/`TcpWrite` — a bespoke shape, the third in this
codebase after Watt-32's `_w32_*` and the `fpcirc_*` wrappers in
`netmodem.pas`. `dos/fpc-sockets-request.md` asks for the RTL's `sockets` unit
to gain a DOS backend: `fpSocket`, `fpConnect`, `fpBind`, `fpListen`,
`fpAccept`, `fpSend`, `fpRecv`, `fpClose`, `TInetSockAddr`. The protocol work
underneath is sound; the interface on top of it is not, and until it changes,
nothing written against FPC sockets can use this stack unmodified.

---

## Requirements

| | |
|---|---|
| CPU | 8086 or better, real mode |
| DOS | 3.0 or later (INT 21h AH=49h, INT 2Fh multiplex) |
| Network | A packet driver on INT 60h–80h |
| Memory | ~58 KB resident (see *Resident footprint*) |

netfossl speaks the **FTP Software Packet Driver Specification 1.09** and
nothing else.

> "FTP Software" here is a company, not the file transfer protocol. FTP
> Software, Inc. was a 1980s TCP/IP vendor that published the packet driver
> spec DOS network cards implement; Crynwr maintained the well-known free
> driver collection built to it. No file transfer is involved.

Note which end of netfossl this describes. The **serial port is the top** — the
emulated 16550 and INT 14h are what the BBS drives. The packet driver is the
**bottom**, the Ethernet card underneath:

```
BBS software
    |  INT 14h        <- the serial port (emulated 16550, FOSSIL functions)
netfossl
    |  packet driver  <- the Ethernet card
NIC
```

There is no serial hardware anywhere in that path. DOS ships no TCP/IP stack
and no network API, so reaching a NIC means choosing one of the three driver
interfaces that exist. Targeting the packet driver spec is not as narrow as it
sounds, because the other two reach it through standard shims:

| Your NIC driver | What to load |
|---|---|
| Crynwr / packet driver | nothing, it is already the right interface |
| Novell ODI | `ODIPKT.COM` |
| NDIS (MS LAN Manager, MS Network Client) | `DIS_PKT9.DOS` |

---

## Syntax

> The syntax below is what the code accepts **today**. See *Known design
> corrections outstanding* — this is not the intended interface.

```
netfossl <myip> <mask> <gw> <dns> <host> [port] [comport]
netfossl /u
```

| Argument | Meaning | Default |
|---|---|---|
| `myip` | this machine's IPv4 address, dotted quad | required |
| `mask` | subnet mask, dotted quad | required |
| `gw` | default gateway, dotted quad | required |
| `dns` | DNS server, dotted quad | required |
| `host` | dotted quad **or** hostname | required |
| `port` | TCP port | `6667` |
| `comport` | FOSSIL port index, 0 = COM1 | `0` |

There is no DHCP and no config file: addressing is entirely static and given on
the command line. `host` is tried as a dotted quad first, and only treated as a
name if that parse fails — which is why the IP parser is strict rather than
permissive.

### Examples

```
REM connect COM1 to an IRC server by name
netfossl 192.168.1.64 255.255.255.0 192.168.1.1 192.168.1.1 irc.libera.chat 6667 0

REM connect COM2 to a telnet BBS by address, no DNS lookup performed
netfossl 192.168.1.64 255.255.255.0 192.168.1.1 192.168.1.1 192.168.1.10 23 1

REM remove it
netfossl /u
```

---

## What the BBS sees

`NM_Fossil` implements 16 of the 28 FOSSIL functions:

| Fn | Name | | Fn | Name |
|---|---|---|---|---|
| `00h` | set baud | | `0Ah` | purge input |
| `01h` | transmit, wait | | `0Bh` | transmit, no wait |
| `02h` | receive, wait | | `0Ch` | peek |
| `03h` | get status | | `0Fh` | flow control |
| `04h` | init | | `18h` | read block |
| `05h` | deinit | | `19h` | write block |
| `06h` | set DTR | | `1Bh` | get driver info |
| `08h` | flush output | | | |
| `09h` | purge output | | | |

`18h`/`19h` block I/O matters: transfer protocols that use them stay off the
byte-at-a-time path and are far less affected by the pump rate below.

**Not implemented (12):** `07h` timer tick, `0Dh`/`0Eh` keyboard, `10h` Ctrl-C
check, `11h`/`12h` cursor, `13h` ANSI write, `14h` watchdog, `15h` write BIOS,
`16h` insert/delete line, `17h` reboot, `1Ah` break.

Most are local console conveniences a FOSSIL offers for BBS authors' benefit
rather than serial operations. `1Ah` break and `14h` watchdog are the two real
gaps for BBS use — software that relies on the watchdog to detect a dropped
carrier will not get it.

Carrier detect follows the TCP connection: DCD asserts while the socket is
established and drops when it closes, so a BBS sees a hangup the way it would
from a real modem.

---

## How it runs

```
BBS --INT 14h--> NM_Int14ISR --> FossilDispatch --> TUart16550 rings
                                                         |
                                          Pump <---------+
                                            |
                        tcpcore -> netcore -> pktdrv -> packet driver
```

Installation connects first and goes resident only on success, so a failure to
reach the host leaves nothing loaded.

After `Keep`, nothing runs in the foreground, so the rings are serviced from
**INT 1Ch at 18.2 Hz**. That choice keeps the packet driver off the INT 14h
call path entirely and leaves `NM_Int14ISR` untouched, at the cost of
throughput — see below. A `PumpBusy` flag prevents the pump re-entering itself,
and the handler chains to the previous INT 1Ch owner before doing any work.

### Throughput

Each tick sends at most one MSS, so the ceiling is roughly
`18.2 x 1400 bytes/sec` ≈ 25 KB/s, and in practice less. That is comfortable
for an interactive terminal session and poor for file transfer. Raising it
means either reprogramming INT 08h for a faster tick or pumping inside the
INT 14h handler; both trade reentrancy safety for speed.

### Resident footprint

`Keep(0)` does not trim, so the whole ~58 KB image stays in conventional
memory. Roughly 13 KB of that is buffers:

| Buffer | Size |
|---|---|
| packet driver receive ring (8 x 1516) | ~12 KB |
| TCP receive + transmit | 8 KB |
| out-of-order reassembly (4 x ~1408) | ~5.6 KB |
| Ethernet TX + RX frames | ~3 KB |

`TCP_OOO_SLOTS` in `tcpcore.pas` and `PKT_SLOTS` in `pktdrv.pas` are the two
knobs worth turning if conventional memory is tight. Setting `TCP_OOO_SLOTS`
to 0 reclaims 5.6 KB and reverts to dropping reordered segments.

---

## Unloading

`netfossl /u` performs a four-step handshake over an INT 2Fh multiplex ID
claimed at install from the `C0h`–`FFh` range:

1. **Request.** The resident copy verifies INT 14h, 1Ch and 2Fh all still point
   at its own handlers, then flags the unload and answers *pending*.
2. **Tick.** On the next timer tick the resident sends a TCP RST, unhooks
   INT 14h and INT 1Ch, and marks itself ready. This happens on the tick, not
   in the INT 2Fh handler, so the only packet the driver is asked to send comes
   from the same context all other sends use.
3. **Release.** The transient copy reads the packet driver handles out of
   resident memory and issues `release_type` for each **in ordinary foreground
   context** — never from inside an interrupt handler.
4. **Free.** The transient copy restores INT 2Fh, then frees the resident's
   environment block and PSP. The side doing the freeing is never the side
   being freed.

Installing twice is refused, since two copies would fight over INT 14h.

### Messages

| Message | Meaning |
|---|---|
| `no packet driver found on INT 60h-80h` | no driver, or an ODI/NDIS shim not loaded |
| `already resident (use /u to unload)` | a copy is installed |
| `no free INT 2Fh multiplex ID in C0-FF` | 64 multiplex IDs all claimed |
| `DNS failed (tx= rx= badid=)` | see counters — `rx=0` means no reply at all |
| `no connection (state= rxmit= arp=)` | `arp=0` means ARP never answered |
| `not resident` | `/u` found no installed copy |
| `unload refused -- another TSR hooked INT 14h/1Ch/2Fh after us` | something loaded on top; unload it first |
| `resident did not complete teardown (timer tick blocked?)` | INT 1Ch never fired — interrupts masked, or the tick chain is broken |
| `vectors restored but memory not freed` | vectors are safe but the block is still owned; a reboot is the clean fix |

---

## Diagnostics

Counters are exported by each unit for a test program to read. They are
counters rather than printed output because the pump runs at interrupt time and
cannot call DOS.

| Unit | Counters |
|---|---|
| `pktdrv` | `PktRxCount` `PktRxDrop` `PktTxCount` `PktLastErr` |
| `netcore` | `StatRxArp` `StatRxIp` `StatRxIcmp` `StatBadCsum` `StatNotForUs` |
| `tcpcore` | `StatTcpRx/Tx/Rxmit/BadSum/OOO` `StatRstRx/Drop/Tx` `StatChallenge` `StatOooQueued/Merged/Evict` |
| `dnscore` | `StatDnsTx` `StatDnsRx` `StatDnsBadId` |

Reading them in order localises a fault quickly. `PktRxCount = 0` means the
receiver callback never fired and nothing above it can work. `StatRxArp > 0`
with `StatRxIp = 0` means the link is alive but IP is not reaching us.
`StatNotForUs` climbing means frames arrive addressed elsewhere — usually a
wrong `myip`. `StatTcpRxmit` climbing with `StatTcpRx = 0` means we transmit
and nothing answers.

---

## Limitations

- **One connection.** Active open only; no listen or accept. A single BBS node
  — see *Lineage*: the original NetModem/32 was multinode across comports 3–99
  and inbound-only, so this is the mirror image of it in both respects.
- **No congestion control** beyond obeying the peer's advertised window, and no
  Nagle. Fine for a byte pipe, wrong for bulk transfer.
- **Every segment is ACKed** — no delayed ACK, so reverse-path traffic is
  roughly double what it needs to be.
- **No IP fragmentation or reassembly.** Datagrams must fit the MTU.
- **DNS is A-records only**, one query in flight, no cache. A CNAME whose A
  record is not in the same response fails rather than triggering a second
  query. No TCP fallback for truncated replies.
- **ARP cache never expires** (8 entries, round-robin). A peer whose MAC
  changes is not noticed until its slot is reused or it sends a gratuitous ARP.
- **`ArpResolve` blocks on a counted spin**, not a timer, so its real duration
  varies with CPU speed.
- **TIME_WAIT is ~3 s**, not 2×MSL — a concession to resident memory.

## See also

| File | Contents |
|---|---|
| `pktdrv.pas` | packet driver interface, receive ring, interrupt-time receiver |
| `netcore.pas` | Ethernet, ARP, IPv4, ICMP, checksum, tick source |
| `tcpcore.pas` | TCP state machine, retransmission, RST validation, reassembly |
| `dnscore.pas` | UDP and the DNS resolver |
| `netfossl.pas` | resident main, pump, INT 2Fh multiplex, unload |
| `../engine/NM_Fossil.pas` | FOSSIL function dispatch |
| `../engine/NM_Int14ISR.pas` | INT 14h hook and resident UART table |
| `../engine/NM_UART16550.pas` | emulated 16550 and its rings |
