program test_transport;
{$MODE OBJFPC}{$H+}
uses NM_UART16550, NetTransport;

type
  { A fake in-memory socket link for testing — no real network. }
  TFakeLink = class(TInterfacedObject, ISocketLink)
  public
    ToRemote  : array of Byte;   // bytes we "sent" to the network
    FromRemote: array of Byte;   // bytes queued as if arriving from network
    RPos      : Integer;
    Connected : Boolean;
    function Connect(const AHost: string; APort: Word): TLinkResult;
    function Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
    function Recv(var Buf; Len: Integer; out Got: Integer): TLinkResult;
    procedure Close;
    function IsConnected: Boolean;
    procedure QueueFromRemote(const B: array of Byte);
  end;

function TFakeLink.Connect(const AHost: string; APort: Word): TLinkResult;
begin Connected := True; Result := lrOk; end;
function TFakeLink.Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
var p: PByte; i, base: Integer;
begin
  p := @Buf; base := Length(ToRemote); SetLength(ToRemote, base+Len);
  for i := 0 to Len-1 do ToRemote[base+i] := p[i];
  Sent := Len; Result := lrOk;
end;
function TFakeLink.Recv(var Buf; Len: Integer; out Got: Integer): TLinkResult;
var p: PByte; n: Integer;
begin
  p := @Buf; Got := 0;
  n := Length(FromRemote) - RPos;
  if n <= 0 then Exit(lrWouldBlock);
  if n > Len then n := Len;
  while Got < n do begin p[Got] := FromRemote[RPos]; Inc(RPos); Inc(Got); end;
  Result := lrOk;
end;
procedure TFakeLink.Close; begin Connected := False; end;
function TFakeLink.IsConnected: Boolean; begin Result := Connected; end;
procedure TFakeLink.QueueFromRemote(const B: array of Byte);
var base,i:Integer;
begin base:=Length(FromRemote); SetLength(FromRemote,base+Length(B));
  for i:=0 to High(B) do FromRemote[base+i]:=B[i]; end;

var
  U: TUart16550;
  link: TFakeLink;
  T: TNetTransport;
  pass, fail, i: Integer;
  b: Byte;
  got: array of Byte;

procedure Check(cond: Boolean; const name: string);
begin
  if cond then begin Inc(pass); writeln('  PASS: ', name); end
  else begin Inc(fail); writeln('  FAIL: ', name); end;
end;

begin
  pass := 0; fail := 0;
  UartReset(U);
  link := TFakeLink.Create;
  T := TNetTransport.Create(@U, link);

  writeln('== dial sends Telnet BINARY negotiation + sets carrier ==');
  Check(T.Dial('bbs.example.com', 23), 'dial ok');
  Check(U.Online, 'carrier up after dial (DCD set)');
  // ToRemote should contain IAC WILL BINARY (255 251 0)
  Check((Length(link.ToRemote) >= 3) and (link.ToRemote[0]=255)
        and (link.ToRemote[1]=251) and (link.ToRemote[2]=0),
        'sent IAC WILL BINARY');

  writeln('== BINARY SAFETY: all 256 byte values guest->net round-trip clean ==');
  // guest writes all 256 values to THR; pump; check ToRemote has them (0xFF doubled)
  SetLength(link.ToRemote, 0);
  for i := 0 to 255 do UartWriteReg(U, UART_THR, Byte(i));
  T.Pump;
  // reconstruct: undo IAC-doubling to verify original stream preserved
  SetLength(got, 0);
  i := 0;
  while i < Length(link.ToRemote) do
  begin
    b := link.ToRemote[i]; Inc(i);
    if (b = 255) and (i < Length(link.ToRemote)) and (link.ToRemote[i] = 255) then
      Inc(i); // skip the doubled IAC
    SetLength(got, Length(got)+1); got[High(got)] := b;
  end;
  Check(Length(got) = 256, 'all 256 bytes present after un-doubling');
  b := 0;
  for i := 0 to 255 do if got[i] <> Byte(i) then b := 1;
  Check(b = 0, 'every byte value 0..255 preserved exactly (incl 0xFF)');

  writeln('== net->guest: IAC commands filtered, data passes clean ==');
  // remote sends: IAC DO BINARY (should be answered, not delivered), then "Hi"
  link.QueueFromRemote([255,253,0, Ord('H'), Ord('i')]);
  T.Pump;
  Check(UartReadReg(U, UART_RBR) = Ord('H'), 'data byte H reached guest');
  Check(UartReadReg(U, UART_RBR) = Ord('i'), 'data byte i reached guest');
  Check(U.RX.Count = 0, 'IAC DO BINARY was filtered (not delivered as data)');

  writeln('== net->guest: escaped 0xFF (IAC IAC) delivers a single 0xFF ==');
  link.QueueFromRemote([255,255, Ord('Z')]);
  T.Pump;
  Check(UartReadReg(U, UART_RBR) = 255, 'IAC IAC -> single 0xFF data byte');
  Check(UartReadReg(U, UART_RBR) = Ord('Z'), 'Z after escaped FF');

  writeln('== link close -> carrier drops ==');
  link.Close;
  Check(not T.Pump, 'pump returns false when link closed');
  Check(not U.Online, 'carrier dropped on close');

  writeln;
  writeln('RESULT: ', pass, ' passed, ', fail, ' failed');
  if fail = 0 then writeln('TRANSPORT + TELNET BINARY SAFETY VERIFIED');
end.
