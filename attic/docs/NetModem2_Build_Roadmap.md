# NetModem/32 Revival — Build Roadmap

Goals for taking the published source to working binaries, on the Windows 98 VM
(9x branch) and then forward to modern Windows (nt branch). Work top to bottom.

---

## Milestone 0 — VM prep (once)
- [ ] **SNAPSHOT the Win98 VM first.** Every step below should be reversible.
- [ ] Get the `netmodem2` repo into the VM (clone or copy the files), e.g. `C:\netmodem2`.

### What to download and where to get it

**Note:** these are decades-old Microsoft dev tools, hosted as abandonware. Use the
well-known archives below (WinWorld, Internet Archive, mdgx), not random file-hosts.

**The OS (only if building the VM fresh):**
- [ ] Windows 98 SE ISO — WinWorld (`winworldpc.com`, Windows 98 SE "Retail Full").
      If your existing Win98 VM already boots and works, you can skip this; grab it
      as a clean fallback.

**Driver toolchain (the Win9x side):**
- [ ] **Windows 98 DDK** — the key download. Sources:
      - Internet Archive: `archive.org/details/DDK-9x-ME`  (`98DDK.RAR`, ~46 MB)
      - or mdgx mirror: `https://www.mdgx.com/spx/98DDK.RAR` (complete DDK + patches,
        known-good)
      Provides the VxD build environment **and** the clean `VMM.INC` / `VWIN32.INC`
      headers to swap into the repo.
- [ ] **MASM 6.14** — install MASM 6.11 then apply the 6.14 patch (assembler = `ML.EXE`).
      Available via WinWorld / archive.org DDK collections. (A Win95/98 DDK CD also
      ships a `MASM611C` directory as a fallback source.)
- [ ] **Visual C++ 5.0** — WinWorld. Provides `LINK.EXE` and build tools the DDK expects.

**GUI toolchain (both branches):**
- [ ] **Lazarus / Free Pascal for Windows** — `lazarus-ide.org`. For the 9x branch use
      an **older** release that still runs on/targets Win98 (newer Lazarus dropped 9x
      support). Exact version TBD — pin it down when reaching Milestone 2.

### Where each piece installs in the VM
- [ ] DDK → `C:\98DDK` (default). Its `inc32\VMM.INC` is the clean header to copy over
      the repo's `driver/src/VMM.INC`.
- [ ] Visual C++ 5 → install everything (safe default).
- [ ] MASM → put its `BIN\` (with `ML.EXE`) on the `PATH`.

### Two setup gotchas (bite everyone — do these before building)
- [ ] Increase environment space: add to `config.sys` →
      `shell=c:\command.com /p /e:4096`
- [ ] Build from the DDK's **"Checked Build Environment"** command prompt (added to the
      Start menu), not a plain DOS box.
      *(Reference: bikodbg.com "Notes on setting up the Windows 98 DDK".)*

## Milestone 1 — Build the driver (9x branch)
- [ ] Replace `driver/src/VMM.INC` with the clean copy from the Win9x DDK
      (the recovered one is slightly truncated).
- [ ] Assemble: `ml /c /Cp /coff NETMODEM.ASM`
- [ ] Link as a VxD using `NETMODEM.DEF`.
- [ ] **Goal:** `NETMODEM.VXD` loads on Win98 with no error. Proves the recovered
      source is sound.

## Milestone 2 — Build the GUI shell (both branches)
- [ ] Open `server/NetModemServer.lpr` and `config/NetModemConfig.lpr` in Lazarus.
- [ ] Get them compiling (they're scaffolds — expect missing forms/units to fix).
- [ ] Rebuild the remaining forms from `docs/GUI_BLUEPRINT.md` as `.lfm`:
      server Splash; config Form2 (Listserv), Form3 (Global), Form4 (View Log),
      Form5 (Icon Legend), Form6 (Address).
- [ ] **Goal:** both apps launch and show their windows (no networking yet).

## Milestone 3 — Driver <-> GUI communication
- [ ] Server: on startup call `IOCTL 08` (register window); confirm it receives
      the `CM_CONNECT_NODE` / `CM_DISCONNECT_NODE` messages.
- [ ] Config: read/write `HKLM\Software\Allen Software\NetModem`
      (`ComportConfig`, `IRQ`), then call `IOCTL 03` (reload, no reboot).
- [ ] **Goal:** the GUI actually controls the loaded driver.

## Milestone 4 — Network transport
- [ ] Write `server/NetTransport.pas` using Synapse (`TTCPBlockSocket`).
- [ ] Bridge the Telnet socket to the driver's data path (`IOCTL 0E`).
- [ ] Handle Telnet BINARY option via `CM_WILL_BINARY` / `CM_WONT_BINARY`.
- [ ] **Goal:** an inbound Telnet connection reaches the virtual COM port.

## Milestone 5 — End-to-end BBS test
- [ ] Point a FOSSIL-aware DOS BBS at the virtual COM port.
- [ ] Test target: **backported Mystic a38 (DOS)** in the same 9x VM.
- [ ] **Goal:** a real Telnet session logs into the board. This is "working" for 9x.

## Milestone 6 — First binary release
- [ ] Tag `v2.0-a3-revival` on GitHub.
- [ ] Attach VM-built `NETMODEM.VXD` + the GUI `.exe`s as Release assets.
- [ ] Paste the matching `CHANGELOG.md` notes into the release description.

---

## nt branch (Windows XP -> 11) — after 9x works
- [ ] Branch `nt` from `main`.
- [ ] Replace the VxD path in `common/NetModemVxD.pas` with a **com0com**
      user-mode virtual COM port (you already have the com0com family on hand).
- [ ] Point the same Lazarus GUI + `NetTransport.pas` at the com0com port.
- [ ] **Goal:** NetModem runs on modern Windows with no kernel driver and no
      driver-signing requirement, all the way to Windows 11.

---

## Repo housekeeping (anytime, low priority)
- [ ] Add an About description + topics (`bbs`, `fossil`, `telnet`, `vxd`,
      `lazarus`) so it's findable.
- [ ] Create the `9x` and `nt` branches when ready to structure the two targets.

## How we'll work
Each milestone is a back-and-forth: you try it in the VM, paste me the errors or
what you see, I fix the Pascal / adjust the steps. The recovered forum "Bugs" and
"Mystic 1.x" threads are a head start on known rough edges. No milestone has to
happen in one sitting.
