# NetModem 2 — Recovery Record & Free Pascal Port Guide

*Reconstructed from the original MASM driver source recovered from the xtcbox.org
vBulletin `attachment` table (April 2007 backup). This document is the interface
specification for re-implementing the lost user-mode host/GUI application in
Free Pascal / Lazarus, without the proprietary Delphi "ShortcutBar" component.*

---

## 1. What was recovered

From the forum's `attachment.MYD` we carved three archives. The important one,
`nmsource.zip`, decompressed CRC-clean and contains the **complete NetModem 2
driver source**:

| File | Purpose |
|------|---------|
| `NETMODEM.ASM` | Main driver, 5,712 lines MASM — VxD virtual COM port + 16550 UART + FOSSIL emulation |
| `NETMODEM.INC` | Structures, constants, and the driver↔host message protocol |
| `NETMODEM.DEF` | VxD segment/export definition |
| `NETMODEM.RC` / `RESOURCE.H` | Version resource |
| `VMM.INC`, `VPICD.INC`, `VCOMM.INC`, `SHELL.INC`, `VWIN32.INC`, `VCOMMW32.INC`, `REGDEF.INC` | Win9x DDK includes (stock — replace `VMM.INC` from a clean DDK; the recovered copy is slightly truncated) |
| `COPYING`, `INFO` | License + build notes |

Identity (from `NETMODEM.INC` / `NETMODEM.ASM`):
`NetModem/32 v2.0.0.4/Alpha`, `Device_Driver_ID = 3D20h`, `Driver_Version = 2004h`,
by Dedrick Allen / Allen Software, 1997–2001.

The other two carved archives: `sbardem.zip` (the Absolute Solutions ShortcutBar
demo — the original missing dependency) and `emailv10.zip` (an unrelated Mystic
BBS email-validation tool).

---

## 2. Why "porting away from the ShortcutBar" is the right move

NetModem 2 is **two programs**, not one:

```
   16-bit BBS door game / terminal
                │  opens "COMx"
                ▼
   ┌───────────────────────────┐        ┌────────────────────────────┐
   │  NETMODEM.VXD  (Ring-0)    │  IOCTL │  User-mode HOST app         │
   │  • virtual COM port        │◄──────►│  • registers its HWND       │
   │  • 16550 UART emulation    │  Post  │  • opens the TCP socket     │
   │  • FOSSIL driver           │  Msg   │  • shuttles bytes ↔ network │
   │  • AT command set          │───────►│  • the GUI  ← ShortcutBar   │
   └───────────────────────────┘        └────────────────────────────┘
        RECOVERED, complete                   LOST — rewrite this
```

The VxD does **no networking itself** (a Win9x Ring-0 VxD can't easily use
Winsock). It emulates the modem hardware and forwards everything to a user-mode
"server" application that registers via `IOCTL 08`. That host app is the piece
that (a) did the actual telnet/TCP connection and (b) used the ShortcutBar for
its GUI. Its source was never in the backup.

**So the ShortcutBar was only ever a dependency of the app you have to rewrite
anyway.** Grep confirms zero references to it in any driver file. The driver is
already free of it. Your job is to write a fresh host app in Free Pascal and
simply not use ShortcutBar — Lazarus's own `TToolBar` / `TTreeView` /
`TCategoryButtons` cover the same UI.

---

## 3. Two possible destinations

| | **A. Keep the recovered VxD** | **B. Full modern rewrite** |
|---|---|---|
| Runs on | Win95/98/ME (real or 86Box/PCem/VirtualBox) | Windows 10/11 |
| Driver | Compile `NETMODEM.VXD` from recovered source (MASM 6.14 + Win98 DDK) | Replace with com0com / a user-mode virtual COM port |
| Host app | New Lazarus app driving the VxD IOCTL interface (Section 4) | New Lazarus app bridging the virtual COM port ↔ TCP |
| Fidelity | Faithful to original NetModem 2 | Same idea, new plumbing |
| Effort | Low–medium (interface is small & documented below) | Medium (but no 16-bit/VxD constraints) |

Both use Free Pascal / Lazarus for the GUI. Path A reuses your recovered driver
and is the most faithful; Path B is the way to run on a modern OS. The interface
spec below is what Path A's host app talks to; for Path B you'd point the same
GUI at a virtual COM port instead of the VxD.

---

## 4. Driver interface specification (for the host app)

### 4.1 Opening the driver (Win9x, Path A)

The host talks to the VxD from Ring-3 via `CreateFile` + `DeviceIoControl`:

```pascal
hVxD := CreateFile('\\.\NETMODEM.VXD', 0, 0, nil, 0,
                   FILE_FLAG_DELETE_ON_CLOSE, 0);   // dynamic-load a VxD
```

If the VxD is loaded statically as a VCOMM port driver, open it by its device
name instead. Control codes are the raw table indices `$00`–`$10` passed as
`dwIoControlCode`.

### 4.2 Calling convention (important quirk)

This driver does **not** use the buffers the way a normal Win32 driver does.
Reading the source (`W32DeviceIoControl`, `jmp IOCTL_Table[eax*4]`):

* The **node index** and, for `IOCTL 08`, the **HWND**, are passed through the
  value *pointed to by* `lpcbBytesReturned` — not through the in-buffer.
  Internally it does `ecx = [lpcbBytesReturned]; index = (ecx-1)*4` into
  `Status_Array`.
* Struct payloads (DriverInfo, InitStruct, IOStruct, ComportStruct) go through
  `lpvInBuffer`.

So from Pascal, pass a pointer to a DWORD holding the node number as
`lpcbBytesReturned`, and your struct as `lpvInBuffer`. The wrapper unit
(`NetModemVxD.pas`) encapsulates this.

### 4.3 IOCTL table (control codes $00–$10)

| Code | Name | Direction / payload |
|------|------|---------------------|
| `$00` | Get driver version | (no-op / status) |
| `$01` | Get driver information | out → `TDriverInfo` (Version, MaxNodes) in `lpvInBuffer` |
| `$02` | Unload port config | node in `[lpcbBytesReturned]` |
| `$03` | Reload port config | node; re-reads registry `ComportConfig` |
| `$04` | Unvirtualize IRQ | node |
| `$05` | Virtualize IRQ | node |
| `$06` | Startup | node |
| `$07` | Shutdown | node |
| `$08` | **Register server window** | HWND in `[lpcbBytesReturned]` → stored as `ServerWindow` |
| `$09` | Get initialization information | node; out → `TInitStruct` (Init_OK, Init_Error) |
| `$0A` | Reset node | node |
| `$0B` | Ring node | node — signal an incoming call |
| `$0C` | Answer check | node |
| `$0D` | Disconnect node | node |
| `$0E` | **Input / Output** | node; `TIOStruct` — the byte data path |
| `$0F` | BREAK received | node |
| `$10` | Get word length | node |

### 4.4 Messages the driver POSTs up to your window

After you register with `IOCTL 08`, the driver calls `SHELL_PostMessage` to your
HWND. `wParam` low byte = node number. Constants (`WM_USER = $0400`):

| Message | Value | Meaning for the host |
|---------|-------|----------------------|
| `CM_CONNECT_NODE` | `WM_USER+409` = `$0599` | Node wants to go online — open the TCP socket |
| `CM_DISCONNECT_NODE` | `WM_USER+410` = `$059A` | Node hung up — close the socket |
| `CM_SEND_REMOTE_BREAK` | `WM_USER+417` = `$05A1` | Send a telnet BREAK to the remote |
| `CM_WONT_BINARY` | `WM_USER+419` = `$05A3` | Telnet WONT BINARY negotiation |
| `CM_WILL_BINARY` | `WM_USER+420` = `$05A4` | Telnet WILL BINARY negotiation |

Your message loop reacts to these: on `CM_CONNECT_NODE` you dial the configured
host/port; while connected you poll `IOCTL 0E` to move bytes both directions; on
`CM_DISCONNECT_NODE` you drop the socket.

### 4.5 Registry configuration

`HKLM\Software\Allen Software\NetModem`
* `ComportConfig` — a `TComportStruct` blob (per node)
* `IRQ` — the virtual IRQ

`TComportStruct` fields include `ComportNumber`, `szComportName[7]`,
`Emulation` (`emUART=0`, `emFOSSIL=1`), `Baudrate`, **`Internetport`** (the TCP
port used for the connection), `Baseaddress`, `Buffersize`, and flags
(`Alwaysactive`, `Lockedbaudrate`, `Managetimeslice`). The host's config screen
reads/writes this — this is where the ShortcutBar-based settings UI used to live.

### 4.6 Result / error codes

Result: `rsOK=0 rsBUSY=1 rsERROR=2 rsNOANSWER=3 rsNOCARRIER=4 rsNODIALTONE=5 rsNORESULT=6`
Error: `NO_ERROR=0 PORT_ERROR=1 MEMORY_ERROR=2 IRQ_ERROR=3 V86_MEMORY_ERROR=4 CB_MEMORY_ERROR=5 DRV_REG_ERROR=6`

---

## 5. Suggested Free Pascal / Lazarus project layout

```
NetModem2/
├── NetModemVxD.pas     ← provided: driver interface (records, IOCTLs, messages)
├── NetModemHost.lpr    ← program entry
├── MainForm.pas/.lfm   ← node list, status, connect/disconnect (TToolBar/TListView)
├── ConfigForm.pas/.lfm ← reads/writes HKLM\Software\Allen Software\NetModem
└── NetTransport.pas    ← TCP/telnet (use Synapse `TTCPBlockSocket` or lNet)
```

* **GUI replacement for ShortcutBar:** Lazarus `TToolBar`, `TCategoryButtons`,
  or `TTreeView` give the same "outlook bar" feel, all built-in and free.
* **Networking:** Synapse (` blcksock`) is the simplest — one `TTCPBlockSocket`
  per node, `SendBuffer`/`RecvBuffer` wired to `IOCTL 0E`. Handle telnet
  IAC/BINARY per the `CM_WILL_BINARY` / `CM_WONT_BINARY` messages.
* **Message pump:** subclass the main form's `WndProc` (or use
  `Application.OnMessage`) to catch the `CM_*` messages in 4.4.

### Minimal host loop (pseudocode)

```
RegisterServerWindow(Handle);         // IOCTL 08
loop:
  on CM_CONNECT_NODE(node):    Sockets[node] := Dial(Config[node].Internetport)
  on CM_DISCONNECT_NODE(node): Sockets[node].Close
  on timer / CM data:
     IO(node, rx, hx);               // IOCTL 0E: rx = to-network, hx = from-network
     Sockets[node].SendBuffer(rx)
     hx := Sockets[node].RecvBuffer
```

---

## 6. Building the driver (Path A only)

Per `INFO`: **MASM 6.14 + Win9x DDK + VC++ 5/6**, on a Win9x host/VM.
`ml /c /Cp /coff NETMODEM.ASM` then link as a VxD using `NETMODEM.DEF`. The
recovered `VMM.INC` is slightly short — drop in the clean copy from the Win98 DDK
before building. The driver targets 95/98/ME only; NT-family needs a full rewrite
(author's own note).

---

## 7. Notes & open items

* `SBARDEM.EXE` inside `sbardem.zip` is the ShortcutBar **evaluation** demo; the
  forum thread indicates the *source* was what the old CPL needed. You don't need
  it at all for the Free Pascal port — it's kept only as a historical artifact.
* The lost CPL/GUI's exact layout isn't recoverable (its source was never
  backed up), so the new GUI is a fresh design against the interface above.
* Everything in Section 4 is transcribed directly from the recovered assembly and
  `NETMODEM.INC`, so it is authoritative for the driver you hold.
```
