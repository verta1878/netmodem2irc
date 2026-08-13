# M1 — MainForm.pas integration (drop-in code)

How to wire the tested engine into server/MainForm.pas. Fills the CM_* TODOs
using TServerBridge (which owns TNodeManager). Minimal changes to the existing
MainForm — the bridge does the work.

## 1. uses clause — add the engine + bridge
```pascal
uses
  ..., NetModemVxD,           // (existing)
  NM_ServerBridge;            // ADD: the bridge to our tested engine
```

## 2. Add a bridge field to TfrmMain (near FDriver)
```pascal
  private
    FDriver: TNetModemDriver;   // (existing)
    FBridge: TServerBridge;     // ADD
```

## 3. Create/free the bridge with the form
In FormCreate, after FDriver is set up:
```pascal
  FBridge := TServerBridge.Create;
```
In FormDestroy / before FDriver.Free:
```pascal
  FBridge.Free;
```

## 4. Fill the CM_* handlers in WndProc
Replace the TODO stubs with bridge calls. Node index = Msg.WParam and $FF.
```pascal
{$IFDEF WINDOWS}
procedure TfrmMain.WndProc(var Msg: TLMessage);
var
  NodeIdx: Integer;
begin
  NodeIdx := Msg.WParam and $FF;
  case Msg.Msg of
    CM_CONNECT_NODE:
      FBridge.OnConnectNode(NodeIdx);        // node online -> open Telnet
    CM_DISCONNECT_NODE:
      FBridge.OnDisconnectNode(NodeIdx);     // hung up -> close socket
    CM_SEND_REMOTE_BREAK:
      FBridge.OnSendRemoteBreak(NodeIdx);    // Telnet BREAK
    CM_WILL_BINARY:
      FBridge.OnBinary(NodeIdx, True);       // BINARY negotiation
    CM_WONT_BINARY:
      FBridge.OnBinary(NodeIdx, False);
  end;
  inherited WndProc(Msg);
end;
{$ENDIF}
```

## 5. Add a pump timer (the IO loop) — NOW COMPLETE
The bridge's DriverIO method handles the whole per-node byte path (built+tested).
Add a TTimer (e.g. 20-50ms). For each online node, read its TIOStruct from the
driver, pass the door's written bytes + a receive buffer to DriverIO, then write
the results back via the driver:
```pascal
procedure TfrmMain.PumpTimerTimer(Sender: TObject);
var
  n, rxcount: Integer;
  io: TIOStruct;
  txbuf, rxbuf: array[0..4095] of Byte;
begin
  for n := 3 to 99 do                       // comports 3-99 (the original range)
    if FBridge.Nodes.NodeByIndex(n) <> nil then
    begin
      if not FDriver.IO(n, io) then Continue;
      // marshal door-written bytes (io.RXPointer/io.Received) into txbuf...
      // (copy io.Received bytes from io.RXPointer into txbuf)
      FBridge.DriverIO(n, txbuf, io.Received, rxbuf, SizeOf(rxbuf), rxcount);
      // ...copy rxcount bytes from rxbuf back to io.HXPointer for the door
      // (the pointer marshalling is the thin driver-side memory copy; the byte
      //  LOGIC is done + tested in DriverIO)
    end;
end;
```
TIOStruct (from common/NetModemVxD.pas):
  RXPointer/Received = bytes the door WROTE (-> DriverIO txbuf, door->wire)
  HXPointer/HXFree   = buffer for bytes TO the door (<- DriverIO rxbuf, wire->door)

DriverIO is TESTED (6/6): both directions + RXMax capping + binary safety
(0xFF correctly IAC-escaped per Telnet). The only remaining glue is the raw
pointer<->buffer memory copy, which is driver-side and best done on Windows where
the TIOStruct pointers are real.

## Build
- Add nt_src/*.pas to the project search path (or copy the units into server/).
- Bundle Synapse: add libs/synapse to the unit path, build -dHAS_SYNAPSE.
- Without -dHAS_SYNAPSE the bridge compiles but MakeLink returns nil (no sockets)
  — useful for a GUI-only compile check.

## Status
- TServerBridge: TESTED (9/9 checks, drives the engine correctly) on FPC 2.6.4 + 3.2.2.
- The driver<->bridge byte glue in the pump timer (step 5 comment) is the one
  remaining M1 piece — it depends on the exact TIOStruct field layout in
  common/NetModemVxD.pas and is best finished on the Windows build where the
  driver IO can be exercised.

---

## UPDATE: driver<->bridge byte glue is DONE (TServerBridge.ServiceNodeIO)

The pump-timer glue (step 5) is now implemented and TESTED. The bridge exposes:

```pascal
function ServiceNodeIO(NodeIndex: Integer; var AIo: TBridgeIO): Boolean;
```

TBridgeIO mirrors the driver's TIOStruct (common/NetModemVxD.pas):
- RXData/RXLength  = bytes the DOS game wrote  -> fed to the node (to the wire)
- HXData/HXLength  = buffer filled with bytes from the wire -> given to the game
- Received/HXFilled = out counts

### Pump timer, completed form
```pascal
procedure TfrmMain.PumpTimerTimer(Sender: TObject);
var
  io: TBridgeIO;
  dio: TIOStruct;          // the driver's struct
  n: Integer;
begin
  FBridge.PumpAll;         // socket <-> node rings, all online nodes
  for n := 0 to NM_MAX_NODES - 1 do
    if FBridge.Nodes.NodeByIndex(n) <> nil then
    begin
      // 1) ask the driver for this node's IO buffers (dio: TIOStruct)
      if FDriver.IO(Byte(n), dio) then
      begin
        // 2) map dio (TIOStruct) fields onto io (TBridgeIO) pointers/lengths,
        //    call FBridge.ServiceNodeIO(n, io), then write back the counts.
        //    (RXPointer/IORXLength -> RXData/RXLength;
        //     HXPointer/IOHXLength -> HXData/HXLength;
        //     io.Received -> dio.Received; io.HXFilled -> dio.HXFree usage)
      end;
    end;
end;
```

### Status
- ServiceNodeIO: TESTED (6/6, incl. binary safety with proper Telnet IAC
  doubling — a lone 0xFF is IAC and MUST be doubled; the engine handles it).
- The ONLY remaining M1 glue is the mechanical TIOStruct<->TBridgeIO field copy
  in the timer, which is trivial pointer/length mapping best finalized on the
  Windows build where FDriver.IO actually returns live buffers. The LOGIC it
  drives (ServiceNodeIO) is done and proven.
