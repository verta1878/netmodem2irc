program test_fossil_block;
{$MODE OBJFPC}{$H+}
{ Fn 18h/19h block read/write, with boundary discipline: the RETURNED COUNT is the
  thing that breaks in block I/O (qwkpoll lesson - test the number). Verify counts
  at: available<CX, available=CX, available>CX, buffer full, empty, nil. }
uses SysUtils, NM_UART16550, NM_Fossil;
var
  U: TUart16550; R: TFossilRegs; pass,fail,i: Integer;
  buf: array[0..63] of Byte;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
function AX(const RR:TFossilRegs):Word; begin AX := (RR.AH shl 8) or RR.AL; end;
begin
  pass:=0;fail:=0;
  UartReset(U);

  writeln('== Fn 19h WRITE_BLOCK: write 5 bytes into TX ==');
  for i:=0 to 4 do buf[i]:=Ord('A')+i;   // A B C D E
  FillChar(R, SizeOf(R), 0);
  R.AH:=$19; R.CX:=5; R.Buf:=@buf[0];
  FossilDispatch(U, R);
  Check(AX(R)=5, 'wrote all 5 bytes (AX=5)');
  Check(U.TX.Count=5, 'TX ring holds 5 bytes');

  writeln('== Fn 18h READ_BLOCK: those bytes appear as RX after loopback ==');
  { move TX->RX to simulate the wire echoing back, so we can read them }
  for i:=0 to 4 do begin RingPut(U.RX, Ord('A')+i); end;
  FillChar(buf, SizeOf(buf), 0);
  FillChar(R, SizeOf(R), 0);
  R.AH:=$18; R.CX:=64; R.Buf:=@buf[0];   // ask for up to 64, only 5 available
  FossilDispatch(U, R);
  Check(AX(R)=5, 'read exactly the 5 available (AX=5, not 64)');
  Check((buf[0]=Ord('A')) and (buf[4]=Ord('E')), 'buffer has A..E correct');

  writeln('== BOUNDARY: CX smaller than available (partial read) ==');
  RingClear(U.RX);
  for i:=0 to 9 do RingPut(U.RX, Ord('0')+i);  // 10 bytes waiting
  FillChar(R, SizeOf(R), 0);
  R.AH:=$18; R.CX:=4; R.Buf:=@buf[0];          // only want 4
  FossilDispatch(U, R);
  Check(AX(R)=4, 'read exactly CX=4 when more available');
  Check(U.RX.Count=6, '6 bytes remain in RX (not lost)');

  writeln('== BOUNDARY: WRITE more than TX room -> truncates to room, honest count ==');
  RingClear(U.TX);
  { fill TX to near-full: RING_SIZE-2 }
  while RingFree(U.TX) > 2 do RingPut(U.TX, 0);
  FillChar(R, SizeOf(R), 0);
  R.AH:=$19; R.CX:=10; R.Buf:=@buf[0];   // try to write 10, only 2 room
  FossilDispatch(U, R);
  Check(AX(R)=2, 'wrote only 2 (TX room), reported honestly');

  writeln('== nil buffer safety ==');
  FillChar(R, SizeOf(R), 0);
  R.AH:=$18; R.CX:=10; R.Buf:=nil;
  FossilDispatch(U, R);
  Check(AX(R)=0, 'nil buffer read -> 0, no crash');
  FillChar(R, SizeOf(R), 0);
  R.AH:=$19; R.CX:=10; R.Buf:=nil;
  FossilDispatch(U, R);
  Check(AX(R)=0, 'nil buffer write -> 0, no crash');

  writeln('== empty RX read -> 0 ==');
  RingClear(U.RX);
  FillChar(R, SizeOf(R), 0);
  R.AH:=$18; R.CX:=10; R.Buf:=@buf[0];
  FossilDispatch(U, R);
  Check(AX(R)=0, 'empty RX -> read 0');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('FOSSIL BLOCK I/O (Fn 18h/19h) - VERIFIED');
end.
