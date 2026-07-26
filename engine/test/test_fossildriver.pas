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

program test_fossildriver;
{$MODE OBJFPC}{$H+}
{ M3.5b test: simulate DOS BBS INT 14h calls hitting the driver's DispatchFrame,
  exactly as a real FOSSIL client (or ELECOM FOS_COM) would call. }
uses NM_UART16550, NM_Fossil, NM_FossilDriver;
var
  U: TUart16550; F: TInt14Frame; pass,fail:Integer;
procedure Check(c:Boolean;const n:string);
begin if c then begin Inc(pass);writeln('  PASS: ',n);end else begin Inc(fail);writeln('  FAIL: ',n);end;end;
begin
  pass:=0;fail:=0;
  UartReset(U);

  writeln('== INT 14h fn 04h (init) -> AX must be $1954 (FOSSIL signature) ==');
  { a DOS BBS does: AH=$04, DL=port, INT 14h; expects AX=$1954 }
  FillChar(F,SizeOf(F),0);
  F.AX := $0400;      // AH=04 (init), AL=0
  F.DX := $0000;      // DL=0 (port 0)
  Check(DispatchFrame(U, F), 'init recognized');
  Check(F.AX = $1954, 'AX = $1954 (this IS a FOSSIL, as ELECOM FOS_COM checks)');

  writeln('== INT 14h fn 03h (status) after init ==');
  FillChar(F,SizeOf(F),0);
  F.AX := $0300;      // AH=03 (status)
  Check(DispatchFrame(U, F), 'status recognized');
  // AH bit tests are internal; just confirm it dispatched

  writeln('== send a char (fn 01h) then check it is in the TX ring ==');
  FillChar(F,SizeOf(F),0);
  F.AX := $0100 or Ord('H');   // AH=01 (tx), AL='H'
  DispatchFrame(U, F);
  Check(U.TX.Count >= 1, 'char H queued to TX ring via INT 14h');

  writeln('== receive path: put a char in RX ring, fn 02h returns it ==');
  RingPut(U.RX, Ord('i'));
  FillChar(F,SizeOf(F),0);
  F.AX := $0200;      // AH=02 (rx)
  DispatchFrame(U, F);
  Check(Lo(F.AX) = Ord('i'), 'received char i via INT 14h fn 02h');

  writeln('== unknown function is not falsely claimed ==');
  FillChar(F,SizeOf(F),0);
  F.AX := $7F00;      // AH=7F (not a FOSSIL fn)
  Check(not DispatchFrame(U, F), 'unknown fn reports not-handled (chains to prev)');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('FOSSIL DRIVER FRAME DISPATCH VERIFIED');
end.
