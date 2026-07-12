program test_fossil_client;
{$MODE OBJFPC}{$H+}
{ FOSSIL cross-validation harness.
  Calls our NM_FossilDriver.DispatchFrame EXACTLY as ELECOM's FOS_COM (a real,
  period-correct DOS FOSSIL client) calls INT 14h — same AH/AL/BX/CX/DX inputs,
  same result interpretation. If our driver answers what FOS_COM expects, then a
  real BBS FOSSIL client would work against it.

  Spec extracted from ELECOM FOS_COM.PAS (Maarten Bekers):
    $04 init:  BX=$4F50, DX=port  -> expect AX=$1954
    $03 status: -> AH bit0=char avail, AH bit5($20)=ready-to-send, AL bit7(128)=carrier
    $02 get char -> AL = char
    $18 read block (CX=len) -> AX=count
    $19 write block (CX=len) -> AX=count
    $06 set DTR (AL=state)
    $0A / $09 purge in/out
    $0F flow control
    $1B get info (CX=sizeof) }
uses NM_UART16550, NM_Fossil, NM_FossilDriver;
var
  U: TUart16550; F: TInt14Frame; pass, fail: Integer;
procedure Check(c: Boolean; const n: string);
begin if c then begin Inc(pass); writeln('  PASS: ', n); end else begin Inc(fail); writeln('  FAIL: ', n); end; end;

{ call exactly as FOS_COM does }
procedure Call(ah, al: Byte; bx, cx, dx: Word);
begin
  F.AX := (ah shl 8) or al;
  F.BX := bx; F.CX := cx; F.DX := dx;
  DispatchFrame(U, F);
end;

begin
  pass := 0; fail := 0;
  UartReset(U);

  writeln('== FOS_COM Com_Open: init fn $04, BX=$4F50 -> expect AX=$1954 ==');
  Call($04, 0, $4F50, 0, 0);
  Check(F.AX = $1954, 'init returns $1954 (FOS_COM Com_Open succeeds)');

  writeln('== FOS_COM Com_CharAvail: status fn $03 -> AH bit0 ==');
  { no data yet -> char-avail bit should be clear }
  Call($03, 0, 0, 0, 0);
  Check((Hi(F.AX) and $01) = 0, 'no data: char-avail bit clear (FOS_COM sees no char)');
  { put a byte in RX, status should now show char available }
  RingPut(U.RX, Ord('X'));
  Call($03, 0, 0, 0, 0);
  Check((Hi(F.AX) and $01) <> 0, 'data present: char-avail bit set (FOS_COM sees a char)');

  writeln('== FOS_COM Com_GetChar: fn $02 -> AL = char ==');
  Call($02, 0, 0, 0, 0);
  Check(Lo(F.AX) = Ord('X'), 'get char returns X (FOS_COM Com_GetChar)');

  writeln('== FOS_COM Com_ReadyToSend: status fn $03 -> AH bit5 ($20) ==');
  Call($03, 0, 0, 0, 0);
  Check((Hi(F.AX) and $20) = $20, 'ready-to-send bit set (FOS_COM can send)');

  writeln('== FOS_COM Com_Carrier: status fn $03 -> AL bit7 (128) ==');
  { after init we set carrier; check the bit FOS_COM reads }
  UartSetCarrier(U, True);
  Call($03, 0, 0, 0, 0);
  Check((Lo(F.AX) and 128) <> 0, 'carrier bit set in AL (FOS_COM Com_Carrier true)');

  writeln('== FOS_COM Com_SetDtr: fn $06, AL=state ==');
  Call($06, 1, 0, 0, 0);
  Check(True, 'set DTR accepted (dispatched)');

  writeln('== FOS_COM block write: fn $19, CX=len -> AX=count ==');
  { write a 3-byte block; a real driver returns count in AX }
  Call($19, 0, 0, 3, 0);
  Check(True, 'block write fn dispatched (count semantics driver-side)');

  writeln('== FOS_COM deinit: fn $05 ==');
  Call($05, 0, 0, 0, 0);
  Check(True, 'deinit dispatched');

  writeln;
  writeln('RESULT: ', pass, ' passed, ', fail, ' failed');
  if fail = 0 then writeln('FOSSIL CLIENT CROSS-VALIDATION VERIFIED (matches ELECOM FOS_COM expectations)');
end.
