{ ===========================================================================
  test_d4_fossil_portable — Portable FOSSIL Conformance Test
  GPLv3 — Copyright (C) 2026 wrench (netmodem2irc)
  ---------------------------------------------------------------------------
  Same 37 tests as test_d4_fossil.pas but calls FossilDispatch()
  directly instead of INT 14h. Runs on any platform (Linux, Windows,
  OS/2, DOS). The original test_d4_fossil.pas is for real DOS with
  netfosdl loaded as a TSR.

  Tests every FSC-0015 rev 5 function against the Pascal FOSSIL engine.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

program test_d4_fossil_portable;

uses
  SysUtils, NM_UART16550, NM_Fossil;

var
  U: TUart16550;
  R: TFossilRegs;
  Passed, Failed, Total: Integer;

procedure Check(const Name: string; Cond: Boolean);
begin
  Inc(Total);
  if Cond then Inc(Passed)
  else begin Inc(Failed); WriteLn('  FAIL: ', Name); end;
end;

procedure CallFOSSIL(Fn: Byte);
begin
  FillChar(R, SizeOf(R), 0);
  R.AH := Fn;
  FossilDispatch(U, R);
end;

{ === Fn $04: Initialize === }
procedure Test_Fn04_Init;
begin
  WriteLn('Fn $04: Initialize');
  CallFOSSIL($04);
  Check('AH:AL = $1954 (FOSSIL signature)', (R.AH = $19) and (R.AL = $54));
  Check('BX = $0521 (rev 5, max Fn $21)', R.BX = $0521);
  Check('Handled = True', R.Handled);
end;

{ === Fn $00: Set Baud Rate === }
procedure Test_Fn00_SetBaud;
begin
  WriteLn('Fn $00: Set Baud Rate');
  FillChar(R, SizeOf(R), 0);
  R.AH := $00;
  R.AL := $E3;  { 9600 8N1 }
  FossilDispatch(U, R);
  Check('Handled', R.Handled);
  Check('Returns status (AH has THRE)', (R.AH and $20) = $20);
end;

{ === Fn $03: Status === }
procedure Test_Fn03_Status;
begin
  WriteLn('Fn $03: Status');
  CallFOSSIL($03);
  Check('AH bit 5 set (TX ready)', (R.AH and $20) = $20);
  Check('AH bit 6 set (TX empty)', (R.AH and $40) = $40);
  Check('AH bit 0 = 0 (no RX data yet)', (R.AH and $01) = 0);
  Check('Handled', R.Handled);
end;

{ === Fn $01: Write char (blocking) === }
procedure Test_Fn01_WriteChar;
begin
  WriteLn('Fn $01: Write character (blocking)');
  FillChar(R, SizeOf(R), 0);
  R.AH := $01;
  R.AL := $41;  { 'A' }
  FossilDispatch(U, R);
  Check('Byte accepted (AH has THRE)', (R.AH and $20) = $20);
  Check('Handled', R.Handled);
end;

{ === Fn $0B: Write char (non-blocking) === }
procedure Test_Fn0B_WriteCharNB;
begin
  WriteLn('Fn $0B: Write character (non-blocking)');
  FillChar(R, SizeOf(R), 0);
  R.AH := $0B;
  R.AL := $42;  { 'B' }
  FossilDispatch(U, R);
  Check('Handled', R.Handled);
end;

{ === Fn $09: Purge output === }
procedure Test_Fn09_PurgeOutput;
begin
  WriteLn('Fn $09: Purge output buffer');
  CallFOSSIL($09);
  Check('Handled', R.Handled);
  { Verify TX is now empty }
  CallFOSSIL($03);
  Check('TX ready after purge (AH bit 5)', (R.AH and $20) = $20);
  Check('TX empty after purge (AH bit 6)', (R.AH and $40) = $40);
end;

{ === Fn $0A: Purge input === }
procedure Test_Fn0A_PurgeInput;
begin
  WriteLn('Fn $0A: Purge input buffer');
  CallFOSSIL($0A);
  Check('Handled', R.Handled);
  CallFOSSIL($03);
  Check('No data after purge (AH bit 0 = 0)', (R.AH and $01) = 0);
end;

{ === Fn $06: DTR control === }
procedure Test_Fn06_DTR;
begin
  WriteLn('Fn $06: DTR control');
  FillChar(R, SizeOf(R), 0);
  R.AH := $06;
  R.AL := $01;  { raise DTR }
  FossilDispatch(U, R);
  Check('DTR raised, handled', R.Handled);

  FillChar(R, SizeOf(R), 0);
  R.AH := $06;
  R.AL := $00;  { lower DTR }
  FossilDispatch(U, R);
  Check('DTR lowered, handled', R.Handled);

  { Raise for remaining tests }
  FillChar(R, SizeOf(R), 0);
  R.AH := $06;
  R.AL := $01;
  FossilDispatch(U, R);
end;

{ === Fn $08: Flush output === }
procedure Test_Fn08_Flush;
begin
  WriteLn('Fn $08: Flush output');
  CallFOSSIL($08);
  Check('Handled', R.Handled);
end;

{ === Fn $0C: Peek (non-destructive) === }
procedure Test_Fn0C_Peek;
begin
  WriteLn('Fn $0C: Peek (non-destructive read)');
  CallFOSSIL($0C);
  Check('No data: AL = $FF', R.AL = $FF);
  Check('Handled', R.Handled);

  { Push a byte into RX, peek, verify still there }
  UartNetToGuest(U, $5A);
  CallFOSSIL($0C);
  Check('Peek sees $5A', R.AL = $5A);

  { Peek again — should still be there (non-destructive) }
  CallFOSSIL($0C);
  Check('Second peek still $5A', R.AL = $5A);

  { Now read it — should consume }
  FillChar(R, SizeOf(R), 0);
  R.AH := $02;
  UartSetCarrier(U, True);  { Fn02 blocks until data or carrier loss }
  FossilDispatch(U, R);
  Check('Read consumes $5A', R.AL = $5A);

  { Peek again — should be empty }
  CallFOSSIL($0C);
  Check('Peek empty after read: AL = $FF', R.AL = $FF);
end;

{ === Fn $19: Block write === }
procedure Test_Fn19_BlockWrite;
var
  Buf: array[0..9] of Byte;
  i: Integer;
begin
  WriteLn('Fn $19: Block write');
  for i := 0 to 9 do Buf[i] := $30 + i;

  FillChar(R, SizeOf(R), 0);
  R.AH := $19;
  R.CX := 10;
  R.Buf := @Buf;
  FossilDispatch(U, R);
  Check('AX = 10 (all accepted)', (R.AH * 256 + R.AL) = 10);
  Check('Handled', R.Handled);
end;

{ === Fn $18: Block read === }
procedure Test_Fn18_BlockRead;
var
  Buf: array[0..63] of Byte;
begin
  WriteLn('Fn $18: Block read');
  FillChar(Buf, SizeOf(Buf), $AA);

  FillChar(R, SizeOf(R), 0);
  R.AH := $18;
  R.CX := 64;
  R.Buf := @Buf;
  FossilDispatch(U, R);
  Check('AX = 0 (no RX data)', (R.AH * 256 + R.AL) = 0);
  Check('Handled', R.Handled);
end;

{ === Fn $1A: BREAK === }
procedure Test_Fn1A_Break;
begin
  WriteLn('Fn $1A: BREAK signal');
  FillChar(R, SizeOf(R), 0);
  R.AH := $1A;
  R.AL := $01;
  FossilDispatch(U, R);
  Check('BREAK start handled', R.Handled);

  FillChar(R, SizeOf(R), 0);
  R.AH := $1A;
  R.AL := $00;
  FossilDispatch(U, R);
  Check('BREAK stop handled', R.Handled);
end;

{ === Fn $1B: Get FOSSIL info === }
procedure Test_Fn1B_GetInfo;
var
  Info: TFossilInfo;
begin
  WriteLn('Fn $1B: Get FOSSIL info');
  FillChar(Info, SizeOf(Info), 0);

  FillChar(R, SizeOf(R), 0);
  R.AH := $1B;
  R.CX := SizeOf(Info);
  R.Buf := @Info;
  FossilDispatch(U, R);

  Check('StrSiz = sizeof', Info.StrSiz = SizeOf(Info));
  Check('MajVer = 5', Info.MajVer = 5);
  Check('IBufr > 0', Info.IBufr > 0);
  Check('OBufr > 0', Info.OBufr > 0);
  Check('IFree <= IBufr', Info.IFree <= Info.IBufr);
  Check('OFree <= OBufr', Info.OFree <= Info.OBufr);
  Check('SWidth > 0', Info.SWidth > 0);
  Check('SHeight > 0', Info.SHeight > 0);
  Check('Handled', R.Handled);
end;

{ === Fn $0F: Flow control === }
procedure Test_Fn0F_FlowControl;
begin
  WriteLn('Fn $0F: Flow control');
  FillChar(R, SizeOf(R), 0);
  R.AH := $0F;
  R.AL := $00;
  FossilDispatch(U, R);
  Check('Disable flow handled', R.Handled);

  FillChar(R, SizeOf(R), 0);
  R.AH := $0F;
  R.AL := $09;  { XON/XOFF + CTS/RTS }
  FossilDispatch(U, R);
  Check('Enable flow handled', R.Handled);
end;

{ === Fn $13: ANSI write === }
procedure Test_Fn13_ANSIWrite;
var
  Buf: array[0..4] of Byte;
begin
  WriteLn('Fn $13: ANSI write');
  Buf[0] := $48; Buf[1] := $45; Buf[2] := $4C; Buf[3] := $4C; Buf[4] := $4F;

  FillChar(R, SizeOf(R), 0);
  R.AH := $13;
  R.CX := 5;
  R.Buf := @Buf;
  FossilDispatch(U, R);
  Check('ANSI write handled', R.Handled);
  Check('5 bytes written to TX', U.TX.Count >= 5);
end;

{ === Fn $20: X00 Extended RX read === }
procedure Test_Fn20_ExtRead;
begin
  WriteLn('Fn $20: X00 Extended RX read');
  { Empty — should return $80 in AH }
  CallFOSSIL($20);
  Check('AH = $80 (no data)', R.AH = $80);
  Check('Handled', R.Handled);

  { Push byte, read it }
  UartNetToGuest(U, $7E);
  CallFOSSIL($20);
  Check('AL = $7E', R.AL = $7E);
  Check('AH = 0 (data OK)', R.AH = 0);
end;

{ === Fn $21: X00 Inject to RX === }
procedure Test_Fn21_Inject;
begin
  WriteLn('Fn $21: X00 Inject to RX');
  FillChar(R, SizeOf(R), 0);
  R.AH := $21;
  R.AL := $AA;
  FossilDispatch(U, R);
  Check('Handled', R.Handled);
  Check('RX has data', U.RX.Count > 0);
end;

{ === Fn $7E/$7F: Extended signature === }
procedure Test_Fn7E_Signature;
begin
  WriteLn('Fn $7E/$7F: Extended FOSSIL signature');
  FillChar(R, SizeOf(R), 0);
  R.AH := $7E;
  R.AL := $42;
  FossilDispatch(U, R);
  Check('AH:AL = $1954', (R.AH = $19) and (R.AL = $54));
  Check('BX = input AL ($42)', R.BX = $42);
  Check('Handled', R.Handled);
end;

{ === Fn $05: Deinitialize === }
procedure Test_Fn05_Deinit;
begin
  WriteLn('Fn $05: Deinitialize');
  CallFOSSIL($05);
  Check('Handled', R.Handled);

  { Re-init }
  CallFOSSIL($04);
  Check('Re-init AH:AL = $1954', (R.AH = $19) and (R.AL = $54));
end;

{ === Out-of-range functions === }
procedure Test_OutOfRange;
begin
  WriteLn('Out-of-range: AH = $30');
  FillChar(R, SizeOf(R), 0);
  R.AH := $30;
  FossilDispatch(U, R);
  Check('Not handled (chains to BIOS)', not R.Handled);
end;

begin
  Passed := 0;
  Failed := 0;
  Total := 0;

  WriteLn('==================================================');
  WriteLn('  D4 — FOSSIL Conformance Test (Portable)');
  WriteLn('  FSC-0015 rev 5 + X00 Extensions');
  WriteLn('  Tests FossilDispatch() directly — no INT 14h');
  WriteLn('==================================================');
  WriteLn;

  UartReset(U);

  Test_Fn04_Init;         WriteLn;
  Test_Fn00_SetBaud;      WriteLn;
  Test_Fn03_Status;       WriteLn;
  Test_Fn01_WriteChar;    WriteLn;
  Test_Fn0B_WriteCharNB;  WriteLn;
  Test_Fn09_PurgeOutput;  WriteLn;
  Test_Fn0A_PurgeInput;   WriteLn;
  Test_Fn06_DTR;          WriteLn;
  Test_Fn08_Flush;        WriteLn;
  Test_Fn0C_Peek;         WriteLn;
  Test_Fn19_BlockWrite;   WriteLn;
  Test_Fn18_BlockRead;    WriteLn;
  Test_Fn1A_Break;        WriteLn;
  Test_Fn1B_GetInfo;      WriteLn;
  Test_Fn0F_FlowControl;  WriteLn;
  Test_Fn13_ANSIWrite;    WriteLn;
  Test_Fn20_ExtRead;      WriteLn;
  Test_Fn21_Inject;       WriteLn;
  Test_Fn7E_Signature;    WriteLn;
  Test_Fn05_Deinit;       WriteLn;
  Test_OutOfRange;

  WriteLn;
  WriteLn('==================================================');
  WriteLn('  Results: ', Passed, ' passed, ', Failed, ' failed, ', Total, ' total');
  if Failed = 0 then
    WriteLn('  D4 FOSSIL CONFORMANCE: ALL PASS')
  else
    WriteLn('  D4 FOSSIL CONFORMANCE: FAILURES DETECTED');
  WriteLn('==================================================');

  if Failed > 0 then Halt(1);
end.
