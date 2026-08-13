# NetModem/32 — the recovery

How an abandoned BBS driver was recovered from a crashed forum database
and turned into a living project.

## The loss

NetModem/32 was written by Dedrick Allen (mag69, Allen Software) between
1997 and 2001. It was a Windows 9x virtual COM port driver and FOSSIL
Telnet server for DOS BBS software — the bridge between the modem era
and the internet. It shipped as shareware, reached beta-4, and was
abandoned.

The source was never publicly released. Dedrick shared it on xtcbox.org,
a small BBS community forum. That forum ran vBulletin. At some point
the forum went down, and with it went the only public copy of the
NetModem/32 source code.

## The recovery

**Source: the vBulletin `attachment` table.**

The xtcbox.org MySQL database survived as a raw backup (April 2007).
The file `attachment.MYD` — vBulletin's attachment storage table —
contained forum post attachments as binary blobs embedded in MySQL's
row format.

Three archives were carved from `attachment.MYD`:

| Archive | Contents | Status |
|---|---|---|
| **`nmsource.zip`** | Complete NetModem 2 driver source | ✅ CRC-clean, decompressed perfectly |
| `sbardem.zip` | Absolute Solutions ShortcutBar demo — the proprietary Delphi component Dedrick used for the GUI | recovered |
| `emailv10.zip` | Unrelated — a Mystic BBS email-validation tool | recovered |

`nmsource.zip` contained the **complete driver source**:

| File | What it is |
|---|---|
| `NETMODEM.ASM` | 5,712 lines MASM — VxD virtual COM port + 16550 UART + FOSSIL emulation |
| `NETMODEM.INC` | Structures, constants, driver↔host message protocol |
| `NETMODEM.DEF` | VxD segment/export definition |
| `NETMODEM.RC` / `RESOURCE.H` | Version resource |
| `SHELL.INC`, `REGDEF.INC` | Driver includes |
| `VMM.INC`, `VPICD.INC`, `VCOMM.INC`, `VWIN32.INC`, `VCOMMW32.INC` | Win9x DDK includes (stock) |
| `COPYING`, `INFO` | License + build notes |

Identity confirmed from `NETMODEM.INC` / `NETMODEM.ASM`:
`NetModem/32 v2.0.0.4/Alpha`, `Device_Driver_ID = 3D20h`,
`Driver_Version = 2004h`, by Dedrick Allen / Allen Software, 1997–2001.

## The GUI recovery

The driver source was the code side. The GUI — `NETMODEM.CPL` (config
applet) and `NETMODEM.EXE` (the server) — was recovered from a
different source: the alpha-3 installer package (`nm32_2a3.zip`, May
2000).

The InstallShield package was unpacked with a custom PKWARE-DCL
decompressor. All ten payload files came out byte-exact:

| File | What it is |
|---|---|
| `NETMODEM.CPL` | Configuration Control Panel applet — 6 Delphi 5 forms |
| `NETMODEM.EXE` | The server / host app — 2 Delphi 5 forms |
| `NETMODEM.DLL` | Shared Delphi runtime |
| `NETMODEM.VXD` | Compiled Ring-0 driver (matches recovered source) |
| `NETSERVER.CNF`, `NETCONFIG.CNF` | Binary config templates |
| `README.TXT`, `WHATSNEW.TXT`, `ATCOMNDS.TXT` | Documentation |

Both GUI apps were Delphi 5, which embeds each form as a binary DFM
resource. The complete UI — every control, caption, size, position,
and event-handler name — was decompiled from the binaries. Those
decompiled forms are in `cpl/original_forms/`.

**Note:** beta-4 was never found. Alpha-3 is the most complete version
recovered. The two may differ slightly, but a3 is a faithful reference
for the full UI and driver interface.

## The hand-off

Dedrick Allen later released the source to Antonio Rico (Reapern66 /
verta1878), who had been a NetModem beta tester during the original
era. The release was under GPLv2.

The revival — netmodem2irc — is Antonio's from-scratch reimplementation
of the user-mode side in Free Pascal, targeting the same FOSSIL and
UART specifications the original implemented, but portable from
Windows 98 through Windows 11. Dedrick's driver source is preserved
verbatim in `driver/src/` and remains under GPLv2. The revival code is
GPLv3. See `LICENSES.md`.

## What survived and where it lives

| What | Where | Original form |
|---|---|---|
| Driver source (MASM) | `driver/src/` | `nmsource.zip` from `attachment.MYD` |
| Compiled binaries | `history/` | alpha-3 installer + earlier distributions |
| `NETMODEM.CPL` (original) | `out/i386/NETMODEM.CPL` | alpha-3 installer |
| Decompiled GUI forms | `cpl/original_forms/` | DFM extraction from the Delphi 5 binaries |
| Documentation | `docs/original/` | `README.TXT`, `WHATSNEW.TXT`, `ATCOMNDS.TXT` |
| VxD build notes | `docs/netmodem2irc_VMM_INC_buildnote.md` | our finding: `VMM.INC` is corrupted |
| Driver functional map | `docs/netmodem2irc_DRIVER_MAP.md` | our analysis of `NETMODEM.ASM` |
| Driver interface spec | `docs/DRIVER_INTERFACE.md` | our reconstruction from the source |
| GUI rebuild blueprint | `docs/GUI_BLUEPRINT.md` | our decompilation + analysis |

## What was lost

| What | Status |
|---|---|
| Beta-4 installer (`nm32_2b4.zip`) | never found |
| The user-mode Delphi source (the GUI / server app) | never recovered — it was Delphi 5 + ShortcutBar, neither of which survives |
| The ShortcutBar component | `sbardem.zip` recovered but it's a demo, not the full component |
| Dedrick's Delphi project files (`.dpr`, `.pas`) | never shared publicly |

The Delphi source is why netmodem2irc exists: the driver interface is
fully documented, the GUI forms are decompiled, and the protocol
specifications are public standards. Everything needed to rebuild the
user-mode side exists. What doesn't exist is Dedrick's implementation
of it — so the revival is a reimplementation, not a port.

## The lesson

The code survived because someone kept a MySQL backup. Not a release,
not a tarball, not a repo — a database dump from a crashed forum. The
recovery worked because vBulletin stores attachments as blobs in a
table, and MySQL's row format is simple enough to carve.

That is why this project documents everything, dates everything, and
keeps original files verbatim. The next recovery won't come from a
database. It will come from this repo.

## See also

- `docs/DRIVER_INTERFACE.md` — the full interface spec, reconstructed
- `docs/GUI_BLUEPRINT.md` — the GUI recovery and rebuild guide
- `docs/netmodem2irc_DRIVER_MAP.md` — functional map of NETMODEM.ASM
- `docs/netmodem2irc_VMM_INC_buildnote.md` — VMM.INC corruption finding
- `CREDITS.md` — the hand-off and the team
- `LICENSES.md` — the chain of title
