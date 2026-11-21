# netmodem2irc Installer Audit — InnoIRC561 Bug Fix Impact
## wrench, 2026-11-20

### Installer Scripts Reviewed

1. **installer/netmodem32.iss** — Full product installer (Win9x + NT + DOS)
2. **InnoIRC561/netmodem2irc.iss** — Simplified NT-only installer

### Impact of byte's 6 InnoIRC561 Fixes

| Bug | Fix | netmodem32.iss | netmodem2irc.iss |
|-----|-----|----------------|------------------|
| 1 — LZMA crash | cdecl callbacks + var alloc | ✅ AFFECTED — all setups crashed | ✅ AFFECTED |
| 3 — Win98 blocked | MinVersion Win9x re-enabled | ✅ AFFECTED — has Win9x components | ❌ NT-only, N/A |
| 6 — Silent exit hang | Application.Terminate | ✅ AFFECTED — /SILENT hung forever | ✅ AFFECTED |
| 8 — [Code] broken | PS_NOIDISPATCH fix | ✅ AFFECTED — has [Code] (IsWin9x) | ❌ No [Code] section |
| 9 — GetExceptionMessage | LastEx* fix | ❌ Not used | ❌ Not used |
| 10 — Script compile empty | fpc264irc BUG-049 | ❌ No complex [Code] | ❌ No [Code] |

### Recommendations

**installer/netmodem32.iss:**
- Change `MinVersion=0,5.0` → `MinVersion=4.1,5.0`
  This enables Win98/ME installs, matching the script's existing Win9x
  components (FOSSIL.VXD, IsWin9x check, SYSTEM.INI registration).
  Without this change, Win98 users can't run the installer even though
  the script has everything they need.
- The [Code] section (IsWin9x/IsWinNT) now compiles and runs correctly
  with byte's bug 8 fix. No code changes needed there.

**InnoIRC561/netmodem2irc.iss:**
- Consider merging netmodem32.iss's Win9x/DOS components into this
  script, or deprecating it in favor of netmodem32.iss as the single
  installer. Currently it's a subset missing the DOS/VxD components
  that are core to netmodem2irc's purpose (virtual modem for BBS).
- If kept as NT-only, MinVersion=5.0 is correct as-is.

### No Code Changes Needed in Installer Scripts

byte's fixes are all in InnoIRC561's compiler/runtime Pascal source, not
in .iss scripts. The scripts compile and run correctly with the fixed
InnoIRC561 without modification — EXCEPT the MinVersion change above,
which is a one-line policy change to take advantage of bug 3's fix.

### Update — byte, 2026-11-21

- The MinVersion change above was made in a copy of `netmodem32.iss` at the repo root (its `Win32\`, `Win9x\`,
  `DOS\`, `Docs\` paths only exist under `installer/`); that copy is now `attic/netmodem32.iss`, and
  `installer/netmodem32.iss` has `MinVersion=4.1,5.0`.
- `installer/netfosdl.iss` had the same block (`0,5.0` with a Win9x component) and a licence path that does not
  exist - both fixed.
- Neither script could be built with InnoIRC561 at all: they use `#define` (ISPP), which InnoIRC561 did not have.
  ISPP is now ported (`InnoIRC561/out/ISPP.dll`); both build unchanged. The setups in `installer/Output` were made
  with stock Inno Setup.
- Tested under Wine, Windows 2000 and Windows 98 mode: both build, install silently, uninstall. Real Win98: open.
