# netmodem2irc — Option A: native user-mode virtual COM driver (the frontier)

## What this is
Option A is the ambitious, **first-of-its-kind** piece: an open, user-mode
(UMDF2) virtual COM-port driver that presents a real COM port to native Windows
software (DOS BBS doors, comm programs) and bridges it to netmodem2irc's Telnet
server. Nobody has published one purpose-built for DOS-BBS-door-to-Telnet with a
documented, portable modem-emulation stack. This doc is the footing for it.

- **Option B (proof of concept): DONE.** The Pascal stack (UART/FOSSIL/transport/
  AT/multinode, 85+ passing checks) proves the emulation + Telnet bridge works.
  The named-pipe seam (NamedPipeLink) connects it to a driver.
- **Option A (frontier): the native driver.** Built in C/C++ (required — see why),
  following Microsoft's MS-PL sample, bridging to the Pascal server over a pipe.

## Why the DRIVER must be C/C++ (not a Pascal port) — honest and final
UMDF2 is not "an API you call" — it is a driver loaded by Windows' driver host
(WUDFHost.exe) that must implement Microsoft's WDF driver contract: specific
callbacks (DriverEntry / EvtDriverDeviceAdd / EvtIoRead / EvtIoWrite / the
IOCTL_SERIAL_* handlers) dispatched through the WDF object model, built against
the WDK's C/C++ headers (wdf.h, wudfddi.h). There are NO FreePascal bindings for
the WDF DDI, and the host expects the exact C/C++ ABI the WDK emits. "Porting" it
to Pascal would mean inventing a complete Pascal WDF framework binding, binary-
exact, untestable until WUDFHost either loads it or fails silently. That is not a
port; it is a research project with high failure odds. So: **the driver is C/C++.**
This is physics of the framework, not a language preference.

## The composition (this is the elegant part)
The driver stays THIN; the intelligence stays in the tested Pascal:

  DOS door / comm app
       |  (opens COMx — a real port Windows presents)
       v
  [C/C++ UMDF2 driver]  <- thin: presents COM port, handles IOCTL_SERIAL_*,
       |                        moves bytes to/from a NAMED PIPE
       |  \\.\pipe\netmodem-nodeN
       v
  [Pascal netmodem2irc server]  <- ALL the intelligence (already built + tested):
       NamedPipeLink (ISocketLink) -> NetTransport (Telnet) -> UART/FOSSIL/AT
       -> Synapse socket -> the remote BBS

Each language does what it's good at. We do NOT rewrite the emulation in C/C++
(it's done in Pascal), and we do NOT force the driver into Pascal (it can't go).

## The reference (verified from the actual source)
Microsoft **Windows-driver-samples / serial/VirtualSerial2** (github.com/microsoft/
Windows-driver-samples). Two sub-samples:
- **ComPort** — a minimal virtual serial driver.
- **FakeModem** — a controller-less MODEM driver that handles AT commands via
  ReadFile/WriteFile or TAPI. THIS is our primary reference — it's ~80% the shape
  of what we need (virtual COM + modem + AT), we just redirect its data path to
  our pipe instead of faking responses.

### License (verified): Microsoft Public License (MS-PL)
The repo's LICENSE is **MS-PL** (not MIT — earlier note corrected). MS-PL is
permissive and OSI-approved; it ALLOWS derivative works. We may base our driver
on the sample provided we honor MS-PL terms (keep the license notice, no using
Microsoft's name to endorse, etc.). Our driver is ORIGINAL code following the
sample's pattern — not a verbatim copy. Attribute the sample as the reference.

## Structure we follow (from the real sample)
- **driver.c/.h** — DriverEntry + EvtDriverDeviceAdd
- **device.c/.h** — device object, PnP
- **queue.c/.h** — EvtIoRead / EvtIoWrite + the IOCTL_SERIAL_* dispatch
- **ringbuffer.c/.h** — a byte ring buffer (mirrors our Pascal TByteRing!)
- **serial.h** — the serial IOCTL definitions
- **.inx** — the INF (Class=Ports) that registers the COM port

### The IOCTL_SERIAL_* contract our driver must fulfil (from the sample)
SET/GET_BAUD_RATE, SET/GET_LINE_CONTROL, SET/GET_HANDFLOW, SET/CLR_DTR, SET/CLR_RTS,
SET/GET_MODEM_CONTROL, SET/GET_CHARS, SET/GET_TIMEOUTS, SET_WAIT_MASK,
WAIT_ON_MASK, SET_QUEUE_SIZE, SET_FIFO_CONTROL, SET_XON/XOFF, RESET_DEVICE,
GET_COMMSTATUS, GET_DTRRTS. Most map to no-ops or trivial state over TCP (baud is
cosmetic); the important ones are READ/WRITE (-> pipe) and the modem-control /
WAIT_ON_MASK signalling.

### KNOWN GOTCHA (documented upfront — footing, not a surprise)
Per Microsoft Q&A on this exact sample: `IOCTL_SERIAL_WAIT_ON_MASK` in the sample
only QUEUES the request and never completes it (until the handle closes). For a
REAL modem that must signal "data available" / carrier change to the app, our
driver must properly COMPLETE the WAIT_ON_MASK IOCTL when bytes arrive from the
pipe (from the network). This is the one non-trivial extension beyond the sample.
Reference: the serial.sys WDK sample (a real 16550 driver) shows how to complete
WAIT_ON_MASK on receive. Plan for this explicitly.

## Build / test reality (honest boundaries)
- The C/C++ driver: written + documented here (referencing the MS-PL sample), but
  it must be BUILT (Visual Studio + WDK, MSBuild), SIGNED, and TESTED on Windows.
  Cannot be built or tested in the Pascal dev environment.
- Driver signing: on modern Win10/11 x64, installing an unsigned UMDF driver
  requires disabling driver-signature enforcement (or a real signing cert). This
  friction applies to ANY virtual-COM approach (com0com included) — not unique
  to us. Target Win2k+ (UMDF2 needs Win7+ realistically; for older, different).
- The Pascal seam (NamedPipeLink): buildable AND testable now (fake pipe).

## Sequencing (grounded, not a flail)
1. [done] Option B: Pascal emulation stack + tests (the proof of concept).
2. Pascal NamedPipeLink (ISocketLink over a named pipe) — testable now.
3. C/C++ UMDF2 driver skeleton following FakeModem — presents COM port, pipes
   bytes. Written here; built/signed/tested on Windows.
4. Wire driver <-> server over the pipe; handle WAIT_ON_MASK completion.
5. Installer (Inno Setup, NT branch) once the driver builds.

## Why this is worth doing (the "first")
An open, documented, user-mode virtual-COM-to-Telnet bridge with a portable modem
emulation stack does not exist. com0com is a generic null-modem; the commercial
tools are closed; G8BPQ is ham-specific; Dedrick's original was a 9x VxD. This
would be the first open reference implementation of the whole path for the DOS-BBS
preservation world — footing nobody has had.
