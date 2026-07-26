# NetModem 2 — Windows GUI Recovery & Rebuild Guide

*The lost GUI, recovered from the alpha-3 installer (`nm32_2a3.zip`) and decompiled.
This is the blueprint for rebuilding it in Free Pascal / Lazarus without the
proprietary ShortcutBar.*

---

## 1. What was recovered

The alpha-3 InstallShield package (May 2000) was unpacked with a custom PKWARE-DCL
decompressor. All ten payload files came out byte-exact. The two that matter for
the GUI:

| File | What it is | Built with |
|------|-----------|-----------|
| `NETMODEM.CPL` | The **configuration** app (Control Panel applet) — 6 forms | Delphi 5 |
| `NETMODEM.EXE` | The **server / host** app (the FOSSIL telnet server) — 2 forms | Delphi 5 |
| `NETMODEM.DLL` | Shared Delphi runtime glue | Delphi 5 |
| `NETMODEM.VXD` | The compiled Ring-0 driver (matches the source we recovered) | MASM |
| `NETSERVER.CNF`, `NETCONFIG.CNF` | Binary config templates | — |
| `README.TXT`, `WHATSNEW.TXT`, `ATCOMNDS.TXT`, `FIX.EXE` | Docs + a fixup util | — |

Both GUIs are **Delphi 5**, which is the ideal case: Delphi embeds each form as a
binary DFM resource, so the complete UI — every control, caption, size, position,
and event-handler name — was recoverable. The decompiled forms are in `forms/*.dfm`.
This is alpha-3; you were looking for beta-4, but a3 is a complete, faithful
reference for the whole UI.

## 2. The GUI, screen by screen

### NETMODEM.EXE — the server (2 forms)

**TForm1 — main server window.** Menu-driven (`TMainMenu` with Exit / Setup /
Edit items), a status display built from `TPanel`×3, `TLabel`×8, a `TListView`
(the node/connection list), a `TStatusBar`, a `TTimer` (status refresh), and a
`TTrayIcon` (runs in the system tray — `TrayIconDblClick` restores it). Handlers:
`FormCreate`, `FormShow`, `FormCloseQuery`, `Timer1Timer`, `Setup1Click`,
`Exit1Click`, `TrayIconDblClick`.
> Uses **`TShortcutBar` + `TShortcutSheet`×2** — the Absolute Solutions component.

**TSplashForm — splash screen.** A `TImage` (400×300) plus a version `TLabel`,
shown at startup.

### NETMODEM.CPL — the configuration app (6 forms)

| Form | Caption | Purpose | Key controls |
|------|---------|---------|--------------|
| **TForm1** | *(main)* | Main config dialog, 424×398, help-enabled | **`TShortcutList`** left nav (105px), `TGroupBox`×3, `TComboBox`×3 (comport / baud / emulation), `TEdit`×2, `TUpDown`×2, `TSpeedButton`×3, `TBitBtn`×2 (OK/Cancel) |
| **TForm2** | Listserv Information | Listserv/telnet address entry | `TEdit`×7, `TStaticText`×7, `TListView`, `TButton`×5 |
| **TForm3** | Global Configuration | Per-node select w/ checkboxes | `TListView` (checkboxes), `TButton`×3 |
| **TForm4** | View Log | Log viewer | `TToolBar` + `TToolButton`×10, `TComboBox`, `TListView`, `TStatusBar`, `TFontDialog`, `TPrintDialog`, `TImageList` |
| **TForm5** | Icon Legend | Legend for the log icons | `TListView` |
| **TForm6** | *(address)* | Address entry, wildcards allowed | `TEdit` (lowercase), `TButton`×2, `TStaticText` |

The `.dfm` files carry exact geometry, tab order, help contexts, and the event
handler names — enough to reproduce the layout pixel-for-pixel and know what code
each control expects.

## 3. Replacing the ShortcutBar

The only proprietary dependency, in two places:
* `NETMODEM.EXE` → `TShortcutBar` + two `TShortcutSheet` pages (the Outlook-style
  bar in the server window).
* `NETMODEM.CPL` → `TShortcutList` (105px left nav switching config sections).

Free Lazarus replacements, no third-party code:
* **`TCategoryButtons`** (in `CategoryButtons` unit) — the closest match to an
  Outlook/shortcut bar; grouped, icon-topped buttons.
* **`TTreeView`** or **`TListView` (vsList/vsIcon)** — if you want the simple
  icon-list style the CPL used.
* **`TPageControl` with hidden tabs** driven by the nav — for the sheet-switching
  behavior of the server's `TShortcutSheet` pages.

Because the nav's only job was "click an entry → show the matching panel," any of
these drops in cleanly: bind each nav item's `OnClick` to show the corresponding
`TPanel`/page.

## 4. Wiring the GUI to the driver

The rebuilt GUI talks to the recovered `NETMODEM.VXD` through the IOCTL/message
interface documented in **NetModem2_Port_Guide.md** (from the driver-source
recovery). The mapping:

* **Config app (CPL):** reads/writes `HKLM\Software\Allen Software\NetModem`
  (`ComportConfig`, `IRQ`) — the `TComboBox`es for comport/baud/emulation and the
  `TUpDown`s set fields of the `ComportStruct`. On apply it calls `IOCTL 03`
  (reload config) so no reboot is needed (a WHATSNEW alpha-3 improvement).
* **Server app (EXE):** on startup calls `IOCTL 08` (register server window) with
  its `TForm1` handle, then reacts to the driver's posted messages
  (`CM_CONNECT_NODE` → open the WinSock telnet socket; `CM_DISCONNECT_NODE` →
  close it) and shuttles bytes through `IOCTL 0E`. The `TListView` is the node
  list; `TTimer` polls status.

So the three pieces now line up: recovered **driver source**, recovered **GUI
blueprint** (this doc + the DFMs), and the **interface spec** that binds them.

## 5. Suggested Lazarus project structure

```
NetModem2/
├── driver/                    ← recovered MASM source (build NETMODEM.VXD)
├── NMVxD.pas            ← IOCTL/message wrapper (from earlier recovery)
├── server/
│   ├── NMServer.lpr
│   ├── MainForm.pas/.lfm      ← rebuild of EXE TForm1 (node list, tray, menu)
│   ├── SplashForm.pas/.lfm    ← rebuild of TSplashForm
│   └── NetTransport.pas       ← WinSock telnet (Synapse TTCPBlockSocket)
└── config/
    ├── NMConfig.lpr
    ├── ConfigMain.pas/.lfm    ← rebuild of CPL TForm1 (+ TCategoryButtons nav)
    ├── frmListserv, frmGlobal, frmLog, frmLegend, frmAddress  ← TForm2..TForm6
    └── RegConfig.pas          ← read/write the NetModem registry keys
```

Rebuild each `.lfm` from the matching `forms/*.dfm` — the control names, captions,
and positions transfer almost directly (Lazarus LFM is the text-DFM format), then
reattach the event handlers listed per form.

## 6. Notes

* This is **alpha-3**; beta-4 (not yet found) may differ slightly, but the
  architecture and form set are stable across the 2.0 alphas.
* The extracted binaries are Win9x Delphi 5 executables — they still run on
  Win98/86Box for reference, so you can watch the original UI behave while you
  rebuild it.
* `NETMODEM.HLP` is referenced by the forms but wasn't in this package; help
  contexts are preserved in the DFMs if you rebuild a help file later.
