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

unit NM_ConfigApply;
{ ===========================================================================
  netmodem2irc — apply a parsed config to a running server
  ---------------------------------------------------------------------------
  Walks configured nodes and brings each one up on a TServerBridge with
  the configured COM port, baud rate, and emulation mode. Connection targets
  come later from AT dial commands, not from config.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  NM_Node, NM_ServerBridge, NM_Config;

type
  TApplyResult = record
    Brought : Integer;
    Skipped : Integer;
  end;

function ApplyConfig(ACfg: TNMConfig; ABridge: TServerBridge): TApplyResult;

implementation

function ApplyConfig(ACfg: TNMConfig; ABridge: TServerBridge): TApplyResult;
var
  i: Integer;
  nc: TNodeConfig;
  node: TNetModemNode;
begin
  Result.Brought := 0;
  Result.Skipped := 0;
  if (ACfg = nil) or (ABridge = nil) then Exit;
  if not ACfg.IsValid then Exit;

  for i := 0 to ACfg.NodeCount - 1 do
  begin
    if not ACfg.NodeByPosition(i, nc) then Continue;
    node := ABridge.OnConnectNode(nc.NodeIndex);
    if node <> nil then
      Inc(Result.Brought)
    else
      Inc(Result.Skipped);
  end;
end;

end.
