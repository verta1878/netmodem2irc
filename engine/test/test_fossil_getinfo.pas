program test_fossil_getinfo;
{$MODE OBJFPC}{$H+}
{ Fn 1Bh GET_INFO: fills the FOSSIL info struct into the caller's ES:DI buffer,
  respecting CX (buffer size). Boundary: CX smaller than the struct must truncate,
  never overflow the caller's buffer. }
uses SysUtils, NM_UART16550, NM_Fossil;
var
  U: TUart16550; R: TFossilRegs; pass,fail: Integer;
  info: TFossilInfo;
  smallbuf: array[0..3] of Byte;
  guard: array[0..7] of Byte;
procedure Check(c:Boolean;const nm:string);
begin if c then begin Inc(pass);writeln('  PASS: ',nm);end else begin Inc(fail);writeln('  FAIL: ',nm);end;end;
function AX(const RR:TFossilRegs):Word; begin AX := (RR.AH shl 8) or RR.AL; end;
begin
  pass:=0;fail:=0;
  UartReset(U);

  writeln('== Fn 1Bh fills the full struct when buffer is big enough ==');
  FillChar(info, SizeOf(info), $EE);
  FillChar(R, SizeOf(R), 0);
  R.AH:=$1B; R.CX:=SizeOf(TFossilInfo); R.Buf:=@info;
  FossilDispatch(U, R);
  Check(AX(R)=SizeOf(TFossilInfo), 'AX = full struct size transferred');
  Check(info.StrSiz=SizeOf(TFossilInfo), 'StrSiz filled correctly');
  Check((info.MajVer=5) and (info.MinVer=0), 'version 5.0 reported');
  Check(info.IBufr=info.OBufr, 'in/out buffer sizes reported');
  writeln('     (StrSiz=',info.StrSiz,' Maj=',info.MajVer,' IBufr=',info.IBufr,
          ' IFree=',info.IFree,')');

  writeln('== BOUNDARY: CX smaller than struct -> truncate, do NOT overflow ==');
  FillChar(smallbuf, SizeOf(smallbuf), 0);
  FillChar(guard, SizeOf(guard), $99);   // sentinel after the small buffer
  FillChar(R, SizeOf(R), 0);
  R.AH:=$1B; R.CX:=4; R.Buf:=@smallbuf[0];   // only 4 bytes of room
  FossilDispatch(U, R);
  Check(AX(R)=4, 'AX = 4 (only CX bytes transferred, not full struct)');
  Check(guard[0]=$99, 'guard byte intact — no buffer overflow past CX');

  writeln('== no buffer -> falls back to CX+signature in registers ==');
  FillChar(R, SizeOf(R), 0);
  R.AH:=$1B; R.CX:=0; R.Buf:=nil;
  FossilDispatch(U, R);
  Check(AX(R)=FOSSIL_SIGNATURE, 'signature in AX when no buffer');
  Check(R.CX=RING_SIZE, 'buffer size in CX when no buffer');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('FOSSIL GET_INFO (Fn 1Bh) - VERIFIED');
end.
