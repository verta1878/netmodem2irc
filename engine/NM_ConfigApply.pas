unit NM_ConfigApply;
{ ===========================================================================
  netmodem2irc — apply a parsed config to a running server
  ---------------------------------------------------------------------------
  Closes the config story: NM_Config PARSES + VALIDATES config (tested); this
  unit APPLIES it — it walks the configured nodes and brings each one up on a
  TServerBridge, so "load a config -> nodes come up" is a real, tested path.

  Kept as its own unit (not folded into the bridge or the config) so each piece
  stays single-purpose and testable:
    NM_Config      : parse + validate text  -> a set of TNodeConfig
    NM_ServerBridge: construct + run nodes
    NM_ConfigApply : the thin glue between them (this unit)
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  NM_Node, NM_ServerBridge, NM_Config;

type
  { result of applying a config: how many nodes came up, and how many were
    skipped (e.g. no transport backend compiled in, or a slot failure). }
  TApplyResult = record
    Brought : Integer;   // nodes successfully brought up
    Skipped : Integer;   // configured nodes that could not be brought up
  end;

{ Apply a validated config to a bridge: bring up every configured node.
  Only applies when the config IsValid (refuses to act on a config that had parse
  errors — don't half-configure from broken input). Returns counts.
  Bringing a node "up" here means creating/activating its node slot on the bridge;
  the host/port from config travel with the node's link when a real transport is
  present. With no transport backend (stub build), nodes are counted as Skipped,
  not falsely reported up. }
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

  { refuse to apply a config that didn't parse cleanly — don't act on broken input }
  if not ACfg.IsValid then Exit;

  for i := 0 to ACfg.NodeCount - 1 do
  begin
    if not ACfg.NodeByPosition(i, nc) then Continue;
    { bring the node up on the bridge. OnConnectNode creates/activates the slot and
      returns the node (or nil if no transport backend / slot failure). }
    node := ABridge.OnConnectNode(nc.NodeIndex);
    if node <> nil then
      Inc(Result.Brought)
    else
      Inc(Result.Skipped);
  end;
end;

end.
