{$MODE OBJFPC}{$H+}
program test_r34_multinode;
{ R3.4 Multinode — self-contained test. Server + 3 clients in one process.
  GPLv3 — netmodem2irc }
uses SysUtils, blcksock, synsock;

const
  PORT = 2325;
  NODE_COUNT = 3;

var
  TestsPassed, TestsFailed, TestsTotal: Integer;

procedure Check(const Name: String; Cond: Boolean);
begin
  Inc(TestsTotal);
  if Cond then begin Inc(TestsPassed); WriteLn('  PASS: ', Name); end
  else begin Inc(TestsFailed); WriteLn('  FAIL: ', Name); end;
end;

var
  ListenSock: TTCPBlockSocket;
  ServerSide: array[0..NODE_COUNT-1] of TTCPBlockSocket;
  ClientSide: array[0..NODE_COUNT-1] of TTCPBlockSocket;
  I, J, Got, Total, Timeout: Integer;
  B, Expect: Byte;
  SendBuf: array[0..1023] of Byte;
  RecvBuf: array[0..1023] of Byte;
  Match: Boolean;

begin
  WriteLn('==================================================');
  WriteLn('  R3.4 — Multinode Test (', NODE_COUNT, ' nodes)');
  WriteLn('==================================================');
  WriteLn;
  TestsPassed := 0; TestsFailed := 0; TestsTotal := 0;

  { Create listener }
  ListenSock := TTCPBlockSocket.Create;
  ListenSock.CreateSocket;
  ListenSock.SetLinger(True, 500);
  ListenSock.Bind('127.0.0.1', IntToStr(PORT));
  ListenSock.Listen;
  Check('Server bound to port ' + IntToStr(PORT), ListenSock.LastError = 0);

  { Phase 1: Connect 3 clients simultaneously }
  WriteLn;
  WriteLn('Phase 1: Connect ', NODE_COUNT, ' clients');
  for I := 0 to NODE_COUNT-1 do
  begin
    ClientSide[I] := TTCPBlockSocket.Create;
    ClientSide[I].Connect('127.0.0.1', IntToStr(PORT));
    Check('Client ' + IntToStr(I) + ' connected', ClientSide[I].LastError = 0);

    { Accept on server side }
    if ListenSock.CanRead(2000) then
    begin
      ServerSide[I] := TTCPBlockSocket.Create;
      ServerSide[I].Socket := ListenSock.Accept;
      Check('Server accepted client ' + IntToStr(I), ServerSide[I].LastError = 0);
    end
    else
      Check('Server accepted client ' + IntToStr(I), False);
  end;

  { Phase 2: Independent echo — each client sends unique data }
  WriteLn;
  WriteLn('Phase 2: Independent echo per node');
  for I := 0 to NODE_COUNT-1 do
  begin
    { Build unique data: node ID + 20 sequential bytes }
    for J := 0 to 19 do
      SendBuf[J] := (I * 32 + J) and $FE;  { unique, skip $FF }

    { Client sends }
    ClientSide[I].SendBuffer(@SendBuf, 20);
    Sleep(50);

    { Server receives and echoes back }
    Total := 0;
    if ServerSide[I].CanRead(500) then
    begin
      Got := ServerSide[I].RecvBuffer(@RecvBuf, 20);
      if Got > 0 then
      begin
        ServerSide[I].SendBuffer(@RecvBuf, Got);
        Total := Got;
      end;
    end;
    Check('Server got ' + IntToStr(Total) + ' bytes from node ' + IntToStr(I),
          Total = 20);

    { Client receives echo }
    Sleep(50);
    Total := 0;
    Timeout := 0;
    while (Total < 20) and (Timeout < 20) do
    begin
      if ClientSide[I].CanRead(100) then
      begin
        Got := ClientSide[I].RecvBuffer(@RecvBuf[Total], 20 - Total);
        if Got > 0 then begin Inc(Total, Got); Timeout := 0; end
        else Inc(Timeout);
      end
      else Inc(Timeout);
    end;

    Match := (Total = 20);
    if Match then
      for J := 0 to 19 do
        if RecvBuf[J] <> ((I * 32 + J) and $FE) then Match := False;
    Check('Node ' + IntToStr(I) + ' echo matches (20 bytes)', Match);
  end;

  { Phase 3: Interleaved — all nodes send at once }
  WriteLn;
  WriteLn('Phase 3: Interleaved sends — no cross-talk');

  { All clients send simultaneously }
  for I := 0 to NODE_COUNT-1 do
  begin
    B := $A0 + I;
    ClientSide[I].SendBuffer(@B, 1);
  end;
  Sleep(100);

  { Server reads from each and echoes }
  for I := 0 to NODE_COUNT-1 do
  begin
    B := 0;
    if ServerSide[I].CanRead(200) then
    begin
      Got := ServerSide[I].RecvBuffer(@B, 1);
      ServerSide[I].SendBuffer(@B, 1);
      Check('Server got $' + IntToHex($A0 + I, 2) + ' from node ' + IntToStr(I),
            (Got = 1) and (B = $A0 + I));
    end
    else Check('Server received from node ' + IntToStr(I), False);
  end;

  { Clients read their echoes }
  for I := 0 to NODE_COUNT-1 do
  begin
    B := 0;
    if ClientSide[I].CanRead(200) then
    begin
      Got := ClientSide[I].RecvBuffer(@B, 1);
      Check('Node ' + IntToStr(I) + ' got its own byte back ($' +
            IntToHex($A0 + I, 2) + ')', (Got = 1) and (B = $A0 + I));
    end
    else Check('Node ' + IntToStr(I) + ' echo received', False);
  end;

  { Phase 4: Disconnect node 1, others survive }
  WriteLn;
  WriteLn('Phase 4: Disconnect node 1, nodes 0 and 2 survive');
  ServerSide[1].CloseSocket;
  ClientSide[1].CloseSocket;

  for I := 0 to NODE_COUNT-1 do
  begin
    if I = 1 then Continue;
    B := $B0 + I;
    ClientSide[I].SendBuffer(@B, 1);
    Sleep(50);
    B := 0;
    if ServerSide[I].CanRead(200) then
    begin
      Got := ServerSide[I].RecvBuffer(@B, 1);
      ServerSide[I].SendBuffer(@B, 1);
    end;
    B := 0;
    if ClientSide[I].CanRead(200) then
    begin
      Got := ClientSide[I].RecvBuffer(@B, 1);
      Check('Node ' + IntToStr(I) + ' alive after node 1 disconnect',
            (Got = 1) and (B = $B0 + I));
    end
    else Check('Node ' + IntToStr(I) + ' alive', False);
  end;

  { Phase 5: Bulk per-node (1KB each) }
  WriteLn;
  WriteLn('Phase 5: Bulk transfer (1KB per node, simultaneous)');
  for I := 0 to NODE_COUNT-1 do
  begin
    if I = 1 then Continue;
    for J := 0 to 255 do SendBuf[J] := (I * 64 + J) and $FE;
    ClientSide[I].SendBuffer(@SendBuf, 256);
    ClientSide[I].SendBuffer(@SendBuf, 256);
    ClientSide[I].SendBuffer(@SendBuf, 256);
    ClientSide[I].SendBuffer(@SendBuf, 256);
  end;
  Sleep(200);

  for I := 0 to NODE_COUNT-1 do
  begin
    if I = 1 then Continue;
    { Server drains and echoes }
    Total := 0;
    Timeout := 0;
    while (Total < 1024) and (Timeout < 30) do
    begin
      if ServerSide[I].CanRead(100) then
      begin
        Got := ServerSide[I].RecvBuffer(@RecvBuf, 1024 - Total);
        if Got > 0 then
        begin
          ServerSide[I].SendBuffer(@RecvBuf, Got);
          Inc(Total, Got);
          Timeout := 0;
        end else Inc(Timeout);
      end else Inc(Timeout);
    end;
    Check('Server echoed 1KB for node ' + IntToStr(I) +
          ' (' + IntToStr(Total) + ')', Total = 1024);
  end;

  for I := 0 to NODE_COUNT-1 do
  begin
    if I = 1 then Continue;
    Total := 0;
    Timeout := 0;
    while (Total < 1024) and (Timeout < 30) do
    begin
      if ClientSide[I].CanRead(100) then
      begin
        Got := ClientSide[I].RecvBuffer(@RecvBuf, 1024 - Total);
        if Got > 0 then begin Inc(Total, Got); Timeout := 0; end
        else Inc(Timeout);
      end else Inc(Timeout);
    end;
    Check('Node ' + IntToStr(I) + ' bulk echo ('+IntToStr(Total)+'/1024)',
          Total = 1024);
  end;

  { Cleanup }
  WriteLn;
  for I := 0 to NODE_COUNT-1 do
  begin
    if I = 1 then Continue;
    ServerSide[I].CloseSocket;
    ClientSide[I].CloseSocket;
    ServerSide[I].Free;
    ClientSide[I].Free;
  end;
  ServerSide[1].Free;
  ClientSide[1].Free;
  ListenSock.Free;

  WriteLn('==================================================');
  WriteLn('  Results: ', TestsPassed, ' passed, ', TestsFailed,
          ' failed, ', TestsTotal, ' total');
  if TestsFailed = 0 then
    WriteLn('  R3.4 MULTINODE: ALL PASS')
  else
    WriteLn('  R3.4 MULTINODE: FAILURES DETECTED');
  WriteLn('==================================================');
  if TestsFailed > 0 then Halt(1);
end.
