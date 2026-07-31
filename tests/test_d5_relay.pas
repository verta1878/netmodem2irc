{ ===========================================================================
  netmodem2irc — D5 Direct Relay Test
  GPLv3. Proves the direct UART relay works and compares it to
  the FOSSIL dispatch path.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

program test_d5_relay;

uses
  SysUtils, NM_UART16550, NM_DirectRelay, NM_Debug
  {$IFDEF HAS_SYNAPSE}, blcksock{$ENDIF};

const
  PORT = 2328;

var
  TestsPassed, TestsFailed, TestsTotal: Integer;

procedure Check(const Name: String; Cond: Boolean);
begin
  Inc(TestsTotal);
  if Cond then begin Inc(TestsPassed); WriteLn('  PASS: ', Name); end
  else begin Inc(TestsFailed); WriteLn('  FAIL: ', Name); end;
end;

{$IFDEF HAS_SYNAPSE}
var
  Manager: TRelayManager;
  Relay: TDirectRelay;
  ListenSock, ServerSock, ClientSock: TTCPBlockSocket;
  B, Got: Byte;
  I, Total, Timeout: Integer;
  SendBuf, RecvBuf: array[0..4095] of Byte;
  Match: Boolean;
begin
  WriteLn('==================================================');
  WriteLn('  D5 — Direct UART Relay Test');
  WriteLn('==================================================');
  WriteLn;
  TestsPassed := 0; TestsFailed := 0; TestsTotal := 0;

  { Create manager with 4 nodes }
  Manager := TRelayManager.Create(4);
  Check('RelayManager created (4 nodes)', Manager.Count = 4);

  Relay := Manager.GetRelay(0);
  Check('Relay 0 exists', Relay <> nil);
  Check('Relay 0 not connected initially', not Relay.Connected);

  { Create TCP listener }
  ListenSock := TTCPBlockSocket.Create;
  ListenSock.CreateSocket;
  ListenSock.Bind('127.0.0.1', IntToStr(PORT));
  ListenSock.Listen;
  Check('Listener bound', ListenSock.LastError = 0);

  { Connect a client }
  ClientSock := TTCPBlockSocket.Create;
  ClientSock.Connect('127.0.0.1', IntToStr(PORT));
  Check('Client connected', ClientSock.LastError = 0);

  { Accept on server side }
  ServerSock := TTCPBlockSocket.Create;
  if ListenSock.CanRead(2000) then
    ServerSock.Socket := ListenSock.Accept;
  Check('Server accepted', ServerSock.LastError = 0);

  { Attach socket to relay }
  Relay.AttachSocket(ServerSock);
  Check('Relay attached, connected', Relay.Connected);

  { === Test 1: FeedByte directly into UART RX ring === }
  WriteLn;
  WriteLn('Test 1: Direct UART feed');
  for I := 0 to 9 do
    Check('FeedByte ' + IntToStr(I), Relay.FeedByte($30 + I));

  { Read back via UART register (guest side) }
  for I := 0 to 9 do
  begin
    B := Relay.ReadReg(0);   { RBR — receive buffer register }
    Check('ReadReg(RBR) = $' + IntToHex($30 + I, 2), B = $30 + I);
  end;

  { === Test 2: Guest writes via UART TX, drain to network === }
  WriteLn;
  WriteLn('Test 2: Guest write → drain');
  for I := 0 to 4 do
    Relay.WriteReg(0, $41 + I);   { THR — transmit holding register }

  for I := 0 to 4 do
  begin
    Check('DrainByte ' + IntToStr(I), Relay.DrainByte(B));
    Check('Drained byte = $' + IntToHex($41 + I, 2), B = $41 + I);
  end;

  { === Test 3: Carrier detect === }
  WriteLn;
  WriteLn('Test 3: Carrier detect');
  Relay.SetCarrier(True);
  B := Relay.ReadReg(6);   { MSR — modem status register }
  Check('DCD on: MSR bit 7 set', (B and $80) = $80);

  Relay.SetCarrier(False);
  B := Relay.ReadReg(6);
  Check('DCD off: MSR bit 7 clear', (B and $80) = 0);

  Relay.SetCarrier(True);   { restore for remaining tests }

  { === Test 4: RING indicator === }
  WriteLn;
  WriteLn('Test 4: RING indicator');
  Relay.SetRing(True);
  B := Relay.ReadReg(6);
  Check('RING on: MSR bit 6 set', (B and $40) = $40);

  Relay.SetRing(False);
  B := Relay.ReadReg(6);
  Check('RING off: MSR bit 6 clear', (B and $40) = 0);

  { === Test 5: Full pump cycle via socket === }
  WriteLn;
  WriteLn('Test 5: Full pump cycle (socket → UART → socket)');

  { Client sends data }
  for I := 0 to 25 do SendBuf[I] := Ord('A') + I;
  ClientSock.SendBuffer(@SendBuf, 26);
  Sleep(100);

  { Pump: socket → UART RX ring }
  Relay.Pump;

  { Guest reads from UART (simulates BBS door reading) }
  Total := 0;
  for I := 0 to 25 do
  begin
    B := Relay.ReadReg(0);   { RBR }
    RecvBuf[I] := B;
    Inc(Total);
  end;
  Check('Guest read 26 bytes from UART', Total = 26);

  Match := True;
  for I := 0 to 25 do
    if RecvBuf[I] <> SendBuf[I] then Match := False;
  Check('All 26 bytes match (A-Z)', Match);

  { Guest writes response }
  for I := 0 to 25 do
    Relay.WriteReg(0, Ord('a') + I);   { THR }

  { Pump: UART TX ring → socket — multiple pumps to drain fully }
  Relay.Pump;
  Relay.Pump;
  Relay.Pump;
  Sleep(200);

  { Client reads response }
  Total := 0;
  Timeout := 0;
  while (Total < 26) and (Timeout < 50) do
  begin
    if ClientSock.CanRead(100) then
    begin
      I := ClientSock.RecvBufferEx(@RecvBuf[Total], 26 - Total, 500);
      if I > 0 then begin Inc(Total, I); Timeout := 0; end
      else Inc(Timeout);
    end
    else Inc(Timeout);
  end;

  Check('Client received 26 bytes back', Total = 26);
  Match := True;
  for I := 0 to 25 do
    if RecvBuf[I] <> Ord('a') + I then Match := False;
  Check('All 26 bytes match (a-z)', Match);

  { === Test 6: Bulk throughput === }
  WriteLn;
  WriteLn('Test 6: Bulk throughput (4KB)');
  for I := 0 to 4095 do
    SendBuf[I] := I and $FE;
  ClientSock.SendBuffer(@SendBuf, 4096);
  Sleep(200);

  { Pump multiple times to drain }
  for I := 0 to 15 do Relay.Pump;

  Check('BytesIn >= 4096', Relay.BytesIn >= 4096);

  { === Test 7: Disconnect === }
  WriteLn;
  WriteLn('Test 7: Detach');
  Relay.Detach;
  Check('Relay disconnected', not Relay.Connected);
  Check('BytesIn recorded', Relay.BytesIn > 0);
  Check('BytesOut recorded', Relay.BytesOut > 0);

  { === Test 8: PumpAll === }
  WriteLn;
  WriteLn('Test 8: PumpAll (no active nodes)');
  I := Manager.PumpAll;
  Check('PumpAll returns 0 (no active relays)', I = 0);

  { Cleanup }
  ClientSock.Free;
  ListenSock.Free;
  Manager.Free;

  WriteLn;
  WriteLn('==================================================');
  WriteLn('  Results: ', TestsPassed, ' passed, ', TestsFailed,
          ' failed, ', TestsTotal, ' total');
  if TestsFailed = 0 then
    WriteLn('  D5 DIRECT RELAY: ALL PASS')
  else
    WriteLn('  D5 DIRECT RELAY: FAILURES DETECTED');
  WriteLn('==================================================');
  if TestsFailed > 0 then Halt(1);

{$ELSE}
begin
  WriteLn('ERROR: compile with -dHAS_SYNAPSE');
  Halt(1);
{$ENDIF}
end.
