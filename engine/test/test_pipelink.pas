program test_pipelink;
{$MODE OBJFPC}{$H+}
uses SysUtils, NM_UART16550, NetTransport, NM_NamedPipeLink;

type
  { fake in-memory pipe backend: simulates the driver on the other end }
  TFakePipe = class(TInterfacedObject, IPipeBackend)
  public
    Opened: Boolean;
    ToDriver: array of Byte;              // what our side wrote (driver would read)
    FromDriver: array of Byte; FDPos: Integer;  // what driver "sent" us
    function Open(const APipeName: string): Boolean;
    function WriteBytes(const Buf; Len: Integer; out Written: Integer): Boolean;
    function ReadBytes(var Buf; Len: Integer; out ReadCount: Integer): Boolean;
    procedure CloseBackend; function IsOpen: Boolean;
    procedure DriverSends(const B: array of Byte);
  end;

function TFakePipe.Open(const APipeName: string): Boolean;
begin Opened := True; Result := True; end;
function TFakePipe.WriteBytes(const Buf; Len: Integer; out Written: Integer): Boolean;
var p: PByte; i, base: Integer;
begin
  if not Opened then Exit(False);
  p := @Buf; base := Length(ToDriver); SetLength(ToDriver, base+Len);
  for i := 0 to Len-1 do ToDriver[base+i] := p[i];
  Written := Len; Result := True;
end;
function TFakePipe.ReadBytes(var Buf; Len: Integer; out ReadCount: Integer): Boolean;
var p: PByte; n: Integer;
begin
  if not Opened then Exit(False);
  p := @Buf; ReadCount := 0;
  n := Length(FromDriver) - FDPos;
  if n <= 0 then Exit(True);   // open, nothing available (non-blocking)
  if n > Len then n := Len;
  while ReadCount < n do begin p[ReadCount] := FromDriver[FDPos]; Inc(FDPos); Inc(ReadCount); end;
  Result := True;
end;
procedure TFakePipe.CloseBackend; begin Opened := False; end;
function TFakePipe.IsOpen: Boolean; begin Result := Opened; end;
procedure TFakePipe.DriverSends(const B: array of Byte);
var base,i:Integer;
begin base:=Length(FromDriver); SetLength(FromDriver,base+Length(B));
  for i:=0 to High(B) do FromDriver[base+i]:=B[i]; end;

var
  fake: TFakePipe;
  ifake: IPipeBackend;
  link: TNamedPipeLink;
  ilink: ISocketLink;
  pass, fail, i, n, j: Integer;
  buf: array[0..63] of Byte;
  lr: TLinkResult;

procedure Check(cond: Boolean; const name: string);
begin
  if cond then begin Inc(pass); writeln('  PASS: ',name); end
  else begin Inc(fail); writeln('  FAIL: ',name); end;
end;

begin
  pass:=0; fail:=0;
  fake := TFakePipe.Create;
  ifake := fake;
  link := TNamedPipeLink.Create(ifake, '\\.\pipe\netmodem-node3');
  ilink := link;

  writeln('== connect opens the pipe ==');
  Check(ilink.Connect('', 0) = lrOk, 'connect returns lrOk');
  Check(ilink.IsConnected, 'IsConnected true after connect');
  Check(fake.Opened, 'backend pipe opened');

  writeln('== send: bytes go toward the driver ==');
  buf[0] := Ord('A'); buf[1] := Ord('T'); buf[2] := 13;
  Check(ilink.Send(buf, 3, n) = lrOk, 'send ok');
  Check(n = 3, 'sent 3 bytes');
  Check((Length(fake.ToDriver)=3) and (fake.ToDriver[0]=Ord('A'))
        and (fake.ToDriver[1]=Ord('T')) and (fake.ToDriver[2]=13),
        'driver side received AT<CR>');

  writeln('== recv: non-blocking when nothing available ==');
  lr := ilink.Recv(buf, SizeOf(buf), n);
  Check((lr = lrWouldBlock) and (n = 0), 'recv lrWouldBlock when pipe empty');

  writeln('== recv: driver-sent bytes arrive ==');
  fake.DriverSends([Ord('O'), Ord('K'), 13, 10]);
  lr := ilink.Recv(buf, SizeOf(buf), n);
  Check(lr = lrOk, 'recv lrOk when data present');
  Check(n = 4, 'got 4 bytes');
  Check((buf[0]=Ord('O')) and (buf[1]=Ord('K')), 'received OK from driver');

  writeln('== binary safety: all 256 values pass through the pipe link clean ==');
  SetLength(fake.FromDriver, 0); fake.FDPos := 0;
  for i := 0 to 255 do fake.DriverSends([Byte(i)]);
  n := 0; i := 0;
  // drain in chunks
  repeat
    lr := ilink.Recv(buf, SizeOf(buf), n);
    for j := 0 to n-1 do
    begin
      if buf[j] <> Byte(i) then fail := fail + 1000; // flag mismatch
      Inc(i);
    end;
  until (lr <> lrOk) or (i >= 256);
  Check(i = 256, 'all 256 byte values received through pipe link');

  writeln('== close drops connection ==');
  ilink.Close;
  Check(not ilink.IsConnected, 'IsConnected false after close');
  Check(ilink.Send(buf, 1, n) = lrClosed, 'send after close -> lrClosed');

  writeln;
  writeln('RESULT: ',pass,' passed, ',fail,' failed');
  if fail=0 then writeln('NAMED PIPE LINK VERIFIED');
end.
