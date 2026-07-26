{ ===========================================================================
  netmodem2irc - part of the NetModem/32 revival
  Copyright (C) 2025-2026 Antonio Rico (Reapern66 / verta1878)

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.

  Dedrick Allen's original NetModem/32 material preserved in driver/src/,
  history/ and cpl/original_forms/ remains under GPLv2 - see LICENSES.md.
  =========================================================================== }

program test_fossil_flow;
{$MODE OBJFPC}{$H+}
{ Fn 0Fh flow control: over TCP we report NONE in effect (AL=0), honestly, rather
  than leaving AL undefined. Also re-check Fn 00h SET_BAUD still works (regression
  guard for the edit). }
uses SysUtils, NM_UART16550, NM_Fossil;
var U: TUart16550; R: TFossilRegs; pass,fail: Integer;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;
  UartReset(U);

  writeln('== Fn 0Fh: request flow control -> report NONE in effect (AL=0) ==');
  FillChar(R, SizeOf(R), 0);
  R.AH:=$0F; R.AL:=$0B;   // door requests XON/XOFF + CTS/RTS
  FossilDispatch(U, R);
  Check(R.AL=0, 'AL=0: honestly reports no flow control in effect over TCP');
  Check(R.Handled, 'function recognized (not a no-op fall-through)');

  writeln('== Fn 00h SET_BAUD still works (regression guard) ==');
  FillChar(R, SizeOf(R), 0);
  R.AH:=$00; R.AL:=$83;   // some baud/line param
  FossilDispatch(U, R);
  Check(U.DLL=$83, 'baud param stored (SET_BAUD not lost in the edit)');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('FOSSIL FLOW CONTROL (Fn 0Fh) + SET_BAUD - VERIFIED');
end.
