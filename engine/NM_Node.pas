unit NM_Node;
{ ===========================================================================
  netmodem2irc — per-node virtual modem (NT-branch)
  ---------------------------------------------------------------------------
  Ties the emulation layers into ONE object per connection/node:
     UART (NM_UART16550) + FOSSIL (NM_Fossil) + AT (NM_ATCommand)
     bound to a transport (NetTransport) over a socket link (ISocketLink).

  This is the object the server drives. The server posts CM_* messages
  (CM_CONNECT_NODE, CM_DISCONNECT_NODE, CM_SEND_REMOTE_BREAK, CM_WILL_BINARY)
  per node; this unit provides the matching methods.

  MULTINODE BY DESIGN (honoring the original — FILE_ID.DIZ: "Multinode versions
  are now available", "Comports 3-99"): every layer keeps its state in the node
  object, no globals. TNodeManager holds an array of nodes so the server can run
  many simultaneous connections, exactly as Dedrick's original did. Single node
  works today; more nodes is just a larger array.

  Data flow per pump:
    guest writes (THR / FOSSIL TX)  -> UART.TX -> transport -> socket
    socket -> transport (Telnet filt) -> UART.RX -> guest reads (RBR / FOSSIL RX)
    in command mode, guest bytes are routed to the AT parser instead of the wire
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand;

const
  { comports 3-99 in the original => up to 97 nodes. Cap generously. }
  NM_MAX_NODES = 99;

type
  TNodeState = (nsIdle, nsOnline, nsHungUp);

  { One virtual modem / node. }
  TNetModemNode = class
  private
    FIndex : Integer;           // node/comport number
    FUart  : TUart16550;
    FTrans : TNetTransport;
    FModem : TATModem;
    FLink  : ISocketLink;
    FManager: TObject;   { back-ref for switch self-activation (TNodeManager) }
    FState : TNodeState;
    function GetOnline: Boolean;
  public
    constructor Create(AIndex: Integer; ALink: ISocketLink);
    destructor Destroy; override;

    { --- server-driven events (map to the CM_* messages) --- }
    { CM_CONNECT_NODE: for an INBOUND connection the server already has a socket;
      it hands us the link and we mark online + set carrier. }
    procedure ConnectInbound;
    { CM_DISCONNECT_NODE }
    procedure Disconnect;
    { CM_SEND_REMOTE_BREAK }
    procedure SendBreak;

    { --- guest side (what the virtual COM / FOSSIL shim calls) --- }
    { A byte the guest wrote (THR or FOSSIL TX). In command mode it goes to the
      AT parser; online it goes to the UART TX ring for the wire. }
    procedure GuestWrite(B: Byte);
    { Read a byte for the guest (RBR / FOSSIL RX); returns false if none. }
    function  GuestRead(out B: Byte): Boolean;
    { FOSSIL INT 14h dispatch for this node. }
    procedure Fossil(var R: TFossilRegs);

    { --- pump: move bytes between rings and socket. Call each server tick. --- }
    { Returns false if the link dropped (carrier lost). }
    function Pump: Boolean;

    property Index: Integer read FIndex;
    property State: TNodeState read FState;
    property Online: Boolean read GetOnline;
    property Uart: TUart16550 read FUart;   // for the virtual-COM register bridge
    { The ISR must dispatch on the RESIDENT UART (not a by-value copy), so expose
      it by pointer — same reason NM_TSR exposes UartPtr. }
    function UartPtr: PUart16550;
    property Modem: TATModem read FModem;
    property Manager: TObject read FManager write FManager;
  end;

  { Holds many nodes — the multinode server core. }
  { Switch-style routing: instead of sweeping all NM_MAX_NODES slots each tick
    (hub behavior — cost scales with total slots), the manager keeps a compact
    list of ACTIVE (online) nodes and services only those (cost scales with
    active traffic). AddNode/Disconnect keep the active list in sync. }
  TNodeManager = class
  private
    FNodes: array[0..NM_MAX_NODES-1] of TNetModemNode;
    FActive: array[0..NM_MAX_NODES-1] of TNetModemNode;  { switch: live nodes only }
    FActiveCount: Integer;
    FCount: Integer;
    procedure AddActive(N: TNetModemNode);
    procedure RemoveActive(N: TNetModemNode);
  public
    constructor Create;
    destructor Destroy; override;
    { Create a node at a comport index with a given socket link. }
    function AddNode(AIndex: Integer; ALink: ISocketLink): TNetModemNode;
    function NodeByIndex(AIndex: Integer): TNetModemNode;
    procedure RemoveNode(AIndex: Integer);
    { Pump every active node once (the server's main tick). }
    procedure PumpAll;
    procedure MarkActive(AIndex: Integer);   { switch: note a node as live }
    property ActiveCount: Integer read FActiveCount;   { live-node count (switch) }
    property Count: Integer read FCount;
  end;

implementation

{ ---------------- TNetModemNode ---------------- }

constructor TNetModemNode.Create(AIndex: Integer; ALink: ISocketLink);
begin
  inherited Create;
  FIndex := AIndex;
  FLink  := ALink;
  UartReset(FUart);
  FTrans := TNetTransport.Create(@FUart, FLink);
  FModem := TATModem.Create(@FUart, FTrans);
  FState := nsIdle;
end;

destructor TNetModemNode.Destroy;
begin
  FModem.Free;
  FTrans.Free;
  FLink := nil;            // interface ref released
  inherited Destroy;
end;

function TNetModemNode.GetOnline: Boolean;
begin
  Result := FUart.Online;
end;

function TNetModemNode.UartPtr: PUart16550;
begin
  Result := @FUart;
end;

procedure TNetModemNode.ConnectInbound;
begin
  { Inbound: caller (server) accepted a socket into FLink. Raise carrier so the
    BBS/door sees a call. The transport still handles Telnet negotiation on pump. }
  UartSetCarrier(FUart, True);
  FState := nsOnline;
  if FManager <> nil then
    TNodeManager(FManager).MarkActive(FIndex);   { switch: auto-activate on connect }
  FModem.ForceOnline;   { inbound: already connected, go straight to online mode }
  { proactively offer BINARY so 8-bit data is clean from the start }
  FTrans.NegotiateBinary;
end;

procedure TNetModemNode.Disconnect;
begin
  FTrans.HangUp;
  FState := nsHungUp;
end;

procedure TNetModemNode.SendBreak;
begin
  FTrans.SendBreak;
end;

procedure TNetModemNode.GuestWrite(B: Byte);
begin
  if FModem.Mode = mmCommand then
    FModem.ATFeed(B)         // AT command parsing
  else
    UartWriteReg(FUart, UART_THR, B);   // online: byte to the wire
end;

function TNetModemNode.GuestRead(out B: Byte): Boolean;
begin
  Result := False;
  if FUart.RX.Count > 0 then
  begin
    B := UartReadReg(FUart, UART_RBR);
    Result := True;
  end;
end;

procedure TNetModemNode.Fossil(var R: TFossilRegs);
begin
  FossilDispatch(FUart, R);
end;

function TNetModemNode.Pump: Boolean;
begin
  Result := FTrans.Pump;
  if not Result then
    FState := nsHungUp;
end;

{ ---------------- TNodeManager ---------------- }

constructor TNodeManager.Create;
var i: Integer;
begin
  inherited Create;
  for i := 0 to NM_MAX_NODES-1 do FNodes[i] := nil;
  FCount := 0;
end;

destructor TNodeManager.Destroy;
var i: Integer;
begin
  FActiveCount := 0;   { SWITCH SAFETY: clear active list before freeing nodes }
  for i := 0 to NM_MAX_NODES-1 do
    if FNodes[i] <> nil then FNodes[i].Free;
  inherited Destroy;
end;

function TNodeManager.AddNode(AIndex: Integer; ALink: ISocketLink): TNetModemNode;
begin
  Result := nil;
  if (AIndex < 0) or (AIndex >= NM_MAX_NODES) then Exit;
  if FNodes[AIndex] <> nil then
  begin
    RemoveActive(FNodes[AIndex]);   { SWITCH SAFETY: purge dangling ref before free }
    FNodes[AIndex].Free;
  end;
  FNodes[AIndex] := TNetModemNode.Create(AIndex, ALink);
  Inc(FCount);
  Result := FNodes[AIndex];
  if Result <> nil then Result.Manager := Self;
end;

function TNodeManager.NodeByIndex(AIndex: Integer): TNetModemNode;
begin
  if (AIndex >= 0) and (AIndex < NM_MAX_NODES) then
    Result := FNodes[AIndex]
  else
    Result := nil;
end;

procedure TNodeManager.RemoveNode(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < NM_MAX_NODES) and (FNodes[AIndex] <> nil) then
  begin
    RemoveActive(FNodes[AIndex]);   { SWITCH SAFETY: drop from active list BEFORE
                                      freeing, so PumpAll never derefs freed memory }
    FNodes[AIndex].Free;
    FNodes[AIndex] := nil;
    Dec(FCount);
  end;
end;

procedure TNodeManager.AddActive(N: TNetModemNode);
var i: Integer;
begin
  for i := 0 to FActiveCount-1 do
    if FActive[i] = N then Exit;          { already active }
  if FActiveCount < NM_MAX_NODES then
  begin
    FActive[FActiveCount] := N;
    Inc(FActiveCount);
  end;
end;

procedure TNodeManager.RemoveActive(N: TNetModemNode);
var i, j: Integer;
begin
  for i := 0 to FActiveCount-1 do
    if FActive[i] = N then
    begin
      for j := i to FActiveCount-2 do
        FActive[j] := FActive[j+1];       { compact — no holes }
      Dec(FActiveCount);
      Exit;
    end;
end;

procedure TNodeManager.MarkActive(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < NM_MAX_NODES) and (FNodes[AIndex] <> nil) then
    AddActive(FNodes[AIndex]);
end;

{ SWITCH: service only the active (live) nodes. A node that hangs up is dropped
  from the active list so idle/dead slots cost nothing. Cost scales with the
  number of LIVE connections, not the 99-slot capacity. }
procedure TNodeManager.PumpAll;
var i: Integer; n: TNetModemNode;
begin
  i := 0;
  while i < FActiveCount do
  begin
    n := FActive[i];
    if (n <> nil) and (n.State = nsOnline) then
    begin
      n.Pump;
      Inc(i);
    end
    else
      RemoveActive(n);   { drop dead/offline node; do NOT advance i (compacted) }
  end;
end;

end.
