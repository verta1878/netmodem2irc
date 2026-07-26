# netmodem2irc — Layer A spec map (UART + FOSSIL emulation)

The re-creatable core. This maps EXACTLY what NetModem's emulation does, so it can
be rebuilt in user-mode Pascal (fpc264irc) for the NT branch. Every item here
implements a PUBLISHED standard (NS-16550 datasheet, FOSSIL spec, Hayes AT), which
is why it's portable — it's spec-implementation, not black-box assembly.

Source: driver/src/NETMODEM.ASM + NETMODEM.INC (structs). Companion to DRIVER_MAP.md.

---

## 1. The emulated 16550 UART (NETMODEM.INC UARTStruct)

The driver emulates a literal NS-16550 register file — one byte per standard
register. A Pascal re-creation mirrors this exactly:

| Reg | Name | Dir | 16550 meaning | Emulation behavior |
|-----|------|-----|---------------|--------------------|
| RBR | Receiver Buffer | R | received byte | pop next byte from RX ring (from network) |
| THR | Transmit Holding | W | byte to send | push byte to TX ring (to network) |
| IER | Int Enable | R/W | which ints enabled | gate Interrupt_Generator |
| IIR | Int Identification | R | pending int cause | report highest-priority pending int |
| FCR | FIFO Control | W | FIFO enable/trigger | FIFO trigger level, clear FIFOs |
| LCR | Line Control | R/W | word len/stop/parity + DLAB | DLAB switches DLL/DLM access |
| MCR | Modem Control | R/W | DTR/RTS/OUT1/OUT2/loop | DTR drop => hangup; loop = local echo |
| LSR | Line Status | R | data-ready/THRE/errors | data-ready if RX ring non-empty; THRE if TX has room |
| MSR | Modem Status | R | CTS/DSR/RI/DCD + deltas | reflect online/ring state (DCD=carrier, RI=ring) |
| SCR | Scratch | R/W | scratch byte | plain storage |
| DLL | Divisor Latch Low | R/W | baud divisor low (DLAB=1) | baud rate (mostly cosmetic over TCP) |
| DLM | Divisor Latch High | R/W | baud divisor high (DLAB=1) | baud rate high |

**Key behaviors to replicate (from IOHandler, DRIVER_MAP §A):**
- **DLAB bit (LCR bit 7):** when set, offset 0/1 access DLL/DLM instead of RBR/THR
  and IER. Must be honored or baud programming corrupts RBR/THR.
- **LSR data-ready (bit 0):** set when RX ring has a byte. Guest polls this.
- **LSR THRE (bit 5):** set when TX ring has room. Guest polls before writing.
- **MSR DCD (bit 7):** carrier detect = "online" (connected to a remote). Doors
  watch this to know a caller is present.
- **MSR RI (bit 6):** ring indicator = incoming-call signalling.
- **FIFO (FCR/IIR):** 16550 has 16-byte FIFOs + trigger levels. Emulation exposes
  FIFO-capable IIR so software uses FIFO mode.

## 2. Interrupt behavior (Interrupt_Generator, DRIVER_MAP §A)
The emulated UART raises interrupts per 16550 rules; IIR reports the cause by
priority:
1. Receiver line status (errors)
2. Received data available (RX ring crossed trigger level)
3. Transmitter holding empty (THRE)
4. Modem status change (CTS/DSR/RI/DCD delta)
On NT user-mode, "raising an interrupt" becomes signalling the virtual COM layer /
the app that data/status changed (an event, not a hardware IRQ).

## 3. FOSSIL services (INT 14h + X00 superset)
NetModem is a Rev.5 FOSSIL driver. Full INT 14h function table (NETMODEM.INC
Int14_Table, functions 00h..21h) — these are the DOCUMENTED FOSSIL API BBS doors
call:

| Fn | FOSSIL service |
|----|----------------|
| 00h | Set baud rate / init |
| 01h | Transmit char (wait) |
| 02h | Receive char (wait) |
| 03h | Get line/modem status |
| 04h | Initialize FOSSIL driver (returns 1954h + info) |
| 05h | Deinitialize FOSSIL |
| 06h | Raise/lower DTR |
| 07h | Return timer tick info |
| 08h | Flush output buffer |
| 09h | Purge output buffer |
| 0Ah | Purge input buffer |
| 0Bh | Transmit char (no wait) |
| 0Ch | Peek at incoming char (no remove) |
| 0Dh | Keyboard read (no wait) — X00 |
| 0Eh | Keyboard read (wait) — X00 |
| 0Fh | Enable/disable flow control |
| 10h | Ctrl-C/Ctrl-K check + transmit-on-empty |
| 11h | Set current cursor location — X00 |
| 12h | Read current cursor location — X00 |
| 13h | Single char ANSI write — X00 |
| 14h | Enable/disable watchdog |
| 15h | Write char to screen (BIOS) — X00 |
| 16h | Insert/delete function |
| 17h | Reboot (X00) |
| 18h | Read block |
| 19h | Write block |
| 1Ah | Break begin/end |
| 1Bh | Return FOSSIL driver info (StrSiz/MajVer/buffers/etc.) |
| 1Ch–21h | Extended/X00 superset functions |
| 7Eh | Special X00 function (INT147E in source) |

The FOSSILStruct (NETMODEM.INC) is the standard FOSSIL info block returned by
Fn 1Bh: StrSiz, MajVer=5, MinVer, Ident, IBufr/IFree/OBufr/OFree (buffer sizes),
SWidth=80, SHeight=25, Baud. A Pascal re-creation returns the same structure.

## 4. AT command set (ParseATCommand / ATCommand, DRIVER_MAP §A)
Hayes AT command emulation. Recognized commands (from the parser):
- **A** answer, **D** dial (ATDT/ATDP), **E** echo, **H** hook (ATH0/ATH1),
  **I** info, **O** online, **Q** quiet, **V** verbose, **Z** reset, **Y** ...,
  **C** carrier, **K**, **R**, **S** S-registers.
- **+++** escape sequence (with guard time — Escape_Time_Out).
- Result codes: OK / CONNECT / RING / NO CARRIER / ERROR / etc.
Dialing (ATDT<host>) is where the modem metaphor meets the network: the "phone
number" becomes a host/port the server connects to via TCP. Emulation-wise, ATDT
triggers the server to open a socket; CONNECT is returned on success.

## 5. Call-state model (StatusStruct flags + TimeOut procs)
Online, Ringing, Attempting, Answered flags + Ringer/Connect/Escape/Break/Sleep
timeouts model modem call progress. NT re-creation keeps the same state machine;
the timeouts become user-mode timers.

---

## What this means for the NT Pascal build (honest)
- **All of Layer A is standard-spec** → re-creatable in FPC/Pascal for NT.
- The UART register file (§1) is a straightforward Pascal record + read/write
  dispatch. The FOSSIL table (§3) is a case/dispatch on AH. AT parsing (§4) is
  string handling. State (§5) is a small state machine.
- **The fiddly parts (be honest):** 16550 FIFO trigger semantics, exact LSR/MSR
  bit timing, FOSSIL Fn 04h/1Bh return-value exactness, +++ guard timing, and
  S-register behavior. Doors are PICKY — get these bit-exact or some door games
  misbehave. Tractable, but test against real doors.
- **The seam:** on NT there's no I/O trapping; instead the virtual COM layer
  (DRIVER_MAP §B replacement / NT_TRANSPORT_LAYER doc) delivers reads/writes to
  this emulation, and this emulation's TX/RX map to the socket. Same logic,
  user-mode plumbing.

## Suggested build order for the NT Pascal emulation
1. UART register record + read/write dispatch (§1) — the core.
2. TX/RX ring buffers wired to the socket (the seam).
3. LSR/MSR status + interrupt/event signalling (§1–2).
4. FOSSIL INT 14h dispatch (§3) — the API doors actually call.
5. AT command parser + call-state machine (§4–5).
6. Test against real DOS door games over the virtual COM.
