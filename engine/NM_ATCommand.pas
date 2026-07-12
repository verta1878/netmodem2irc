unit NM_ATCommand;
{ ===========================================================================
  netmodem2irc — Hayes AT command emulation (NT-branch, user-mode)
  ---------------------------------------------------------------------------
  Re-creates the AT command layer that Dedrick's VxD implemented in
  ParseATCommand / ATCommand (NETMODEM.ASM), per docs LAYER_A_SPEC.md §4.

  This is where the MODEM METAPHOR MEETS THE NETWORK: when a BBS door (or the
  guest) issues `ATDT<host>`, we don't dial a phone — we open a TCP/Telnet
  connection through NetTransport. On success we emit CONNECT; the door then
  talks to the remote BBS as if over a modem.

  Command bytes the guest "types" arrive via ATFeed (from the UART TX path in
  command mode). Result codes and echoes go back via the UART RX path so the
  guest "sees" them, exactly like a real modem.

  Result-code strings verified against NETMODEM.ASM (szRING, szNOCARRIER,
  szCONNECT_300 = "CONNECT 300/ARQ/TELNET", etc.).

  State: command mode (AT parsing) vs online mode (bytes pass to transport).
  The +++ escape sequence returns from online to command mode (with guard time,
  handled by the caller's timer — here we recognize the sequence).
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, NM_UART16550, NetTransport;

type
  TModemMode = (mmCommand, mmOnline);

  { Emits a result to the guest (echo/result codes go into the UART RX ring). }
  TATModem = class
  private
    FUart : PUart16550;
    FTrans: TNetTransport;
    FMode : TModemMode;
    FLine : string;           // accumulating command line
    FEcho : Boolean;          // ATE1 = echo on
    FVerbose : Boolean;       // ATV1 = word result codes
    FQuiet : Boolean;         // ATQ1 = suppress result codes
    FDefaultPort : Word;
    procedure EmitStr(const S: string);
    procedure EmitResult(const AWord: string; ANum: Integer);
    procedure DoCommandLine(const ALine: string);
    function  ParseDial(const AArg: string; out AHost: string; out APort: Word): Boolean;
  public
    constructor Create(AUart: PUart16550; ATrans: TNetTransport);
    { Feed one byte the guest "typed" (from UART TX in command mode). }
    procedure ATFeed(B: Byte);
    { Called each pump: if online, returns True (bytes flow via transport);
      if command mode, AT bytes are consumed here. }
    { Force online mode (used for INBOUND connections — no AT dial needed). }
    procedure ForceOnline;
    property Mode: TModemMode read FMode;
    property DefaultPort: Word read FDefaultPort write FDefaultPort;
  end;

const
  { result code numbers (Hayes standard) }
  RC_OK        = 0;
  RC_CONNECT   = 1;
  RC_RING      = 2;
  RC_NOCARRIER = 3;
  RC_ERROR     = 4;
  RC_NODIALTONE= 6;
  RC_BUSY      = 7;

implementation

constructor TATModem.Create(AUart: PUart16550; ATrans: TNetTransport);
begin
  inherited Create;
  FUart := AUart;
  FTrans := ATrans;
  FMode := mmCommand;
  FLine := '';
  FEcho := True;       // modems default to echo on in command mode
  FVerbose := True;    // default V1 = word codes
  FQuiet := False;
  FDefaultPort := 23;  // telnet
end;

{ Push a string to the guest by feeding each byte into the UART RX ring. }
procedure TATModem.EmitStr(const S: string);
var i: Integer;
begin
  for i := 1 to Length(S) do
    UartNetToGuest(FUart^, Byte(S[i]));
end;

procedure TATModem.EmitResult(const AWord: string; ANum: Integer);
begin
  if FQuiet then Exit;
  if FVerbose then
    EmitStr(#13#10 + AWord + #13#10)
  else
    EmitStr(IntToStr(ANum) + #13);
end;

{ Parse ATD argument into host + port. Accepts:
    ATDT bbs.example.com        -> host, default port 23
    ATDT bbs.example.com:2323   -> host, port 2323
  The 'T'/'P' (tone/pulse) prefix is ignored (meaningless over TCP). }
function TATModem.ParseDial(const AArg: string; out AHost: string; out APort: Word): Boolean;
var
  s: string;
  cp: Integer;
begin
  s := AArg;
  { strip a leading T or P (tone/pulse dial modifier) }
  if (Length(s) > 0) and ((UpCase(s[1]) = 'T') or (UpCase(s[1]) = 'P')) then
    Delete(s, 1, 1);
  s := Trim(s);
  if s = '' then Exit(False);
  APort := FDefaultPort;
  cp := Pos(':', s);
  if cp > 0 then
  begin
    AHost := Copy(s, 1, cp-1);
    APort := Word(StrToIntDef(Copy(s, cp+1, Length(s)), FDefaultPort));
  end
  else
    AHost := s;
  Result := AHost <> '';
end;

procedure TATModem.DoCommandLine(const ALine: string);
var
  u: string;
  arg, host: string;
  port: Word;
  i: Integer;
  c: Char;
begin
  u := Trim(ALine);
  if u = '' then Exit;
  { must start with AT (case-insensitive) }
  if (Length(u) < 2) or (UpCase(u[1]) <> 'A') or (UpCase(u[2]) <> 'T') then
  begin
    EmitResult('ERROR', RC_ERROR);
    Exit;
  end;
  Delete(u, 1, 2);   // strip "AT"

  { Bare "AT" -> OK }
  if u = '' then
  begin
    EmitResult('OK', RC_OK);
    Exit;
  end;

  { Dial command: D[T/P]<host> — handle first since it consumes the rest }
  if (Length(u) >= 1) and (UpCase(u[1]) = 'D') then
  begin
    arg := Copy(u, 2, Length(u));
    if ParseDial(arg, host, port) then
    begin
      if FTrans.Dial(host, port) then
      begin
        FMode := mmOnline;
        EmitResult('CONNECT 300/ARQ/TELNET', RC_CONNECT);
      end
      else
        EmitResult('NO CARRIER', RC_NOCARRIER);
    end
    else
      EmitResult('NO DIAL TONE', RC_NODIALTONE);
    Exit;
  end;

  { Simple single-letter commands (subset that makes sense over TCP). }
  i := 1;
  while i <= Length(u) do
  begin
    c := UpCase(u[i]);
    case c of
      'E': begin  { echo } if (i<Length(u)) and (u[i+1]='0') then FEcho:=False else FEcho:=True; Inc(i); end;
      'V': begin  { verbose } if (i<Length(u)) and (u[i+1]='0') then FVerbose:=False else FVerbose:=True; Inc(i); end;
      'Q': begin  { quiet } if (i<Length(u)) and (u[i+1]='0') then FQuiet:=False else FQuiet:=True; Inc(i); end;
      'H': begin  { hook: H0 = hang up } FTrans.HangUp; FMode:=mmCommand; Inc(i); end;
      'A': begin  { answer — no inbound in dial mode; ack } end;
      'Z': begin  { reset } FEcho:=True; FVerbose:=True; FQuiet:=False; FTrans.HangUp; FMode:=mmCommand; end;
      'O': begin  { return online } if FTrans.BinaryMode or True then FMode:=mmOnline; end;
      '0'..'9': ; { parameter digits consumed by their command }
    end;
    Inc(i);
  end;
  EmitResult('OK', RC_OK);
end;

procedure TATModem.ATFeed(B: Byte);
begin
  if FMode = mmOnline then Exit;   // online: bytes go to transport, not here

  { command mode: echo if enabled }
  if FEcho then
    UartNetToGuest(FUart^, B);

  case B of
    13:  begin                 // CR ends the command line
           DoCommandLine(FLine);
           FLine := '';
         end;
    10:  ;                      // LF ignored
    8, 127: if Length(FLine) > 0 then SetLength(FLine, Length(FLine)-1); // backspace
  else
    if Length(FLine) < 128 then
      FLine := FLine + Chr(B);
  end;
end;

procedure TATModem.ForceOnline;
begin
  FMode := mmOnline;
end;

end.