unit NM_ServerBridge;
{ ===========================================================================
  netmodem2irc — server bridge (M1 integration)
  ---------------------------------------------------------------------------
  Connects the TESTED emulation engine (NM_Node: TNodeManager) to the existing
  server GUI's CM_* message handlers and the driver's per-node IO.

  This is the piece that fills server/MainForm.pas's TODOs:
    CM_CONNECT_NODE      -> node goes online, open Telnet socket
    CM_DISCONNECT_NODE   -> node hung up, close socket
    CM_SEND_REMOTE_BREAK -> send Telnet BREAK
    CM_WILL/WONT_BINARY  -> Telnet BINARY negotiation

  Design: the GUI stays thin. It owns ONE TServerBridge. On each CM_* message it
  calls the matching bridge method with (NodeIndex). The bridge owns the
  TNodeManager (our tested multinode engine) and drives the sockets.

  The bridge is transport-agnostic via ISocketLink: it uses CreateSocketLink
  (Synapse, when built -dHAS_SYNAPSE) for real TCP. For inbound connections the
  driver hands us an accepted connection; for dial-out the AT layer dials.

  BUILD: uses only our engine units + the repo's driver interface. Compiles in
  stub form without Synapse; define -dHAS_SYNAPSE for real sockets.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils,
  NM_UART16550, NM_Fossil, NetTransport, NM_ATCommand, NM_Node
  {$IFDEF HAS_SYNAPSE}, NM_SynapseLink{$ENDIF};

type
  { Mirror of the driver's TIOStruct (common/NetModemVxD.pas). Kept here so the
    bridge is testable without the driver unit; the layouts MUST match.
    RX = bytes the DOS game wrote (-> send to socket).
    HX = buffer for bytes from the socket (-> give to the game). }
  TBridgeIO = packed record
    RXData     : PByte;   // bytes the game wrote (send to network)
    RXLength   : LongWord;
    HXData     : PByte;   // buffer to fill with bytes from network (to game)
    HXLength   : LongWord;
    Received   : Word;    // out: how many RX bytes we consumed
    HXFilled   : Word;    // out: how many HX bytes we produced
  end;

  { One bridge per server instance. Owns the multinode engine. }
  TServerBridge = class
  private
    FNodes: TNodeManager;
    FDefaultPort: Word;
    function MakeLink: ISocketLink;
  public
    constructor Create;
    destructor Destroy; override;

    { --- called from the GUI's CM_* handlers (pass node = Msg.WParam and $FF) --- }

    { CM_CONNECT_NODE: a node is going online. For an inbound call the driver has
      accepted a connection; we bring the node online and start Telnet. Returns
      the node so the caller can pump it, or nil on failure. }
    function OnConnectNode(NodeIndex: Integer): TNetModemNode;

    { CM_DISCONNECT_NODE: node hung up -> close its socket/transport. }
    procedure OnDisconnectNode(NodeIndex: Integer);

    { CM_SEND_REMOTE_BREAK: send a Telnet BREAK to the remote. }
    procedure OnSendRemoteBreak(NodeIndex: Integer);

    { CM_WILL_BINARY / CM_WONT_BINARY: drive Telnet BINARY negotiation. }
    procedure OnBinary(NodeIndex: Integer; AWill: Boolean);

    { --- data movement (call from the server's IO loop / timer) --- }

    { Pump every online node once (moves bytes socket<->rings). Call on a timer. }
    procedure PumpAll;

    { Service one node's byte IO (the driver's IOCTL_IO / TIOStruct path):
      feed RX bytes (game->wire) into the node, and fill HX (wire->game) from it.
      Returns True if the node exists. Sets AIo.Received / AIo.HXFilled. }
    function ServiceNodeIO(NodeIndex: Integer; var AIo: TBridgeIO): Boolean;

    { Direct TIOStruct servicing — the server passes the driver's raw fields and
      gets back the counts. No manual mapping needed in the GUI. RXPtr/HXPtr are
      the (possibly 32-bit) buffer pointers from TIOStruct.
      Returns True if the node exists; out params are the consumed/produced counts. }
    function ServiceDriverIO(NodeIndex: Integer;
                             RXPtr: Pointer; RXLen: LongWord;
                             HXPtr: Pointer; HXLen: LongWord;
                             out AReceived: Word; out AHXFilled: Word): Boolean;

    { A byte the guest (DOS door via the driver) wrote to node's COM/FOSSIL. }
    procedure GuestWrite(NodeIndex: Integer; B: Byte);
    { A byte to hand back to the guest; false if none available. }
    function  GuestRead(NodeIndex: Integer; out B: Byte): Boolean;

    { --- driver TIOStruct glue (the M1 byte data path) ---
      The GUI reads the driver's TIOStruct for a node and passes the two buffers
      here each IO tick:
        TXBuf/TXLen  = bytes the door WROTE (RXPointer/Received) -> to the wire
        RXBuf/RXMax  = buffer to FILL with bytes for the door (HXPointer/HXFree)
      Returns in RXCount how many bytes were placed into RXBuf. }
    procedure DriverIO(NodeIndex: Integer;
                       const TXBuf; TXLen: Integer;
                       var RXBuf; RXMax: Integer; out RXCount: Integer);

    property Nodes: TNodeManager read FNodes;
    property DefaultPort: Word read FDefaultPort write FDefaultPort;
  end;

implementation

constructor TServerBridge.Create;
begin
  inherited Create;
  FNodes := TNodeManager.Create;
  FDefaultPort := 23;   { Telnet }
end;

destructor TServerBridge.Destroy;
begin
  FNodes.Free;
  inherited Destroy;
end;

function TServerBridge.MakeLink: ISocketLink;
begin
  {$IFDEF HAS_SYNAPSE}
  Result := CreateSocketLink;     { real Synapse TCP socket }
  {$ELSE}
  Result := nil;                  { no socket backend compiled in }
  {$ENDIF}
end;

function TServerBridge.OnConnectNode(NodeIndex: Integer): TNetModemNode;
var
  link: ISocketLink;
  node: TNetModemNode;
begin
  Result := nil;
  { reuse an existing node slot or create one }
  node := FNodes.NodeByIndex(NodeIndex);
  if node = nil then
  begin
    link := MakeLink;
    if link = nil then Exit;      { no transport available (stub build) }
    node := FNodes.AddNode(NodeIndex, link);
    if node = nil then Exit;
  end;
  { inbound: the connection is established; bring the node online + start Telnet }
  node.ConnectInbound;
  Result := node;
end;

procedure TServerBridge.OnDisconnectNode(NodeIndex: Integer);
var node: TNetModemNode;
begin
  node := FNodes.NodeByIndex(NodeIndex);
  if node <> nil then
  begin
    node.Disconnect;
    FNodes.RemoveNode(NodeIndex);
  end;
end;

procedure TServerBridge.OnSendRemoteBreak(NodeIndex: Integer);
var node: TNetModemNode;
begin
  node := FNodes.NodeByIndex(NodeIndex);
  if node <> nil then node.SendBreak;
end;

procedure TServerBridge.OnBinary(NodeIndex: Integer; AWill: Boolean);
var node: TNetModemNode;
begin
  node := FNodes.NodeByIndex(NodeIndex);
  if node = nil then Exit;
  { WILL BINARY -> ensure binary negotiation is offered; WONT is informational.
    Our transport negotiates BINARY on connect; this lets the driver re-assert. }
  if AWill then
    node.ConnectInbound;   { ConnectInbound calls NegotiateBinary; safe to re-offer }
end;

procedure TServerBridge.PumpAll;
begin
  FNodes.PumpAll;
end;

procedure TServerBridge.GuestWrite(NodeIndex: Integer; B: Byte);
var node: TNetModemNode;
begin
  node := FNodes.NodeByIndex(NodeIndex);
  if node <> nil then node.GuestWrite(B);
end;

function TServerBridge.GuestRead(NodeIndex: Integer; out B: Byte): Boolean;
var node: TNetModemNode;
begin
  Result := False;
  node := FNodes.NodeByIndex(NodeIndex);
  if node <> nil then Result := node.GuestRead(B);
end;

procedure TServerBridge.DriverIO(NodeIndex: Integer;
                                 const TXBuf; TXLen: Integer;
                                 var RXBuf; RXMax: Integer; out RXCount: Integer);
var
  node: TNetModemNode;
  p: PByte;
  i: Integer;
  b: Byte;
begin
  RXCount := 0;
  node := FNodes.NodeByIndex(NodeIndex);
  if node = nil then Exit;

  { door -> wire: feed every byte the door wrote into the node }
  if TXLen > 0 then
  begin
    p := @TXBuf;
    for i := 0 to TXLen-1 do
      node.GuestWrite(p[i]);
  end;

  { move bytes across the socket both directions }
  node.Pump;

  { wire -> door: drain the node's RX into the door's read buffer }
  p := @RXBuf;
  while (RXCount < RXMax) and node.GuestRead(b) do
  begin
    p[RXCount] := b;
    Inc(RXCount);
  end;
end;

function TServerBridge.ServiceNodeIO(NodeIndex: Integer; var AIo: TBridgeIO): Boolean;
var
  node: TNetModemNode;
  i: LongWord;
  b: Byte;
begin
  AIo.Received := 0;
  AIo.HXFilled := 0;
  node := FNodes.NodeByIndex(NodeIndex);
  Result := node <> nil;
  if not Result then Exit;

  { RX: bytes the game wrote -> into the node (which routes to wire when online,
    or to the AT parser in command mode). }
  if (AIo.RXData <> nil) and (AIo.RXLength > 0) then
    for i := 0 to AIo.RXLength - 1 do
    begin
      node.GuestWrite((AIo.RXData + i)^);
      Inc(AIo.Received);
    end;

  { HX: fill the game's buffer with bytes that arrived from the wire. }
  if (AIo.HXData <> nil) and (AIo.HXLength > 0) then
    while (AIo.HXFilled < AIo.HXLength) and node.GuestRead(b) do
    begin
      (AIo.HXData + AIo.HXFilled)^ := b;
      Inc(AIo.HXFilled);
    end;
end;

function TServerBridge.ServiceDriverIO(NodeIndex: Integer;
                                       RXPtr: Pointer; RXLen: LongWord;
                                       HXPtr: Pointer; HXLen: LongWord;
                                       out AReceived: Word; out AHXFilled: Word): Boolean;
var
  io: TBridgeIO;
begin
  FillChar(io, SizeOf(io), 0);
  io.RXData   := PByte(RXPtr);
  io.RXLength := RXLen;
  io.HXData   := PByte(HXPtr);
  io.HXLength := HXLen;
  Result := ServiceNodeIO(NodeIndex, io);
  AReceived := io.Received;
  AHXFilled := io.HXFilled;
end;

end.
