# Finishing the i8086 TSR when the backport lands — a fill-in guide

DESIGN-STAGE scaffolds are in place (host-compiling, real-mode parts guarded by
{$IFDEF DOS_TARGET}). They are REASONED, NOT PROVEN — they cannot be compiled or
tested for real until the fpc264irc i8086 (16-bit real-mode) backend exists. All
the LOGIC they call is already complete and tested (33 host tests). When the
backport lands, finishing is a mechanical fill-in. This is the checklist.

## The scaffolds
- NM_Int14ISR.pas   — the thin INT 14h ISR (register plumbing -> FossilDispatch).
- NM_TSRResident.pas — residency: load NM_Config -> switch -> register UARTs ->
                       hook INT 14h -> go resident.
(Both compile on the host today with the DOS parts guarded out.)

## The architecture they implement (switch-shaped, ISR is the thin on-ramp)
door on node N -> INT 14h -> ISR (thin: find node N, plumb registers)
  -> FossilDispatch on node N's resident UART (TESTED: DTR, block I/O, GET_INFO...)
  -> seam sender frames it (NodeIndex=N)
  -> THE SWITCH (TNodeManager, TESTED, ~5.4x) routes among ACTIVE nodes
  -> node N's TServerLink (NM_ServerLink, TESTED) -> wire
The ISR stays TINY (interrupt context). The switch does multi-node routing. Config
comes from NM_Config (CPL writes it) via NM_ConfigApply.

## Fill-in checklist (when i8086 exists)
1. INTERRUPT FRAME: confirm fpc264irc i8086 supports the `interrupt` directive and
   the exact pushed-register frame. Adjust Int14Handler's parameter list to match.
2. ES:DI -> R.Buf: the ONE key real-mode step. Form the pointer the DOS memory
   model uses (e.g. R.Buf := PByte(Ptr(ES, DI))) so Fn 18h/19h/1Bh read/write the
   caller's buffer. VERIFY on a real VM (NTVDM/DOSBox-X) with a door that does
   block I/O.
3. CHAIN-TO-PREV: for a port that isn't ours (ResidentUarts[port]=nil), JMP to
   PrevInt14 so other FOSSIL/serial software still works. Fill in the far-call/jmp.
4. GO RESIDENT: after InstallInt14, call the DOS terminate-stay-resident service
   (Turbo-style Keep, or INT 21h fn 31h) — the {$IFDEF DOS_TARGET} Keep(0) spot in
   NM_TSRResident.Install.
5. PUMP WIRING: connect each active node's pump to its real TServerLink instance
   (NM_ServerLink) — the NM_TSRResident.Pump body. Use TSynapseServerLink for TCP.
6. TIMING/REENTRANCY: ensure the ISR is non-reentrant-safe (it's short; keep it
   short). Heavy work stays out of interrupt context — only register plumbing +
   FossilDispatch (which is bounded and fast).

## Test plan (once buildable)
- Build the TSR for i8086, load in NTVDM (WinNT4) / DOSBox-X / ntvdmx64.
- Point a DOS door (or a simple INT 14h test program) at a configured port.
- Verify: byte echo, block transfer (Fn 18h/19h), GET_INFO, carrier/DTR, and a
  real Telnet connection through TSynapseServerLink to a live BBS.
- The host tests already prove FossilDispatch + seam + switch + link; the i8086
  test proves the register plumbing + residency + the ES:DI pointer mapping.

## Honest status
Scaffolds: compile on host, structure + register mapping laid out, marked
design-stage. Nothing here is runtime-proven for real mode. The tested core they
sit on (33 tests) is what makes the fill-in low-risk.
