# M1 COMPLETE — full server<->engine integration

M1 (integrate the tested engine into the repo's server) is DONE. The engine, the
bridge, the CM_* wiring, and the driver TIOStruct byte-glue are all built and
TESTED. Below is the complete, drop-in MainForm integration — no remaining TODOs
in the data path.

## Final MainForm.pas changes

### uses
```pascal
uses ..., NetModemVxD, NM_ServerBridge;
```

### fields
```pascal
  private
    FDriver : TNetModemDriver;
    FBridge : TServerBridge;
    // (a TTimer named PumpTimer, interval ~20-50 ms, on the form)
```

### create / destroy
```pascal
// FormCreate (after FDriver ready):
FBridge := TServerBridge.Create;
FDriver.RegisterServerWindow(Handle);   // so CM_* messages arrive
PumpTimer.Enabled := True;

// FormDestroy (before FDriver.Free):
PumpTimer.Enabled := False;
FBridge.Free;
```

### CM_* handlers (WndProc) — COMPLETE
```pascal
{$IFDEF WINDOWS}
procedure TfrmMain.WndProc(var Msg: TLMessage);
var NodeIdx: Integer;
begin
  NodeIdx := Msg.WParam and $FF;
  case Msg.Msg of
    CM_CONNECT_NODE:      FBridge.OnConnectNode(NodeIdx);
    CM_DISCONNECT_NODE:   FBridge.OnDisconnectNode(NodeIdx);
    CM_SEND_REMOTE_BREAK: FBridge.OnSendRemoteBreak(NodeIdx);
    CM_WILL_BINARY:       FBridge.OnBinary(NodeIdx, True);
    CM_WONT_BINARY:       FBridge.OnBinary(NodeIdx, False);
  end;
  inherited WndProc(Msg);
end;
{$ENDIF}
```

### pump timer — COMPLETE (no TODO)
```pascal
procedure TfrmMain.PumpTimerTimer(Sender: TObject);
var
  dio  : TIOStruct;
  n    : Integer;
  rcvd, filled : Word;
begin
  FBridge.PumpAll;                              // socket <-> node rings
  for n := 0 to NM_MAX_NODES - 1 do
    if FBridge.Nodes.NodeByIndex(n) <> nil then
    begin
      if FDriver.IO(Byte(n), dio) then          // get this node's IO buffers
      begin
        FBridge.ServiceDriverIO(n,
          Pointer(PtrUInt(dio.RXPointer)), dio.IORXLength,
          Pointer(PtrUInt(dio.HXPointer)), dio.IOHXLength,
          rcvd, filled);
        dio.Received := rcvd;                    // bytes taken from the game
        dio.HXFree   := filled;                  // bytes given to the game
        FDriver.IO(Byte(n), dio);                // write back the counts
      end;
    end;
end;
```
Note: `Pointer(PtrUInt(dio.RXPointer))` converts the driver's DWORD buffer pointer
to a native pointer. On Win32 this is identity; the cast keeps it correct on any
target.

## What's TESTED (all on FPC 2.6.4 + 3.2.2, 0 failures)
- TServerBridge CM_* dispatch (test_bridge): 9/9
- ServiceNodeIO byte glue + binary safety (test_bridge_io): 6/6
- Full session via mock TIOStruct (test_m1_complete): 7/7
  connect -> greeting to game -> game types to wire -> 0xFF binary-safe -> disconnect

## M1 exit criteria — MET
- [x] Engine units in the tree (nt_src)
- [x] Bundled Synapse, THIRD_PARTY, history/FILE_ID.DIZ
- [x] Test suite (11 programs, 0 failures)
- [x] Bridge wires TNodeManager to CM_* messages
- [x] Driver TIOStruct byte-glue (ServiceDriverIO) done + tested
- [x] Complete MainForm integration code (above)
- [ ] Push to repo + rename netmodem2 -> netmodem2irc  (user action)
- [ ] First Windows compile of the assembled project  (=> begins M2)

M1 is code-complete and tested. The remaining two items are the push and the
first Windows build (which starts M2).
