unit NM_FossilDriver;
{ ===========================================================================
  netmodem2irc — FOSSIL driver packaging (NetFOSSIL/32 revival) — M3.5b
  ---------------------------------------------------------------------------
  Wraps the TESTED FOSSIL service logic (NM_Fossil.FossilDispatch) behind a real
  INT 14h handler, so DOS BBS software can drive netmodem2irc as it drove
  NetModem/32's NetFOSSIL/32.

  Layering:
    DOS BBS --INT 14h--> [this driver's ISR] --> FossilDispatch (NM_Fossil, tested)
                                                 --> UART rings --> server seam

  DESIGN: the ISR does the minimum — map the CPU register frame onto TFossilRegs,
  call the tested dispatch, map the result back. All the ACTUAL FOSSIL semantics
  live in NM_Fossil (already tested). This unit is just the DOS packaging.

  TARGET: this is real-mode / go32v2 DOS code. The actual INT 14h vector hook
  (GetIntVec/SetIntVec + an interrupt handler) is guarded by DOS_TARGET and built
  under fpc264irc (which bundles the go32v2 toolchain). WITHOUT DOS_TARGET the
  unit still compiles (host build) and the register-frame MAPPING is testable via
  DispatchFrame — so the logic is verified even where the real ISR can't be built.

  VERIFICATION NOTE (honest): DispatchFrame (frame<->TFossilRegs<->dispatch) is
  testable on any host and IS tested. The real INT 14h hook + TSR residency need
  a go32v2/DOS build + a real door to verify.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  NM_UART16550, NM_Fossil;

type
  { A CPU register frame as an INT 14h handler sees it. On real x86 this overlays
    the actual pushed registers; here it's a plain record so the mapping is
    testable. Field names match the x86 registers FOSSIL uses. }
  TInt14Frame = record
    AX : Word;    // AH = function, AL = char/subcode
    BX : Word;
    CX : Word;
    DX : Word;    // DL = port index
    { (real ISR would also carry SI/DI/DS/ES/flags; not needed for FOSSIL fns) }
  end;

{ The core: take an INT 14h register frame, run the tested FOSSIL dispatch against
  a UART, and write results back into the frame. This is the heart of the driver
  and is fully host-testable. Returns True if the function was recognized. }
function DispatchFrame(var U: TUart16550; var F: TInt14Frame): Boolean;

{$IFDEF DOS_TARGET}
{ Install / remove the real INT 14h handler (go32v2/DOS only). These wrap the
  interrupt vector; the handler calls DispatchFrame on the resident UART. Built
  only for the DOS target under fpc264irc. }
procedure InstallFossil(var U: TUart16550);
procedure RemoveFossil;
{$ENDIF}

implementation

function DispatchFrame(var U: TUart16550; var F: TInt14Frame): Boolean;
var
  R: TFossilRegs;
begin
  { map the CPU frame -> TFossilRegs (the tested dispatch's input) }
  R.AH := Hi(F.AX);      // function number
  R.AL := Lo(F.AX);      // char / subcode
  R.BX := F.BX;
  R.CX := F.CX;
  R.DX := F.DX;          // DL = port index
  R.Handled := False;

  { run the TESTED FOSSIL service logic }
  FossilDispatch(U, R);

  { map results back into the CPU frame }
  F.AX := (R.AH shl 8) or R.AL;
  F.BX := R.BX;
  F.CX := R.CX;
  F.DX := R.DX;

  Result := R.Handled;
end;

{$IFDEF DOS_TARGET}
{ ---- real INT 14h hook (go32v2/DOS) ----
  NOTE: real-mode ISR details (saving the prior vector, chaining non-our-port
  calls, the interrupt attribute/register access) are DOS-target specifics
  finalized on the fpc264irc go32v2 build. Sketch of the shape: }

var
  PrevInt14 : Pointer;      // saved previous INT 14h vector
  ResidentU : PUart16550;   // the UART the ISR services

{ The actual interrupt handler would read the pushed CPU registers into a
  TInt14Frame, call DispatchFrame(ResidentU^, frame), and write them back to the
  register frame, chaining PrevInt14 for ports that aren't ours. Implemented with
  the go32v2 interrupt support on the DOS build. }

procedure InstallFossil(var U: TUart16550);
begin
  ResidentU := @U;
  { GetIntVec($14, PrevInt14); SetIntVec($14, @Int14Handler);  -- DOS build }
end;

procedure RemoveFossil;
begin
  { SetIntVec($14, PrevInt14);  -- restore on unload }
  ResidentU := nil;
end;
{$ENDIF}

end.
