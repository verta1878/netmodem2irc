# NetModem/32 driver — functional map (NETMODEM.ASM)

**First netmodem2irc doc.** Maps what Dedrick Allen's driver assembly actually does,
section by section, so any point in the source can be traced back to an explanation.
Companion to the existing docs/DRIVER_INTERFACE.md. Small in-source comments should
reference this map (e.g. `; see DRIVER_MAP.md §4 — UART emulation`).

Source: driver/src/NETMODEM.ASM — 5,712 lines. MASM, .386P, Win9x VxD.
Author: Dedrick Allen / Allen Software, 1997-2001, GPLv2. Version 2.0.0.4.
Self-description: "32-Bit Virtual comport with true NS-16550/AFN FIFO UART emulation +
32-Bit Rev.5 Virtual FOSSIL Driver with X00 Superset functions."

## The big picture: three layers, cleanly separated

The driver is NOT monolithic mystery assembly. It separates into three concerns —
exactly the split that determines what can be re-created vs. what stays kernel-bound:

- **(A) Hardware/protocol EMULATION** — pretend to be a 16550 UART + FOSSIL modem.
  Implements KNOWN specs. Re-creatable from spec; portable in principle.
- **(B) Win9x VxD KERNEL PLUMBING** — how it inserts into the 9x kernel (Ring-0,
  VMM, I/O trapping, virtual IRQ). Bound to 9x + assembly. NOT portable.
- **(C) The SEAM** — IOCTL interface + TX/RX ring buffers that shuttle bytes to the
  user-mode server (which does the actual WinSock/Telnet). The bridge between the
  emulated modem and the network.

## The central data structure: StatusStruct (per-port state)
One StatusStruct per virtual port holds everything: the emulated UART state, the
FOSSIL state, AT-command parser state, and THREE ring buffers — ATBuffer (AT command
input), TXBuffer (bytes going OUT to the network), RXBuffer (bytes coming IN from the
network). Online/Ringing/Answered/Attempting flags model the modem call state. This
struct IS the emulated modem's memory.

---

## Section-by-section map

### Layer B — Win9x VxD kernel plumbing (STAYS assembly, 9x-only)
- **SysDeviceCriticalInit (220-573)** — VxD load-time init. Calls Install_IO_Handler
  to trap I/O port access (the core 9x mechanism: intercept when a DOS box touches
  COM port addresses). Allocates the ring buffers.
- **DeviceInit (575-630)** — device initialization.
- **Control_Proc (662-671)** — the VxD control-message dispatcher. Routes 9x system
  messages (Sys_Critical_Init, Device_Init, W32_DeviceIoControl, Sys_Critical_Exit,
  System_Exit, VM_Not_Executeable) to their handlers. This is pure VxD-model code.
- **VPICD_Hw_Int_Proc / VPICD_EOI_Proc (673-687)** — virtual PIC (interrupt
  controller) hooks. Virtual IRQ handling — deeply 9x-kernel-specific.
- **Simulate_Interrupt (689-699)** — inject a virtual interrupt into the VM.
- **SysCriticalExit / SystemExit / VMNotExecuteable (5115-5305)** — teardown paths.
- **Real_Mode_Proc (5698+)** — real-mode init stub.
These sections are the "how to be a Win9x VxD" dialect. They CANNOT be Pascal and
CANNOT run on NT — this is exactly why the `nt` branch replaces the VxD entirely.

### Layer A — UART + FOSSIL emulation (SPEC-implementable → portable)
- **IOHandler (1836-2450)** — THE HEART of UART emulation. This is the handler that
  fires when the guest touches a COM-port I/O address. It emulates the NS-16550 UART
  registers (RBR/THR/IER/IIR/FCR/LCR/MCR/LSR/MSR/scratch) + FIFO behavior. This is
  ~600 lines implementing a KNOWN chip spec — the biggest single re-createable piece.
- **Interrupt_Generator (701-843)** — decides when the emulated UART should raise an
  interrupt (data available, transmitter empty, modem status change) per 16550 rules.
- **Event_Generator (868-905)** — Win32 event signalling toward the server (ties to
  the RX/TX buffers).
- **ParseATCommand (1118-1649) + ATCommand (1675-1794)** — the AT command set (Hayes
  modem commands: ATDT, ATH, ATA, +++, etc.) + the "X00 superset". ~650 lines
  implementing modem AT behavior. Known spec (Hayes/X00) → re-createable.
- **Ringer/Connect/Escape/Break/Sleep TimeOuts (907-1099)** — modem call-progress
  timing (ring cadence, connect timeout, +++ escape guard time, break). Models modem
  timing behavior.
FOSSIL services (INT 14h / X00 superset) are dispatched through these — the FOSSIL
layer is the documented BBS modem API. All of Layer A implements PUBLISHED specs
(16550 datasheet, Hayes AT, FOSSIL/X00) — which is why it can be re-expressed in
Pascal/C for the NT user-mode bridge.

### Layer C — the seam (IOCTL + buffers → the server does WinSock)
- **W32DeviceIoControl (4250-5114)** — THE INTERFACE to the user-mode server. ~865
  lines dispatching the IOCTL table. The server calls DeviceIoControl; this routes
  to IOCTL00..0A+ handlers:
    IOCTL00 Get driver version    IOCTL06 Startup
    IOCTL01 Get driver info       IOCTL07 Shutdown
    IOCTL02 Unload port config    IOCTL08 Register server window
    IOCTL03 Reload port config    IOCTL09 Get init information
    IOCTL04 Unvirtualize IRQ      IOCTL0A Reset node
    IOCTL05 Virtualize IRQ        (see IOCTL_Table @ line 147)
- **TX/RXBuffer ring buffers** — bytes the guest "sends to the modem" land in
  TXBuffer; the server drains TX and pushes to the socket. Bytes from the socket the
  server writes into RXBuffer; the guest reads them as if from the UART. This ring-
  buffer pair IS the modem<->network bridge.
- **GetStatusStructAddress(Ex) (1796-1826, 5210)** — hand the server a pointer to
  per-port state.
- **S_DriverControl / InitFunction / PortOpen / PortClose (5348-5697, CCALL)** — the
  C-callable entry points (note CCALL = cdecl) the Pascal/server side links against.
  These are the documented ABI in common/NetModemVxD.pas.

---

## What this means for the revival (honest)

- **9x branch:** Layer B (VxD plumbing) MUST stay MASM — it's how you trap I/O and
  run Ring-0 on 9x. Layer A (emulation) also runs Ring-0 here (it has to, to service
  the trapped I/O in context), so on 9x it stays in the VxD too — but it's
  understandable spec-work, not black box.
- **nt branch:** No VxD. Layer B is REPLACED by a user-mode virtual COM bridge
  (com0com-style). Layer A (UART/FOSSIL/AT emulation) can be RE-CREATED in user-mode
  Pascal from the same specs this driver implements. Layer C (the byte-shuttle +
  server protocol) becomes user-mode too. => **This is where FPC/fpc264irc + the
  sockets work applies: the NT user-mode COM emulation + Telnet server is Pascal.**
- The IOCTL table (Layer C) is the contract the Pascal server already speaks
  (common/NetModemVxD.pas) — so the server's view of the driver is already documented
  and stable across both branches.

## Honest caveats
- VMM.INC bundled copy is noted (README) as slightly truncated — replace with clean
  DDK copy to build the 9x VxD. Does not affect reading/mapping.
- "Re-createable from spec" (Layer A) is real but CAREFUL work: 16550 timing, FIFO
  trigger levels, exact FOSSIL INT 14h semantics, and AT/X00 edge cases are fiddly —
  BBS door games are picky about modem behavior. Tractable, spec-guided, not trivial.
- This map is functional (what each section DOES). A line-by-line audit of the
  timing-sensitive Ring-0 paths is a larger, separate task.

## Suggested in-source comment anchors (traceability)
Add small comments at each proc referencing this map, e.g.:
  ; [DRIVER_MAP.md B] VxD control dispatch  (at Control_Proc)
  ; [DRIVER_MAP.md A] 16550 UART emulation  (at IOHandler)
  ; [DRIVER_MAP.md A] Hayes/X00 AT parser   (at ParseATCommand)
  ; [DRIVER_MAP.md C] server IOCTL interface (at W32DeviceIoControl)
so any point in NETMODEM.ASM traces back to its explanation here.
