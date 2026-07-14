unit NM_Int14ISR;
{ ===========================================================================
  netmodem2irc — INT 14h ISR scaffold (i8086 real-mode) — DESIGN STAGE
  ---------------------------------------------------------------------------
  *** THIS IS A DESIGN-STAGE SCAFFOLD. It is REASONED, NOT PROVEN. ***
  It cannot be compiled or tested until the fpc264irc i8086 (16-bit real-mode)
  backend exists. The register-mapping and structure are laid out so that, when
  the backport lands, finishing this is a mechanical fill-in — the LOGIC it calls
  (FossilDispatch) is already complete and tested (33 host tests).

  WHAT THIS IS
  The ISR (Interrupt Service Routine) is the thin real-mode handler that answers
  INT 14h when a DOS BBS door fires it. Its ONLY job is register plumbing:
    1. save registers,
    2. map the CPU registers (AH,AL,BX,CX,DX, ES:DI) -> our TFossilRegs,
    3. call FossilDispatch (the tested, audited core — DTR, block I/O, GET_INFO,
       flow control, all done),
    4. map results back into the CPU registers,
    5. restore and IRET.
  It stays TINY on purpose: an ISR runs in interrupt context (interrupts may be
  disabled); heavy work here destabilizes the system. All real logic lives in
  FossilDispatch, NOT here.

  ARCHITECTURE (the switch-shaped system, ISR is the thin on-ramp)
    door on node N -> INT 14h -> THIS ISR (thin: identify node N, plumb registers)
       -> FossilDispatch on node N's resident UART
       -> seam sender frames it (tagged NodeIndex=N)
       -> THE SWITCH (TNodeManager) routes among ACTIVE nodes (the ~5.4x path)
       -> node N's TServerLink -> wire
    The ISR does NOT route or manage nodes. It hands the one call to node N's UART;
    the SWITCH (already built + tested) does the multi-node routing. Many thin
    per-node on-ramps -> one switch -> many links.

  CONFIG (config-driven, CPL writes NM_Config)
    Which comport/node maps to which resident UART is set up at INSTALL time from
    NM_Config (via NM_ConfigApply -> the switch). By the time an INT 14h arrives,
    the node's UART already exists and is wired. The ISR just finds it by port and
    dispatches. The CPL config utility only ever writes NM_Config; it never touches
    this ISR.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  NM_UART16550, NM_Fossil;

{ Resident per-node UART table. At install time (from NM_Config), each served
  comport index gets a resident UART pointer here. The ISR looks up the UART for
  the port the door addressed (DX = port index in the FOSSIL calling convention). }
const
  NM_MAX_PORTS = 100;   { comports 0..99, matches NM_MAX_NODES }

var
  ResidentUarts: array[0..NM_MAX_PORTS-1] of PUart16550;
  { set true once InstallInt14 has hooked the vector }
  Int14Installed: Boolean;

{ Install / remove the INT 14h handler. DOS build only (real vector work). On the
  host these are no-ops so higher layers compile/test (mirrors NM_FossilDriver). }
procedure InstallInt14;
procedure RemoveInt14;

{ Register a resident UART for a comport/node index (called at install from
  NM_ConfigApply as it brings up each configured node on the switch). }
procedure SetResidentUart(APortIndex: Byte; AUart: PUart16550);

implementation

{$IFDEF DOS_TARGET}
uses
  Dos;   { for real-mode interrupt vector access (GetIntVec/SetIntVec) }

var
  PrevInt14: Pointer;   { saved previous INT 14h vector, restored on unload }

{ ---------------------------------------------------------------------------
  THE ISR ITSELF — design-stage real-mode handler.

  DESIGN NOTES (fill-in when i8086 lands):
  - Declared as an 'interrupt' procedure so the compiler emits the proper
    prologue/epilogue (push all regs, IRET). fpc264irc i8086 must support the
    'interrupt' directive for this to work; if the exact register frame differs,
    adjust the mapping below accordingly.
  - The FOSSIL calling convention (Raymond Gwinn X00):
       AH = function number
       AL = char (Fn 01 write) / sub-code
       DX = port index (which comport/node)
       ES:DI = buffer far pointer (Fn 18h/19h read/write block, Fn 1Bh get info)
       CX = byte count for block ops
    Returns go back in AX (and Fn 03/04 in AH/AL/BX) — see FossilDispatch.
  - Mapping ES:DI -> R.Buf: on real-mode, ES:DI is a far pointer. R.Buf is a
    PByte. The fill-in must form the flat/near pointer the memory model uses
    (e.g. Ptr(ES, DI) under the DOS memory model) and assign it to R.Buf. This is
    THE key real-mode-specific step and must be verified on real hardware/VM.
  --------------------------------------------------------------------------- }
procedure Int14Handler(
  { the exact parameter list depends on fpc264irc's 'interrupt' frame; shown
    named for clarity of intent — fill in to match the backend }
  Flags, CS, IP, AX, BX, CX, DX, SI, DI, DS, ES, BP: Word); interrupt;
var
  R: TFossilRegs;
  port: Byte;
  U: PUart16550;
begin
  { 1. identify the addressed port/node (DX = port index) }
  port := Lo(DX);
  if (port >= NM_MAX_PORTS) or (ResidentUarts[port] = nil) then
  begin
    { not one of ours (or unconfigured) -> chain to the previous handler so we
      don't break other FOSSIL/serial software. (Fill-in: JMP PrevInt14.) }
    { CallPrevInt14(...); }
    Exit;
  end;
  U := ResidentUarts[port];

  { 2. map CPU registers -> TFossilRegs }
  R.AH := Hi(AX);
  R.AL := Lo(AX);
  R.BX := BX;
  R.CX := CX;
  R.DX := DX;
  { ES:DI -> R.Buf (far pointer -> PByte). Real-mode-specific; verify on VM.
    R.Buf := PByte(Ptr(ES, DI)); }
  R.Buf := nil;   { placeholder until the far-pointer form is filled in }
  R.Handled := False;

  { 3. call the TESTED core — all FOSSIL logic lives here, not in the ISR }
  FossilDispatch(U^, R);

  { 4. map results back into the CPU registers the door will read }
  AX := (R.AH shl 8) or R.AL;
  BX := R.BX;
  CX := R.CX;
  { (block/info functions already wrote through R.Buf into the caller's ES:DI) }

  { 5. epilogue/IRET emitted by the 'interrupt' directive. }
end;

procedure InstallInt14;
begin
  if Int14Installed then Exit;
  GetIntVec($14, PrevInt14);
  SetIntVec($14, @Int14Handler);
  Int14Installed := True;
end;

procedure RemoveInt14;
begin
  if not Int14Installed then Exit;
  SetIntVec($14, PrevInt14);   { restore the previous handler }
  Int14Installed := False;
end;

{$ELSE}
{ ---- host build: no real INT 14h vector. No-ops so higher layers compile/test.
       (The ISR logic it would call, FossilDispatch, is fully host-tested.) ---- }
procedure InstallInt14;
begin
  Int14Installed := True;   { pretend-installed; nothing to hook on the host }
end;

procedure RemoveInt14;
begin
  Int14Installed := False;
end;
{$ENDIF}

procedure SetResidentUart(APortIndex: Byte; AUart: PUart16550);
begin
  if APortIndex < NM_MAX_PORTS then
    ResidentUarts[APortIndex] := AUart;
end;

var
  i: Integer;
initialization
  for i := 0 to NM_MAX_PORTS-1 do ResidentUarts[i] := nil;
  Int14Installed := False;
end.
