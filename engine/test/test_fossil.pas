program test_fossil;
{$MODE OBJFPC}{$H+}
uses NM_UART16550, NM_Fossil;
var
  U: TUart16550;
  R: TFossilRegs;
  Info: TFossilInfo;
  pass, fail: Integer;
procedure Check(cond: Boolean; const name: string);
begin
  if cond then begin Inc(pass); writeln('  PASS: ', name); end
  else begin Inc(fail); writeln('  FAIL: ', name); end;
end;
procedure Call(fn: Byte; al: Byte = 0);
begin
  FillChar(R, SizeOf(R), 0);
  R.AH := fn; R.AL := al;
  FossilDispatch(U, R);
end;
begin
  pass := 0; fail := 0;
  UartReset(U);

  writeln('== Fn 04h init returns FOSSIL signature ==');
  Call(FN_INIT);
  Check((R.AH = $19) and (R.AL = $54), 'AX = 1954h (FOSSIL signature)');
  Check(R.BX = $0521,                  'BX = 0521h (maxfunc 21h / rev 5)');

  writeln('== Fn 01h transmit -> byte lands in TX for server ==');
  Call(FN_TX_WAIT, $41);   // send 'A'
  Check(U.TX.Count = 1,    'TX has 1 byte after transmit');
  Check(U.TX.Data[U.TX.Tail] = $41, 'TX byte is A');

  writeln('== Fn 02h receive -> pulls from RX (server-delivered) ==');
  UartNetToGuest(U, $5A);  // server delivers 'Z'
  Call(FN_RX_WAIT);
  Check(R.AL = $5A,        'received Z via Fn 02h');

  writeln('== Fn 0Ch peek does not remove ==');
  UartNetToGuest(U, $42);  // 'B'
  Call(FN_PEEK);
  Check(R.AL = $42,        'peek sees B');
  Check(U.RX.Count = 1,    'peek did not remove B');
  Call(FN_RX_WAIT);
  Check(R.AL = $42,        'B still there to read');

  writeln('== Fn 03h status reflects buffers + carrier ==');
  UartSetCarrier(U, True);
  UartNetToGuest(U, $01);
  Call(FN_GET_STATUS);
  Check((R.AH and FSTAT_RX_READY) <> 0, 'status: RX ready');
  Check((R.AH and FSTAT_TX_ROOM) <> 0,  'status: TX room');
  Check((R.AL and MSR_DCD) <> 0,        'status AL: DCD (online)');

  writeln('== Fn 06h drop DTR -> hangup (carrier off) ==');
  Call(FN_SET_DTR, 0);
  Check(not U.Online,      'DTR drop cleared carrier');

  writeln('== Fn 0Ah purge input ==');
  UartNetToGuest(U, $99);
  Call(FN_PURGE_INPUT);
  Check(U.RX.Count = 0,    'RX purged');

  writeln('== Fn 1Bh info block ==');
  FossilGetInfo(U, Info);
  Check(Info.MajVer = 5,   'info MajVer = 5');
  Check(Info.StrSiz = SizeOf(TFossilInfo), 'info StrSiz correct');
  Check((Info.SWidth = 80) and (Info.SHeight = 25), 'info 80x25');

  writeln('== X00 superset fn recognized (no fault) ==');
  Call(FN_SET_CURSOR);
  Check(R.Handled,         'Fn 11h handled (no-op, no fault)');

  writeln;
  writeln('RESULT: ', pass, ' passed, ', fail, ' failed');
  if fail = 0 then writeln('FOSSIL EMULATION VERIFIED');
end.
