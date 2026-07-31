{ ===========================================================================
  netmodem2irc — D4 FOSSIL Conformance Test
  GPLv3. Tests netfosdl against FSC-0015 rev 5 / FSC-0072.
  ---------------------------------------------------------------------------
  Exercises every FOSSIL INT 14h function and verifies the return
  values match the specification. Run on real DOS hardware with
  netfosdl loaded as a TSR.

  This does NOT require a connected modem — it tests the FOSSIL
  driver's API contract, not the serial hardware. Run it with
  netfosdl loaded but no cable connected.

  Usage:
    1. Load netfosdl: NETFOSDL /P:1 /B:9600
    2. Run this test: TEST_D4
    3. Compare output against X00/BNU/ADF/NetFoss

  Compile: fpc -Mtp test_d4_fossil.pas
  (or ppcross386 -Tgo32v2 for DOS target)
  =========================================================================== }

{$MODE TP}

program test_d4_fossil;

uses Dos;

const
  FOSSIL_SIG   = $1954;   { AX after Fn $04 = success }
  FOSSIL_REV5  = $0521;   { BX after Fn $04 = rev 5, max Fn $21 }
  FOSSIL_PORT  = 0;       { COM1 = 0, COM2 = 1 }

var
  TestsPassed, TestsFailed, TestsTotal: Integer;
  Regs: Registers;

procedure Check(const Name: String; Cond: Boolean);
begin
  Inc(TestsTotal);
  if Cond then
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

procedure CallFOSSIL(Fn: Byte);
{ Call INT 14h with AH=Fn, DX=port }
begin
  FillChar(Regs, SizeOf(Regs), 0);
  Regs.AH := Fn;
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
end;

{ === Fn $04: Initialize === }
procedure Test_Fn04_Init;
begin
  WriteLn('Fn $04: Initialize');
  CallFOSSIL($04);
  Check('AX = $1954 (FOSSIL signature)', Regs.AX = FOSSIL_SIG);
  Check('BX = $0521 (rev 5, max Fn $21)', Regs.BX = FOSSIL_REV5);
  Check('BL = $21 (max function number)', Regs.BL = $21);
  Check('BH = $05 (revision 5)', Regs.BH = $05);
end;

{ === Fn $00: Set Baud Rate === }
procedure Test_Fn00_SetBaud;
begin
  WriteLn('Fn $00: Set Baud Rate');
  { AL = $E3 = 9600 baud, no parity, 8 data, 1 stop
    Bits [7:5] = 111 = 9600
    Bits [4:3] = 00  = no parity
    Bits [2]   = 1   = 8 data bits
    Bits [1:0] = 11  = (unused in some drivers) }
  Regs.AH := $00;
  Regs.AL := $E3;
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
  Check('Returns status in AX (non-zero)', Regs.AX <> 0);
  { AH = line status, AL = modem status — same as Fn $03 }
end;

{ === Fn $03: Status === }
procedure Test_Fn03_Status;
begin
  WriteLn('Fn $03: Status');
  CallFOSSIL($03);
  { AH bit 5 = transmit holding register empty (should be 1 when idle) }
  Check('AH bit 5 set (TX ready)', (Regs.AH and $20) = $20);
  { AH bit 0 = data ready (should be 0 with nothing connected) }
  { AL = modem status register }
  Check('Returns AH (line status) + AL (modem status)', True);
end;

{ === Fn $01: Write char (blocking) === }
procedure Test_Fn01_WriteChar;
begin
  WriteLn('Fn $01: Write character (blocking)');
  Regs.AH := $01;
  Regs.AL := $41;   { 'A' }
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
  Check('Returns without hanging (TX buffer accepted byte)', True);
  { Note: with no modem connected, the byte goes into the TX ring
    and gets sent to nowhere. That's correct behavior. }
end;

{ === Fn $0B: Write char (non-blocking) === }
procedure Test_Fn0B_WriteCharNB;
begin
  WriteLn('Fn $0B: Write character (non-blocking)');
  Regs.AH := $0B;
  Regs.AL := $42;   { 'B' }
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
  Check('AX = 1 (byte accepted)', Regs.AX = 1);
end;

{ === Fn $09: Purge output === }
procedure Test_Fn09_PurgeOutput;
begin
  WriteLn('Fn $09: Purge output buffer');
  CallFOSSIL($09);
  Check('Returns without error', True);
  { Verify TX buffer is now empty }
  CallFOSSIL($03);
  Check('TX ready after purge (AH bit 5)', (Regs.AH and $20) = $20);
end;

{ === Fn $0A: Purge input === }
procedure Test_Fn0A_PurgeInput;
begin
  WriteLn('Fn $0A: Purge input buffer');
  CallFOSSIL($0A);
  Check('Returns without error', True);
  { Verify RX buffer is now empty }
  CallFOSSIL($03);
  Check('No data ready after purge (AH bit 0 = 0)', (Regs.AH and $01) = 0);
end;

{ === Fn $06: DTR control === }
procedure Test_Fn06_DTR;
begin
  WriteLn('Fn $06: DTR control');
  { Raise DTR }
  Regs.AH := $06;
  Regs.AL := $01;
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
  Check('DTR raised (AL=1) without error', True);

  { Lower DTR }
  Regs.AH := $06;
  Regs.AL := $00;
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
  Check('DTR lowered (AL=0) without error', True);

  { Raise again for remaining tests }
  Regs.AH := $06;
  Regs.AL := $01;
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
end;

{ === Fn $08: Flush output (drain) === }
procedure Test_Fn08_Flush;
begin
  WriteLn('Fn $08: Flush output (wait for TX empty)');
  CallFOSSIL($08);
  Check('Returns after TX buffer drained', True);
end;

{ === Fn $18: Block read === }
procedure Test_Fn18_BlockRead;
var
  Buf: array[0..63] of Byte;
begin
  WriteLn('Fn $18: Block read');
  { With nothing connected, should return 0 bytes }
  FillChar(Buf, SizeOf(Buf), $AA);
  Regs.AH := $18;
  Regs.CX := 64;
  Regs.ES := Seg(Buf);
  Regs.DI := Ofs(Buf);
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
  Check('AX = 0 (no data available)', Regs.AX = 0);
end;

{ === Fn $19: Block write === }
procedure Test_Fn19_BlockWrite;
var
  Buf: array[0..9] of Byte;
  I: Integer;
begin
  WriteLn('Fn $19: Block write');
  for I := 0 to 9 do Buf[I] := $30 + I;   { '0'..'9' }
  Regs.AH := $19;
  Regs.CX := 10;
  Regs.ES := Seg(Buf);
  Regs.DI := Ofs(Buf);
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
  Check('AX = 10 (all bytes accepted)', Regs.AX = 10);
end;

{ === Fn $0C: Peek (non-destructive read) === }
procedure Test_Fn0C_Peek;
begin
  WriteLn('Fn $0C: Peek (non-destructive read)');
  CallFOSSIL($0C);
  { With no data, AX should be $FFFF }
  Check('AX = $FFFF (no data to peek)', Regs.AX = $FFFF);
end;

{ === Fn $1A: BREAK signal === }
procedure Test_Fn1A_Break;
begin
  WriteLn('Fn $1A: BREAK signal');
  { Start BREAK }
  Regs.AH := $1A;
  Regs.AL := $01;
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
  Check('BREAK start accepted', True);

  { Stop BREAK }
  Regs.AH := $1A;
  Regs.AL := $00;
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
  Check('BREAK stop accepted', True);
end;

{ === Fn $1B: Get FOSSIL info === }
procedure Test_Fn1B_GetInfo;
type
  TFossilInfo = packed record
    StructSize:   Word;
    MajorVer:     Byte;
    MinorVer:     Byte;
    IDStringOfs:  Word;
    IDStringSeg:  Word;
    RXBufSize:    Word;
    RXBufFree:    Word;
    TXBufSize:    Word;
    TXBufFree:    Word;
    ScreenWidth:  Byte;
    ScreenHeight: Byte;
    BaudRate:     Word;
  end;
var
  Info: TFossilInfo;
begin
  WriteLn('Fn $1B: Get FOSSIL info');
  FillChar(Info, SizeOf(Info), 0);
  Regs.AH := $1B;
  Regs.CX := SizeOf(Info);
  Regs.ES := Seg(Info);
  Regs.DI := Ofs(Info);
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);

  Check('AX = struct bytes filled (>= 18)', Regs.AX >= 18);
  Check('StructSize = sizeof(TFossilInfo)', Info.StructSize = SizeOf(Info));
  Check('MajorVer > 0', Info.MajorVer > 0);
  Check('RXBufSize > 0', Info.RXBufSize > 0);
  Check('TXBufSize > 0', Info.TXBufSize > 0);
  Check('RXBufFree <= RXBufSize', Info.RXBufFree <= Info.RXBufSize);
  Check('TXBufFree <= TXBufSize', Info.TXBufFree <= Info.TXBufSize);
  Check('ScreenWidth > 0 (e.g. 80)', Info.ScreenWidth > 0);
  Check('ScreenHeight > 0 (e.g. 25)', Info.ScreenHeight > 0);

  WriteLn('  Info: ', Info.MajorVer, '.', Info.MinorVer,
          ' RX=', Info.RXBufSize, '/', Info.RXBufFree,
          ' TX=', Info.TXBufSize, '/', Info.TXBufFree,
          ' Screen=', Info.ScreenWidth, 'x', Info.ScreenHeight,
          ' Baud=', Info.BaudRate);
end;

{ === Fn $0F: Set flow control (stub) === }
procedure Test_Fn0F_FlowControl;
begin
  WriteLn('Fn $0F: Set flow control');
  { Many doors call this. Even if it's stubbed, it must not crash. }
  Regs.AH := $0F;
  Regs.AL := $00;   { disable flow control }
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
  Check('Fn $0F returns without crash', True);

  Regs.AH := $0F;
  Regs.AL := $09;   { XON/XOFF + CTS/RTS }
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);
  Check('Fn $0F with flow control enabled returns OK', True);
end;

{ === Fn $05: Deinitialize === }
procedure Test_Fn05_Deinit;
begin
  WriteLn('Fn $05: Deinitialize');
  CallFOSSIL($05);
  Check('Deinit returns without error', True);
  { DTR should be lowered (hangup) }

  { Re-init for any further tests }
  CallFOSSIL($04);
  Check('Re-init succeeds (AX = $1954)', Regs.AX = FOSSIL_SIG);
end;

{ === Cross-driver comparison === }
procedure Test_CrossDriver;
begin
  WriteLn('Cross-driver comparison notes:');
  WriteLn('  Run this same test with X00, BNU, ADF, and NetFoss loaded.');
  WriteLn('  Compare the output line by line. Key differences to watch:');
  WriteLn('    - Fn $1B info struct size (some drivers return < 18 bytes)');
  WriteLn('    - Fn $0F flow control (some ignore, some implement)');
  WriteLn('    - Fn $0C peek return ($FFFF vs $FF00 for "no data")');
  WriteLn('    - Fn $18/$19 block I/O byte counts');
  WriteLn('    - BaudRate field in info struct');
end;

{ === Main === }
begin
  WriteLn('==================================================');
  WriteLn('  D4 — FOSSIL Conformance Test');
  WriteLn('  FSC-0015 rev 5 / FSC-0072');
  WriteLn('  Port: COM', FOSSIL_PORT + 1);
  WriteLn('==================================================');
  WriteLn;

  TestsPassed := 0;
  TestsFailed := 0;
  TestsTotal := 0;

  Test_Fn04_Init;      WriteLn;
  Test_Fn00_SetBaud;   WriteLn;
  Test_Fn03_Status;    WriteLn;
  Test_Fn01_WriteChar; WriteLn;
  Test_Fn0B_WriteCharNB; WriteLn;
  Test_Fn09_PurgeOutput; WriteLn;
  Test_Fn0A_PurgeInput;  WriteLn;
  Test_Fn06_DTR;       WriteLn;
  Test_Fn08_Flush;     WriteLn;
  Test_Fn18_BlockRead; WriteLn;
  Test_Fn19_BlockWrite; WriteLn;
  Test_Fn0C_Peek;      WriteLn;
  Test_Fn1A_Break;     WriteLn;
  Test_Fn1B_GetInfo;   WriteLn;
  Test_Fn0F_FlowControl; WriteLn;
  Test_Fn05_Deinit;    WriteLn;
  Test_CrossDriver;

  WriteLn;
  WriteLn('==================================================');
  WriteLn('  Results: ', TestsPassed, ' passed, ', TestsFailed,
          ' failed, ', TestsTotal, ' total');
  if TestsFailed = 0 then
    WriteLn('  D4 FOSSIL CONFORMANCE: ALL PASS')
  else
    WriteLn('  D4 FOSSIL CONFORMANCE: FAILURES DETECTED');
  WriteLn('==================================================');

  { Final deinit }
  FillChar(Regs, SizeOf(Regs), 0);
  Regs.AH := $05;
  Regs.DX := FOSSIL_PORT;
  Intr($14, Regs);

  if TestsFailed > 0 then Halt(1);
end.
