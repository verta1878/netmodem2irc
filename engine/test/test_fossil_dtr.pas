program test_fossil_dtr;
{$MODE OBJFPC}{$H+}
{ Verify Fn 06h SET_DTR handles BOTH directions (the fix informed by ELECOM
  ComBase Com_SetDtr(State) being stateful). Structural-sight check against the
  FOSSIL contract, not just "does it run". }
uses SysUtils, NM_UART16550, NM_Fossil;
var
  U: TUart16550; R: TFossilRegs; pass,fail: Integer;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;
  UartReset(U);

  writeln('== raise carrier first (simulate a connection) ==');
  UartSetCarrier(U, True);
  Check(U.Online, 'carrier up');

  writeln('== Fn 06h AL=0 -> lower DTR: hangup + DTR bit clear ==');
  R.AH := $06; R.AL := 0; R.Handled := True;
  FossilDispatch(U, R);
  Check(not U.Online, 'carrier dropped on DTR low (hangup)');
  Check((U.MCR and MCR_DTR) = 0, 'MCR DTR bit cleared');

  writeln('== Fn 06h AL=1 -> raise DTR: DTR bit set (line ready) ==');
  R.AH := $06; R.AL := 1; R.Handled := True;
  FossilDispatch(U, R);
  Check((U.MCR and MCR_DTR) <> 0, 'MCR DTR bit set on DTR high');
  { raising DTR alone should NOT fabricate carrier }
  Check(not U.Online, 'raising DTR does not falsely create carrier');

  writeln('== toggle again: lower then check hangup still works ==');
  UartSetCarrier(U, True);
  R.AH := $06; R.AL := 0; R.Handled := True;
  FossilDispatch(U, R);
  Check(not U.Online, 'second hangup via DTR low works');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('FOSSIL DTR (Fn 06h) BOTH DIRECTIONS - VERIFIED');
end.
