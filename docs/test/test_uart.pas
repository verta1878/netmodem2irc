program test_uart;
{$MODE OBJFPC}{$H+}
uses NM_UART16550;
var
  U: TUart16550;
  b: Byte;
  pass, fail: Integer;
procedure Check(cond: Boolean; const name: string);
begin
  if cond then begin Inc(pass); writeln('  PASS: ', name); end
  else begin Inc(fail); writeln('  FAIL: ', name); end;
end;
begin
  pass := 0; fail := 0;
  UartReset(U);

  writeln('== reset state ==');
  Check((U.LSR and LSR_THRE) <> 0, 'THRE set after reset (TX has room)');
  Check((U.LSR and LSR_DR) = 0,   'DR clear after reset (RX empty)');
  Check((U.MSR and MSR_DCD) = 0,  'DCD clear after reset (offline)');

  writeln('== guest writes THR -> server drains TX ==');
  UartWriteReg(U, UART_THR, $41);  // 'A'
  UartWriteReg(U, UART_THR, $42);  // 'B'
  Check(UartGuestToNet(U, b) and (b = $41), 'TX byte 1 = A');
  Check(UartGuestToNet(U, b) and (b = $42), 'TX byte 2 = B');
  Check(not UartGuestToNet(U, b),           'TX now empty');

  writeln('== server delivers RX -> guest reads RBR ==');
  UartNetToGuest(U, $58);          // 'X'
  Check((U.LSR and LSR_DR) <> 0,   'DR set after net byte arrives');
  Check(UartReadReg(U, UART_RBR) = $58, 'RBR reads X');
  Check((U.LSR and LSR_DR) = 0,    'DR clear after reading last byte');

  writeln('== DLAB switches DLL/DLM ==');
  UartWriteReg(U, UART_LCR, LCR_DLAB);       // set DLAB
  UartWriteReg(U, UART_DLL, $0C);            // divisor low = 12 (9600)
  Check(UartReadReg(U, UART_DLL) = $0C,      'DLL reads back with DLAB set');
  UartWriteReg(U, UART_LCR, $03);            // clear DLAB, 8N1
  UartNetToGuest(U, $99);
  Check(UartReadReg(U, UART_RBR) = $99,      'offset 0 = RBR again with DLAB clear');

  writeln('== carrier/ring -> MSR ==');
  UartSetCarrier(U, True);
  Check((U.MSR and MSR_DCD) <> 0,  'DCD set when online');
  UartSetRing(U, True);
  Check((U.MSR and MSR_RI) <> 0,   'RI set when ringing');
  b := UartReadReg(U, UART_MSR);   // read clears deltas
  Check((U.MSR and $0F) = 0,       'MSR delta bits cleared after read');

  writeln;
  writeln('RESULT: ', pass, ' passed, ', fail, ' failed');
  if fail = 0 then writeln('UART16550 EMULATION VERIFIED');
end.
