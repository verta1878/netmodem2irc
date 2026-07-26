# Building NetModem/32

Two parts build separately: the **driver** (Dedrick's MASM VxD, 9x only) and the
**GUI** (Lazarus, both branches). The driver builds on a Windows 9x VM; the GUI
builds anywhere Lazarus runs and cross-compiles to your Windows target.

---

## Driver — `NETMODEM.VXD` (9x branch only)

Requirements (per the original `driver/src/INFO`): **MASM 6.14**, the **Windows 9x
DDK**, and **Visual C++ 5 or 6**, on a Windows 95/98/ME host or VM.

1. Replace `driver/src/VMM.INC` with the clean copy from the Win9x DDK. (The
   recovered one is slightly truncated — it's a stock DDK header, so the DDK copy
   is authoritative.)
2. Assemble: `ml /c /Cp /coff NETMODEM.ASM`
3. Link as a VxD using `NETMODEM.DEF` (the segment/`EXPORTS NETMODEM_DDB` layout is
   already defined there).
4. Output is `NETMODEM.VXD`, loadable on 95/98/ME.

The VxD is Ring-0 and **cannot** load on the NT kernel (XP+). That's why the `nt`
branch uses a user-mode COM bridge instead — see below.

## GUI — server + config (both branches)

Requirements: **Free Pascal 3.2.x + Lazarus**. On your build machine install
Lazarus, then:

* Server:  open `server/NMServer.lpr` in Lazarus and Build.
* Config:  open `config/NMConfig.lpr` in Lazarus and Build.

Add `common/` to each project's unit search path so `NMVxD` is found.

### Targeting Windows 9x vs. modern Windows

* **9x branch:** build the GUI for **i386-win32**. FPC/Lazarus can target win32;
  the resulting `.exe` runs on 98/ME. Pair with the VxD above.
* **nt branch:** build for win32 or win64. Replace the VxD path in `NMVxD.pas`
  with a **com0com** (or similar) user-mode virtual COM port, and have the server
  bridge that port to WinSock. No kernel driver, no driver signing.

### Networking

The server's Telnet/TCP side is not yet included — add `server/NetTransport.pas`
using **Synapse** (`TTCPBlockSocket`) or **lNet**. Wire it to the `CM_CONNECT_NODE`
/ `CM_DISCONNECT_NODE` handlers in `MainForm.pas` and move bytes through the
driver's `IOCTL 0E`.

## Rebuilding the forms

`server/MainForm.pas` and `config/ConfigMain.pas` are scaffolds. The full original
layouts (all 8 forms, every control/caption/position) are documented in
[`GUI_BLUEPRINT.md`](GUI_BLUEPRINT.md); rebuild the remaining forms (`Form2`–`Form6`,
splash) as `.lfm` files from those, then attach the listed event handlers.

## Testing with a BBS

Once the driver and server run, point a FOSSIL-aware DOS BBS or door game at the
virtual COM port. Backported Mystic BBS (a38, DOS) is a natural test target — run it
in the same 9x VM against NetModem's virtual port and confirm inbound Telnet
sessions reach the board.
