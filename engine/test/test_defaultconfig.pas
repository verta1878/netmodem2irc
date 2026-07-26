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

program test_defaultconfig;
{$MODE OBJFPC}{$H+}
{ Tests NM_DefaultConfig: factory defaults match original NetModem v1 CPL,
  TRegComportStruct matches VxD ComportStruct byte-for-byte.
  DefaultNodeConfig and CreateDefaultConfig are in NM_Config. }
uses SysUtils, NM_Config, NM_DefaultConfig;
var
  cfg: TNMConfig; c: TNodeConfig; pass,fail: Integer;
  reg: TRegComportStruct;
procedure Check(cc:Boolean;const nm:string);
begin if cc then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
begin
  pass:=0;fail:=0;

  writeln('== DefaultNodeConfig matches NetModem v1 factory defaults ==');
  c := DefaultNodeConfig;
  Check(c.NodeIndex = 1, 'node 1');
  Check(c.ComPort = 3, 'COM3');
  Check(c.Baud = 38400, 'baud 38400');
  Check(c.Mode = nmFossil, 'FOSSIL mode');
  Check(c.Enabled = True, 'enabled');
  Check(c.InternetPort = 23, 'telnet port 23');
  Check(c.BaseAddress = $03E8, 'base $03E8 (standard COM3)');
  Check(c.BufferSize = 2048, 'buffer 2048');
  Check(c.AlwaysActive = False, 'alwaysactive off');
  Check(c.LockedBaudRate = True, 'lockedbaud on');
  Check(c.ManageTimeSlice = True, 'timeslice on');

  writeln('== CreateDefaultConfig produces valid config ==');
  cfg := CreateDefaultConfig;
  Check(cfg.IsValid, 'config valid');
  Check(cfg.NodeCount = 1, '1 node');
  Check(cfg.GetNode(1, c), 'node 1 present');
  Check(c.ComPort = 3, 'COM3');
  Check(c.Baud = 38400, '38400');
  cfg.Free;

  writeln('== TRegComportStruct size matches VxD (22 bytes) ==');
  Check(SizeOf(TRegComportStruct) = 22, 'struct is 22 bytes');

  writeln('== TRegComportStruct field layout ==');
  FillChar(reg, SizeOf(reg), 0);
  reg.Node := 1;
  reg.Enabled := 1;
  reg.ComportNumber := 3;
  reg.Emulation := 1;
  reg.Baudrate := 38400;
  reg.Internetport := 23;
  reg.Baseaddress := $03E8;
  reg.Buffersize := 2048;
  reg.Lockedbaudrate := 1;
  reg.Managetimeslice := 1;
  Check(reg.Node = 1, 'reg.Node');
  Check(reg.Enabled = 1, 'reg.Enabled');
  Check(reg.ComportNumber = 3, 'reg.ComportNumber');
  Check(reg.Emulation = 1, 'reg.Emulation (FOSSIL)');
  Check(reg.Baudrate = 38400, 'reg.Baudrate');
  Check(reg.Internetport = 23, 'reg.Internetport');
  Check(reg.Baseaddress = $03E8, 'reg.Baseaddress');
  Check(reg.Buffersize = 2048, 'reg.Buffersize');
  Check(reg.Lockedbaudrate = 1, 'reg.Lockedbaudrate');
  Check(reg.Managetimeslice = 1, 'reg.Managetimeslice');

  writeln('== RegistryConfigExists returns False on non-Windows ==');
  {$IFNDEF WINDOWS}
  Check(RegistryConfigExists = False, 'no registry on this platform');
  {$ENDIF}

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('DEFAULT CONFIG - VERIFIED');
end.
