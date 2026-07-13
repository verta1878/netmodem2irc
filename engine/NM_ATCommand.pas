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
    { extended &-command settings (from the original ATCOMNDS.TXT) }
    FDCDMode : Byte;          // &C: 0=override(always on), 1=normal
    FDTRMode : Byte;          // &D: 0=ignore, 2=normal(hang up on DTR drop)
    FSoftFlow: Byte;          // &I: 0=off, 1=both, 2=local
    FHardFlow: Byte;          // &R: 1=ignore RTS, 2=data on RTS
    FDSRMode : Byte;          // &S: 0=always on, 1=follows DTR
    FBreakHandling: Byte;     // &Y: 0/1/2/3 break behavior
    FVerbose : Boolean;       // ATV1 = word result codes
    FQuiet : Boolean;         // ATQ1 = suppress result codes
    FDefaultPort : Word;
    procedure EmitStr(const S: string);
    procedure EmitResult(const AWord: string; ANum: Integer);
    procedure DoAmpersand(ACmd: Char; AParam: Byte);
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
    { Emit RING to the guest (an incoming call is present). A BBS answers with
      ATA, or auto-answers per S0. }
    procedure SignalRing;
    property Mode: TModemMode read FMode;
    property DefaultPort: Word read FDefaultPort write FDefaultPort;
    { test accessor for the private dial parser (unit tests) }
    function TestParseDial(const AArg: string; out AHost: string; out APort: Word): Boolean;
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
  FEcho := True;
  FDCDMode := 1; FDTRMode := 2; FSoftFlow := 0;   { the * defaults from ATCOMNDS }
  FHardFlow := 2; FDSRMode := 0; FBreakHandling := 1;       // modems default to echo on in command mode
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
  prt: LongInt;   // wide parse before range-check (avoid Word wrap)
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
    { Parse the port into a WIDE signed int first, then range-check 1..65535.
      Do NOT cast straight to Word: Word() wraps silently (e.g. 70000 -> 4464),
      which would connect to a different port than dialled. Reject out-of-range
      by falling back to the default, same discipline as the config parser. }
    prt := StrToIntDef(Copy(s, cp+1, Length(s)), FDefaultPort);
    if (prt >= 1) and (prt <= 65535) then
      APort := Word(prt)
    else
      APort := FDefaultPort;   // out-of-range port -> default, never a wrapped value
  end
  else
    AHost := s;
  Result := AHost <> '';
end;

function TATModem.TestParseDial(const AArg: string; out AHost: string; out APort: Word): Boolean;
begin
  Result := ParseDial(AArg, AHost, APort);
end;

{ Return the numeric parameter at position p (0 if none/not a digit). }
function AmpParam(const s: string; p: Integer): Byte;
begin
  if (p >= 1) and (p <= Length(s)) and (s[p] in ['0'..'9']) then
    AmpParam := Ord(s[p]) - Ord('0')
  else
    AmpParam := 0;
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
      '&': begin  { extended commands: &C, &D, &I, &R, &S, &Y — record the setting }
             if i < Length(u) then
             begin
               DoAmpersand(UpCase(u[i+1]), AmpParam(u, i+2));
               Inc(i);              // skip the letter after &
               if (i < Length(u)) and (u[i+1] in ['0'..'9']) then Inc(i); // skip digit
             end;
           end;
      '0'..'9': ; { parameter digits consumed by their command }
    end;
    Inc(i);
  end;
  EmitResult('OK', RC_OK);
end;

procedure TATModem.DoAmpersand(ACmd: Char; AParam: Byte);
begin
  { Record the extended-command settings. Over a Telnet bridge most are
    cosmetic (no real RS-232 lines), but faithful modems ACCEPT them and a BBS
    init string like AT&C1&D2 must succeed. &D and &C affect our carrier/hangup
    semantics; the rest are stored for completeness. }
  case ACmd of
    'C': FDCDMode := AParam;        // Data Carrier Detect mode
    'D': FDTRMode := AParam;        // Data Terminal Ready mode
    'I': FSoftFlow := AParam;       // software (XON/XOFF) flow control
    'R': FHardFlow := AParam;       // hardware (RTS) flow control
    'S': FDSRMode := AParam;        // Data Set Ready mode
    'Y': FBreakHandling := AParam;  // break handling
    'F': begin FEcho:=True; FVerbose:=True; FQuiet:=False; end; // &F = factory defaults
  end;
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

procedure TATModem.SignalRing;
begin
  { emit the RING result code to the guest, exactly as a modem does on an
    incoming call. RC_RING = 2 (Hayes standard). }
  EmitResult('RING', RC_RING);
end;

end.
