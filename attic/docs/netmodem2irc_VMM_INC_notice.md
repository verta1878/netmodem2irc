# netmodem2irc — VMM.INC is CORRUPTED: replace with a clean DDK copy

## Finding (verified by reading the file, not just the README)
The README says the bundled `driver/src/VMM.INC` is "slightly truncated."
On inspection it is **worse than truncated — it is garbled/corrupted throughout.**
The tail of the file is scrambled bytes and mangled macro fragments (e.g.
`AL_cERCm iOSF`, `VMM_mcRI Rt naTA`, broken `BeginProc`/`EQU` fragments), not a
clean cutoff. It is **not usable to assemble the 9x VxD as-is.**

## Impact
VMM.INC provides the Windows 9x **Virtual Machine Manager** service definitions,
equates, and macros (BeginProc/EndProc, VMMCall, Control_Dispatch, segment
declarations, etc.) that NETMODEM.ASM depends on via `Include VMM.inc`. Without a
correct VMM.INC, `NETMODEM.ASM` cannot assemble — the macros it relies on are
undefined or wrong. **This blocks building the 9x-branch VxD.** (It does NOT
affect reading/mapping the source, and does NOT affect the NT branch, which has no
VxD.)

## Fix: replace with the clean copy from the Windows 9x DDK
VMM.INC is a standard Microsoft Win9x DDK file. Obtain a clean, complete copy:
- **Source:** the Windows 95/98 DDK (Driver Development Kit). VMM.INC ships in the
  DDK's include directory (commonly `\ddk\inc32\VMM.INC` or the VxD include set).
- **Also bundled with:** the Windows 98 DDK, and some MASM32/VxD toolchains that
  redistribute the 9x VxD includes.
- Replace `driver/src/VMM.INC` with the clean DDK copy. Do NOT hand-repair the
  corrupted one — VMM.INC is large (~thousands of lines of MASM equates/macros) and
  reconstructing it by hand is error-prone; use the authoritative DDK original.

## How to verify the replacement is good
1. It should be plain, readable MASM throughout (no garbled bytes at the tail).
2. It must define the macros NETMODEM.ASM uses: `BeginProc`, `EndProc`, `VMMCall`,
   `Control_Dispatch`, `VxD_LOCKED_CODE_SEG`, etc.
3. Test assemble: `ml /c /Cx /coff NETMODEM.ASM` (MASM 6.14 per BUILD.md) should get
   past the `Include VMM.inc` stage without "undefined macro/symbol" errors.
4. The other bundled includes (SHELL.INC, VPICD.INC, VCOMM.INC, VWIN32.INC,
   REGDEF.INC, VCOMMW32.INC, NETMODEM.INC) appear intact — spot-check they are
   readable MASM too, but the known-bad one is VMM.INC.

## License note
VMM.INC is a Microsoft DDK file, not Dedrick's work — it is a build-time dependency,
not part of the GPLv2 driver source. Document where to obtain it; do not necessarily
redistribute the DDK file in the repo unless its license permits. A README pointer to
"get VMM.INC from the Win9x DDK" is the clean approach (same spirit as not bundling
Watt-32 into the GPL fpc264irc repo).

## Status
- [ ] Replace driver/src/VMM.INC with clean Win9x DDK copy
- [ ] Verify NETMODEM.ASM assembles past the include stage
- [ ] Note in BUILD.md: "VMM.INC bundled copy is corrupt — obtain clean copy from
      Win9x DDK before assembling the 9x VxD"
This only affects the **9x branch** VxD build. The NT branch (user-mode, no VxD)
does not need VMM.INC at all.
