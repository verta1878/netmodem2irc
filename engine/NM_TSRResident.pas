unit NM_TSRResident;
{ ===========================================================================
  netmodem2irc — TSR residency scaffold (i8086 real-mode) — DESIGN STAGE
  ---------------------------------------------------------------------------
  *** DESIGN-STAGE SCAFFOLD. REASONED, NOT PROVEN. ***
  Cannot be compiled/tested for real until the fpc264irc i8086 backend exists.
  The host build compiles (DOS-specific parts guarded out).

  WHAT THIS IS
  "TSR" = Terminate and Stay Resident. A DOS program that installs its interrupt
  handler, then EXITS but leaves its code in memory so the handler keeps running.
  This unit is the residency layer that:
    - INSTALL: reads NM_Config, brings up each configured node on the switch
      (via NM_ConfigApply), registers each node's resident UART with the ISR
      (NM_Int14ISR.SetResidentUart), hooks INT 14h, and goes resident.
    - PUMP: while resident, services the seam link both directions (the tested
      NM_TSR core does this per node; here it's driven for all configured nodes).
    - UNLOAD: restores the INT 14h vector and frees memory.

  THE SWITCH-SHAPED SYSTEM (as the maintainer described)
    Each served comport is a thin ISR on-ramp (NM_Int14ISR) feeding node state;
    the SWITCH (TNodeManager, already built + tested) routes among ACTIVE nodes;
    each node has a TServerLink (NM_ServerLink, already built + tested). This unit
    wires those existing, tested pieces together at install time from NM_Config.
    The ISR stays thin; the switch does the multi-node routing.

  CONFIG FLOW (CPL writes NM_Config; this reads it)
    CPL (GUI, M2) -> writes NM_Config file
                  -> NM_Config parses/validates (tested)
                  -> NM_ConfigApply brings up nodes on the switch (tested)
                  -> this unit registers each node's UART with the ISR + hooks INT 14h
    The CPL never touches this unit or the ISR — it only writes NM_Config.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  NM_UART16550, NM_Node, NM_Config, NM_ConfigApply, NM_ServerBridge,
  NM_Int14ISR;

type
  { Residency state — one per running TSR instance (the whole driver). }
  TTSRResident = class
  private
    FBridge : TServerBridge;     { hosts the switch (TNodeManager) + nodes }
    FConfig : TNMConfig;   { the loaded per-node config }
    FResident : Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    { INSTALL: load+apply config, register resident UARTs with the ISR, hook INT
      14h, mark resident. Returns count of nodes brought up.
      DESIGN NOTE (i8086 fill-in): after hooking, a real TSR calls the DOS
      Keep/TSR service (INT 21h/31h or Turbo Pascal's Keep) to terminate-stay-
      resident. That final Keep call is the one real-mode-specific step here. }
    function Install(const AConfigText: string): Integer;

    { PUMP: service all resident nodes' seam links both ways. Called from the
      resident context (e.g. a timer/idle hook, or the pump loop). Delegates to
      the tested per-node NM_TSR logic via the bridge's nodes. }
    procedure Pump;

    { UNLOAD: restore INT 14h, free resources, clear resident flag. }
    procedure Unload;

    property Resident: Boolean read FResident;
    property Bridge: TServerBridge read FBridge;
  end;

implementation

constructor TTSRResident.Create;
begin
  inherited Create;
  FBridge := TServerBridge.Create;
  FConfig := TNMConfig.Create;
  FResident := False;
end;

destructor TTSRResident.Destroy;
begin
  if FResident then Unload;
  FConfig.Free;
  FBridge.Free;
  inherited Destroy;
end;

function TTSRResident.Install(const AConfigText: string): Integer;
var
  applied: TApplyResult;
  i: Integer;
  nc: TNodeConfig;
  node: TNetModemNode;
begin
  Result := 0;

  { 1. parse + validate config (tested). Refuse to install a broken config. }
  FConfig.ParseText(AConfigText);
  if not FConfig.IsValid then Exit;

  { 2. bring up configured nodes on the switch (tested NM_ConfigApply). }
  applied := ApplyConfig(FConfig, FBridge);
  Result := applied.Brought;

  { 3. register each configured node's resident UART with the ISR, so an INT 14h
       for that port dispatches on the right UART. The bridge/switch owns the
       node objects; we hand the ISR a pointer to each node's UART. }
  for i := 0 to FConfig.NodeCount - 1 do
    if FConfig.NodeByPosition(i, nc) then
    begin
      node := FBridge.Nodes.NodeByIndex(nc.NodeIndex);
      if node <> nil then
        SetResidentUart(nc.NodeIndex, node.UartPtr);
    end;

  { 4. hook INT 14h (real vector on DOS; no-op on host). }
  InstallInt14;

  { 5. go resident. DESIGN NOTE (i8086 fill-in): the real TSR terminate-stay-
       resident call goes here (Keep / INT 21h fn 31h) on the DOS build. On the
       host there is nothing to keep. }
  {$IFDEF DOS_TARGET}
  { Keep(0);  -- terminate and stay resident, keeping our code+ISR in memory }
  {$ENDIF}

  FResident := True;
end;

procedure TTSRResident.Pump;
begin
  { Service every active node's seam link both directions. The SWITCH services
    only active nodes (the efficient path). Per-node pumping uses the tested
    NM_TSR / bridge logic. Design-stage: the concrete per-node pump wiring is
    filled in alongside the real TServerLink instances at i8086 time. }
  if not FResident then Exit;
  { for each active node: node.PumpSeam;  (delegates to tested NM_TSR core) }
end;

procedure TTSRResident.Unload;
begin
  if not FResident then Exit;
  RemoveInt14;             { restore the INT 14h vector (tested no-op on host) }
  FResident := False;
end;

end.
