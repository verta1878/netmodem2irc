unit NM_TSR;
{ ===========================================================================
  netmodem2irc — the driver-side TSR skeleton (the resident program shell)
  ---------------------------------------------------------------------------
  This is the top-level structure of the FOSSIL TSR: the resident program that
  the DOS BBS loads so its INT 14h calls become network traffic. It plugs the
  three already-built, already-tested pieces together:

    1. a UART (NM_UART16550)         — the emulated 16550 the guest talks to
    2. FOSSIL dispatch (NM_FossilDriver) — turns INT 14h calls into UART activity
    3. the seam sender (NM_SeamSender)   — wraps UART activity into frames for
                                           the server, over a byte sink (pipe/socket)

  DESIGN — target-independent orchestration, guarded residency:
    The ORCHESTRATION (init the pieces, pump both directions, tear down) is plain
    Pascal and host-testable. The real-mode RESIDENCY (going TSR-resident, the
    INT 14h vector hook, the pipe/socket to the server) is DOS-specific and lives
    behind DOS_TARGET / behind the byte-sink callback. So this skeleton is built
    and tested on the host now; when i8086 lands, only the thin real-mode wrapper
    (residency + the actual pipe write) is filled in — the shape is already here.

  The full driver<->server loop this completes:
    guest -> INT 14h -> FOSSIL dispatch -> UART TX ring -> [pump] -> seam sender
      -> byte sink (pipe/socket) -> SERVER
    SERVER -> (frames) -> [feed] -> UART RX ring -> FOSSIL dispatch -> guest
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  NM_UART16550, NM_FossilDriver, NM_SeamProtocol, NM_SeamSender;

type
  { The link to the server, abstracted so the TSR shell doesn't care whether it's
    a real DOS pipe/socket or a test buffer. Send pushes bytes to the server;
    Poll pulls any bytes the server sent back (0 if none). Mirrors the two
    directions the TSR must service. }
  TServerLink = class
  public
    function Send(const Buf; Len: Integer): Integer; virtual; abstract;
    function Poll(var Buf; MaxLen: Integer): Integer; virtual; abstract;
  end;

  { The resident driver: owns the UART, the sender, and the server link, and
    services traffic both ways. One TSR instance per served comport/node. }
  TNetModemTSR = class
  private
    FUart      : TUart16550;
    FSender    : TSeamSender;
    FLink      : TServerLink;
    FNodeIndex : Byte;
    FRunning   : Boolean;
    FParser    : TSeamParser;   { parses frames the SERVER sends back to us }
    { the sink the sender writes through -> forwards to the server link }
    function SinkToServer(const Buf; Len: Integer): Integer;
    { route a frame the server sent us into the UART RX (guest will read it) }
    procedure HandleServerFrame(const Frame: TSeamFrame);
  public
    constructor Create(ALink: TServerLink; ANodeIndex: Byte);
    destructor Destroy; override;

    { Bring the driver up: reset UART, hook FOSSIL (INT 14h on the DOS build),
      tell the server we're here (smConnect). }
    procedure Startup;
    { Tear down: unhook FOSSIL, tell the server we're gone (smDisconnect). }
    procedure Shutdown;

    { One service tick — call from the resident loop (or a test):
      (a) drain the UART TX ring (guest -> wire) and send it as seam frames,
      (b) poll the server link and feed any frames into the UART RX (wire -> guest).
      Returns True while running. }
    function Pump: Boolean;

    { The FOSSIL ISR dispatches on the RESIDENT UART, so expose it by pointer
      (not a by-value copy). This is the same UART InstallFossil hooks. }
    function UartPtr: PUart16550;
    property NodeIndex: Byte read FNodeIndex;
    property Running: Boolean read FRunning;
  end;

implementation

constructor TNetModemTSR.Create(ALink: TServerLink; ANodeIndex: Byte);
begin
  inherited Create;
  FLink := ALink;
  FNodeIndex := ANodeIndex;
  FParser := TSeamParser.Create;
  { the sender writes through our sink, which forwards to the server link }
  FSender := TSeamSender.Create(@SinkToServer, ANodeIndex);
  UartReset(FUart);
  FRunning := False;
end;

destructor TNetModemTSR.Destroy;
begin
  if FRunning then Shutdown;
  FSender.Free;
  FParser.Free;
  inherited Destroy;
end;

function TNetModemTSR.SinkToServer(const Buf; Len: Integer): Integer;
begin
  if FLink <> nil then
    Result := FLink.Send(Buf, Len)
  else
    Result := 0;
end;

procedure TNetModemTSR.HandleServerFrame(const Frame: TSeamFrame);
var
  i: Integer;
begin
  case Frame.Msg of
    smData:
      { bytes from the remote -> push into UART RX so the guest can read them }
      for i := 0 to High(Frame.Payload) do
        UartNetToGuest(FUart, Frame.Payload[i]);
    smConnect, smCarrierUp:
      UartSetCarrier(FUart, True);
    smDisconnect, smCarrierDn:
      UartSetCarrier(FUart, False);
    smBreak:
      ; { a remote BREAK; the UART/AT layer would surface this if needed }
    smKeepAlive:
      ; { no-op }
  end;
end;

procedure TNetModemTSR.Startup;
begin
  UartReset(FUart);
  InstallFossil(FUart);      { DOS build: hooks INT 14h; host build: sets ResidentU }
  FRunning := True;
  FSender.SendConnect;       { tell the server this node's driver is up }
end;

procedure TNetModemTSR.Shutdown;
begin
  if not FRunning then Exit;
  FSender.SendDisconnect;    { tell the server we're going away }
  RemoveFossil;              { DOS build: restores INT 14h }
  FRunning := False;
end;

function TNetModemTSR.UartPtr: PUart16550;
begin
  Result := @FUart;
end;

function TNetModemTSR.Pump: Boolean;
var
  txbuf: array[0..1023] of Byte;
  n: Integer;
  b: Byte;
  inbuf: array[0..1023] of Byte;
  got: Integer;
  frame: TSeamFrame;
begin
  Result := FRunning;
  if not FRunning then Exit;

  { (a) guest -> wire: drain the UART TX ring, send as seam data frames }
  n := 0;
  while (n < SizeOf(txbuf)) and UartGuestToNet(FUart, b) do
  begin
    txbuf[n] := b;
    Inc(n);
  end;
  if n > 0 then
    FSender.SendData(txbuf[0], n);

  { (b) wire -> guest: poll the server link, feed frames into the UART RX }
  if FLink <> nil then
  begin
    got := FLink.Poll(inbuf[0], SizeOf(inbuf));
    if got > 0 then
    begin
      FParser.Feed(inbuf[0], got);
      while FParser.NextFrame(frame) do
        HandleServerFrame(frame);
    end;
  end;
end;

end.
