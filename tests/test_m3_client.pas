{ ===========================================================================
  netmodem2irc — M3 Live Connection Test Client
  GPLv3. Connects to the M3 test server and verifies the data path.
  ---------------------------------------------------------------------------
  Sends a series of test patterns and verifies they echo back correctly:
    1. ASCII text
    2. CP437 characters (128-255)
    3. Binary data (all 256 byte values)
    4. Zmodem-like header
    5. Bulk data (4KB)
    6. "quit" to disconnect

  Usage:
    test_m3_client                  connect to localhost:2323
    test_m3_client <host> <port>    connect to specified host:port
  =========================================================================== }

{$MODE OBJFPC}{$H+}

program test_m3_client;

uses
  SysUtils,
  {$IFDEF HAS_SYNAPSE}
  blcksock,
  {$ENDIF}
  Classes;

const
  DEFAULT_HOST = 'localhost';
  DEFAULT_PORT = 2323;

var
  TestsPassed, TestsFailed: Integer;

procedure Check(const Name: String; Condition: Boolean);
begin
  if Condition then
  begin
    Inc(TestsPassed);
    WriteLn('  PASS: ', Name);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('  FAIL: ', Name);
  end;
end;

{$IFDEF HAS_SYNAPSE}
function SendAndVerify(Sock: TTCPBlockSocket;
  const Data: array of Byte; Len: Integer;
  const TestName: String): Boolean;
var
  RecvBuf: array[0..4095] of Byte;
  Got, Total, I: Integer;
  Timeout: Integer;
  Match: Boolean;
begin
  Result := False;
  Sock.SendBuffer(@Data[0], Len);

  { Read back the echo }
  Total := 0;
  Timeout := 0;
  while (Total < Len) and (Timeout < 50) do  { 5 second timeout }
  begin
    if Sock.CanRead(100) then
    begin
      Got := Sock.RecvBuffer(@RecvBuf[Total], Len - Total);
      if Got > 0 then
      begin
        Inc(Total, Got);
        Timeout := 0;
      end
      else
        Inc(Timeout);
    end
    else
      Inc(Timeout);
  end;

  Match := Total = Len;
  if Match then
    for I := 0 to Len - 1 do
      if RecvBuf[I] <> Data[I] then
      begin
        Match := False;
        Break;
      end;

  Check(TestName + ' (' + IntToStr(Len) + ' bytes)', Match);
  Result := Match;
end;
{$ENDIF}

var
  Host: String;
  Port: Word;
  {$IFDEF HAS_SYNAPSE}
  Sock: TTCPBlockSocket;
  {$ENDIF}
  I: Integer;
  TestData: array[0..4095] of Byte;

begin
  WriteLn('==================================================');
  WriteLn('  M3 — Live Connection Test Client');
  WriteLn('==================================================');
  WriteLn;

  TestsPassed := 0;
  TestsFailed := 0;

  if ParamCount >= 2 then
  begin
    Host := ParamStr(1);
    Port := StrToIntDef(ParamStr(2), DEFAULT_PORT);
  end
  else
  begin
    Host := DEFAULT_HOST;
    Port := DEFAULT_PORT;
  end;

  {$IFNDEF HAS_SYNAPSE}
  WriteLn('ERROR: compile with -dHAS_SYNAPSE for network.');
  Halt(1);
  {$ENDIF}

  {$IFDEF HAS_SYNAPSE}
  WriteLn('Connecting to ', Host, ':', Port, '...');

  Sock := TTCPBlockSocket.Create;
  try
    Sock.Connect(Host, IntToStr(Port));
    if Sock.LastError <> 0 then
    begin
      WriteLn('FAIL: cannot connect — ', Sock.LastErrorDesc);
      Halt(1);
    end;
    WriteLn('Connected!');
    WriteLn;

    { Read and discard the welcome banner }
    Sleep(500);
    while Sock.CanRead(100) do
      Sock.RecvByte(100);

    { Test 1: ASCII text }
    WriteLn('Test 1: ASCII text');
    for I := 0 to 25 do TestData[I] := Ord('A') + I;
    SendAndVerify(Sock, TestData, 26, 'A-Z alphabet');

    { Test 2: CP437 box-drawing }
    WriteLn('Test 2: CP437 box-drawing');
    TestData[0] := $DA; TestData[1] := $C4; TestData[2] := $C4;
    TestData[3] := $BF; TestData[4] := $B3; TestData[5] := $C0;
    TestData[6] := $C4; TestData[7] := $C4; TestData[8] := $D9;
    SendAndVerify(Sock, TestData, 9, 'Box chars (DA C4 BF B3 C0 D9)');

    { Test 3: High bytes (128-254, skip 255/IAC for Telnet) }
    WriteLn('Test 3: High bytes (128-254)');
    for I := 0 to 126 do TestData[I] := 128 + I;
    SendAndVerify(Sock, TestData, 127, 'Bytes 128-254');

    { Test 4: Null bytes }
    WriteLn('Test 4: Null bytes');
    TestData[0] := 0; TestData[1] := 0; TestData[2] := $41;
    TestData[3] := 0; TestData[4] := $42;
    SendAndVerify(Sock, TestData, 5, 'Nulls + data');

    { Test 5: Zmodem-like header }
    WriteLn('Test 5: Zmodem header pattern');
    TestData[0] := $2A; { ZPAD }
    TestData[1] := $2A; { ZPAD }
    TestData[2] := $18; { ZDLE }
    TestData[3] := $42; { ZHEX }
    TestData[4] := $30; { '0' }
    TestData[5] := $30;
    TestData[6] := $0D;
    TestData[7] := $0A;
    SendAndVerify(Sock, TestData, 8, 'ZPAD ZPAD ZDLE ZHEX');

    { Test 6: Bulk data (4KB) }
    WriteLn('Test 6: Bulk data (4KB)');
    for I := 0 to 4095 do
      TestData[I] := I and $FE;   { skip $FF to avoid Telnet IAC }
    SendAndVerify(Sock, TestData, 4096, '4KB bulk transfer');

    { Send quit }
    WriteLn;
    WriteLn('Sending quit...');
    Sock.SendString('quit' + #13#10);
    Sleep(500);

  finally
    Sock.Free;
  end;

  WriteLn;
  WriteLn('==================================================');
  WriteLn('  Results: ', TestsPassed, ' passed, ', TestsFailed, ' failed');
  if TestsFailed = 0 then
    WriteLn('  M3 LIVE CONNECTION: ALL PASS')
  else
    WriteLn('  M3 LIVE CONNECTION: FAILURES DETECTED');
  WriteLn('==================================================');
  {$ENDIF}

  if TestsFailed > 0 then Halt(1);
end.
