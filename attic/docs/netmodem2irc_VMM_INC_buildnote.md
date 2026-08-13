# netmodem2irc — build note: VMM.INC is corrupted, use a clean DDK copy (9x VxD)

## The problem (VERIFIED, not just README hearsay)
Building the 9x-branch VxD (NETMODEM.VXD) from driver/src/ requires VMM.INC. The
bundled copy is BAD. The README says "slightly truncated" — reading the actual
file, it's worse than that: the tail is **byte-level corrupted/garbled**, not a
clean truncation. Last lines are unreadable macro fragments, e.g.:
  `n < EELoO c4CRITRlselagsame]AIs eWreg-aMctr [??_basWreg-aMc_(na...`
So VMM.INC cannot be relied on to assemble correctly as-is.

## Why it matters
NETMODEM.ASM depends on many VMM services that VMM.INC must correctly define.
Confirmed VMMCall usages include:
  Install_IO_Handler, Remove_IO_Handler, Begin_Nest_Exec, End_Nest_Exec,
  Begin_Nest_V, Exec_Int, Simulate_Iret, Simulate_Far_Jmp, Resume_Exec,
  Set_Global_Time_Out, Cancel_Time_Out, Get_System_Time, Adjust_Execution_Time,
  Enable_VM_Ints, Close_VM, Release_Time_Slice, List_Create/Allocate/Attach/
  Get_Next, and more.
If VMM.INC's macros/equates for these are corrupted, the assemble fails or (worse)
silently miscompiles Ring-0 code.

## The fix
Replace driver/src/VMM.INC with the clean, official copy from the **Windows 95/98
DDK** (Device Driver Kit). VMM.INC is a standard Microsoft DDK include; the
authoritative copy ships with the Win9x DDK.

### Steps
1. Obtain the Win9x DDK (Windows 95 DDK or Windows 98 DDK).
2. Locate its VMM.INC (typically under the DDK's INC or INC32 directory).
3. Replace driver/src/VMM.INC with the DDK copy.
4. Assemble with MASM 6.14 + the Win9x DDK per docs/BUILD.md.

### Honest notes
- Keep the DDK VMM.INC's licensing in mind — it's a Microsoft DDK file. Do NOT
  commit the Microsoft VMM.INC into this GPLv2 repo (license mismatch). Instead:
  document that the builder supplies it from their DDK (same pattern as "bring your
  own binutils" — reference, don't bundle a mismatched-license file).
- This only affects the **9x VxD build**. The **nt branch** does not use the VxD at
  all (see NT_TRANSPORT_LAYER doc), so VMM.INC is irrelevant there.
- Verify after swapping: the ~20 VMMCall services above all resolve, and the VxD
  links via NETMODEM.DEF.

## Status
9x VxD build: BLOCKED on a clean VMM.INC (bundled copy corrupted). Builder must
supply DDK VMM.INC. Not a code bug in NETMODEM.ASM — a missing/corrupt include.

---

## VERIFICATION CHECKLIST for a replacement VMM.INC (extracted from NETMODEM.ASM)

When you obtain a clean VMM.INC from the Win9x DDK, confirm it defines everything
the driver actually uses. These were extracted directly from NETMODEM.ASM:

### 28 VMM service calls that MUST resolve (VMMCall ...)
Adjust_Execution_Time, Begin_Nest_Exec, Begin_Nest_V, Cancel_Time_Out, Close_VM,
Enable_VM_Ints, End_Nest_Exec, Exec_Int, Get_System_Time, Install_IO_Handler,
List_Allocate, List_Attach, List_Create, List_Get_Next, Release_Time_Slice,
Remove_IO_Handler, Resume_Exec, Set_Global_Time_Out, Simulate_Far_Jmp,
Simulate_Iret, Validate_VM_Handle, Wake_Up_VM, _HeapAllocate, _HeapFree,
_RegCloseKey, _RegOpenKey, _RegQueryValueEx, _lstrcmpi

The load-bearing ones: **Install_IO_Handler / Remove_IO_Handler** (the I/O-port
trapping that IS Layer B), the Nest_Exec / Simulate_Iret / Exec_Int group (VM
execution control), and the List_* services (buffer management).

### 7 macros/declarations that MUST be defined
BeginProc, EndProc, Control_Dispatch, Declare_Virtual_Device,
VxD_LOCKED_CODE_SEG, VxD_LOCKED_DATA_SEG, VxD_PAGEABLE

### Build environment (from docs/BUILD.md + driver/src/INFO)
MASM 6.14, Windows 9x DDK, Visual C++ 5 or 6, on a Win95/98/ME host or VM.

### Verify procedure
1. Swap in the DDK VMM.INC.
2. `ml /c /Cx /coff NETMODEM.ASM` (MASM 6.14) — must pass the include stage with
   no "undefined symbol/macro" for any of the 28 services or 7 macros above.
3. Link the VxD via NETMODEM.DEF.

## HONEST NOTE — why this file was NOT auto-replaced
The clean VMM.INC must come from a genuine Windows 9x DDK. It cannot be
reconstructed or fabricated — it is a precise Microsoft artifact of thousands of
MASM equates/macros, and a made-up version would fail subtly (worse than the known-
corrupt one). It also should NOT be committed into this GPLv2 repo (Microsoft
license). The correct action: the builder supplies VMM.INC from their own Win9x DDK.
This checklist lets them confirm their copy is complete before building.

---

## WHERE TO GET A CLEAN VMM.INC (verified sources)
- **Windows 98 DDK** is the complete, single-source option — it "includes
  everything" (VMM.INC + the VxD include set + MASM 6.11d), unlike the Win95 DDK
  which needed the Win32 SDK alongside it. Prefer the **Win98 DDK**.
- The authentic Microsoft installer is **`98ddk.exe`** (originally distributed by
  Microsoft; commonly mirrored on archive sites, e.g. archive.org's Win9x/ME DDK).
- VMM.INC lives in the DDK's include directory (`inc` / `inc32`).
- Note: BUILD.md wants MASM 6.14; the Win98 DDK ships MASM 6.11d — either works for
  VxD builds; 6.14 is fine if you have it.

### SAFETY / LICENSE (honest)
- Old redistributed DDK installers from archive sites cannot be integrity-verified
  here. Use a VM, check checksums if provided, apply normal caution.
- VMM.INC is a Microsoft file — DO NOT commit it into this GPLv2 repo. Builder
  supplies it from their own DDK (reference, don't bundle).

## BUILD QUIRK (so a config error isn't mistaken for a corrupt file)
Even a CLEAN VMM.INC can throw `vmm.inc(NNN): error A2008: syntax error : &` if the
MASM-mode define isn't set. Fix (documented by VxD builders): add after `.386p`:
```
    MASM = 1
```
or assemble with the define: `ml -coff -c -Cx -DMASM6 -DBLD_COFF -DIS_32 NETMODEM.ASM`
So if you swap in a clean VMM.INC and still get macro/syntax errors, check the MASM
define BEFORE suspecting the file — this is a known VxD-build gotcha, not corruption.
