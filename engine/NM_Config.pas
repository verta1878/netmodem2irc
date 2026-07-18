unit NM_Config;
{ ===========================================================================
  netmodem2irc — configuration (per-node NetModem settings)
  ---------------------------------------------------------------------------
  Matches the original NetModem/32 CPL configuration 1:1.
  All per-node fields from TRegComportStruct are represented.

  Format (plain text, keyword=value per node):
      node <index> comport <n> baud <rate> mode <fossil|uart> port <n>
                   base <hex> buffer <n> alwaysactive <0|1>
                   lockedbaud <0|1> timeslice <0|1> enabled <0|1>

  Shorthand (defaults: baud=38400 mode=fossil port=23 base=$03E8
             buffer=2048 alwaysactive=0 lockedbaud=1 timeslice=1 enabled=1):
      node 1 comport 3

  Connection targets come from AT dial commands (ATDT host:port) at runtime.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, NM_Node;

type
  TNMMode = (nmFossil, nmUart);

  TNodeConfig = record
    NodeIndex      : Integer;    // node slot, 0 .. NM_MAX_NODES-1
    ComPort        : Integer;    // virtual COM port, 1..99
    Baud           : LongInt;    // baud rate
    Mode           : TNMMode;    // FOSSIL or plain UART
    Enabled        : Boolean;    // node active
    InternetPort   : Word;       // TCP listen port (default 23)
    BaseAddress    : Word;       // I/O base address (hex, e.g. $03E8)
    BufferSize     : Word;       // RX/TX buffer size in bytes
    AlwaysActive   : Boolean;    // keep node active without connection
    LockedBaudRate : Boolean;    // lock baud (no auto-negotiate)
    ManageTimeSlice: Boolean;    // yield CPU when idle
  end;

  TNMConfig = class
  private
    FNodes : array of TNodeConfig;
    FErrors: array of string;
    function FindNode(AIndex: Integer): Integer;
  public
    constructor Create;
    function ParseLine(const ALine: string): Boolean;
    function ParseText(const AText: string): Integer;
    function GetNode(AIndex: Integer; out ACfg: TNodeConfig): Boolean;
    function NodeCount: Integer;
    function NodeByPosition(APos: Integer; out ACfg: TNodeConfig): Boolean;
    function ErrorCount: Integer;
    function ErrorText(APos: Integer): string;
    function IsValid: Boolean;
  end;

function ValidBaud(B: LongInt): Boolean;
function DefaultNodeConfig: TNodeConfig;
function CreateDefaultConfig: TNMConfig;

implementation

function ValidBaud(B: LongInt): Boolean;
begin
  Result := (B = 300) or (B = 1200) or (B = 2400) or (B = 9600) or
            (B = 14400) or (B = 16800) or (B = 19200) or (B = 21600) or
            (B = 28800) or (B = 33600) or (B = 38400) or (B = 57600) or
            (B = 64000) or (B = 115200);
end;

function DefaultNodeConfig: TNodeConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.NodeIndex := 1;
  Result.ComPort := 3;
  Result.Baud := 38400;
  Result.Mode := nmFossil;
  Result.Enabled := True;
  Result.InternetPort := 23;
  Result.BaseAddress := $03E8;
  Result.BufferSize := 2048;
  Result.AlwaysActive := False;
  Result.LockedBaudRate := True;
  Result.ManageTimeSlice := True;
end;

function CreateDefaultConfig: TNMConfig;
begin
  Result := TNMConfig.Create;
  Result.ParseLine('node 1 comport 3 baud 38400 mode fossil port 23');
end;

constructor TNMConfig.Create;
begin
  inherited Create;
  SetLength(FNodes, 0);
  SetLength(FErrors, 0);
end;

function TNMConfig.FindNode(AIndex: Integer): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to High(FNodes) do
    if FNodes[i].NodeIndex = AIndex then begin Result := i; Exit; end;
end;

function TNMConfig.ParseLine(const ALine: string): Boolean;
var
  s: string;
  parts: array of string;
  p, idx, com, code, ival: Integer;
  cfg: TNodeConfig;

  procedure PushErr(const Msg: string);
  begin
    SetLength(FErrors, Length(FErrors) + 1);
    FErrors[High(FErrors)] := Msg;
  end;

  procedure Split(const line: string);
  var i: Integer; cur: string;
  begin
    SetLength(parts, 0); cur := '';
    for i := 1 to Length(line) do
      if (line[i] = ' ') or (line[i] = #9) then begin
        if cur <> '' then begin
          SetLength(parts, Length(parts)+1); parts[High(parts)] := cur; cur := '';
        end;
      end else cur := cur + line[i];
    if cur <> '' then begin
      SetLength(parts, Length(parts)+1); parts[High(parts)] := cur;
    end;
  end;

begin
  Result := False;
  s := Trim(ALine);
  if (s = '') or (s[1] = ';') or (s[1] = '#') then Exit;

  Split(s);
  if Length(parts) = 0 then Exit;

  if LowerCase(parts[0]) <> 'node' then
  begin PushErr('unknown keyword: ' + parts[0]); Exit; end;

  if Length(parts) < 4 then
  begin PushErr('expected: node <index> comport <n> [...]: ' + s); Exit; end;

  { node index }
  Val(parts[1], idx, code);
  if code <> 0 then begin PushErr('node index not a number: ' + parts[1]); Exit; end;
  if (idx < 0) or (idx >= NM_MAX_NODES) then
  begin PushErr('node index ' + IntToStr(idx) + ' out of range (0..' +
                IntToStr(NM_MAX_NODES-1) + ')'); Exit; end;

  { comport keyword + value }
  if LowerCase(parts[2]) <> 'comport' then
  begin PushErr('expected "comport" after node index: ' + s); Exit; end;
  Val(parts[3], com, code);
  if code <> 0 then begin PushErr('comport not a number: ' + parts[3]); Exit; end;
  if (com < 1) or (com > 99) then
  begin PushErr('comport ' + IntToStr(com) + ' out of range (1..99)'); Exit; end;

  { start with defaults, then override }
  cfg := DefaultNodeConfig;
  cfg.NodeIndex := idx;
  cfg.ComPort := com;

  { parse optional keyword pairs }
  p := 4;
  while p <= High(parts) do
  begin
    if (LowerCase(parts[p]) = 'baud') and (p+1 <= High(parts)) then
    begin
      Val(parts[p+1], cfg.Baud, code);
      if (code <> 0) or (not ValidBaud(cfg.Baud)) then
      begin PushErr('invalid baud rate: ' + parts[p+1]); Exit; end;
      Inc(p, 2);
    end
    else if (LowerCase(parts[p]) = 'mode') and (p+1 <= High(parts)) then
    begin
      if LowerCase(parts[p+1]) = 'fossil' then cfg.Mode := nmFossil
      else if LowerCase(parts[p+1]) = 'uart' then cfg.Mode := nmUart
      else begin PushErr('invalid mode: ' + parts[p+1]); Exit; end;
      Inc(p, 2);
    end
    else if (LowerCase(parts[p]) = 'port') and (p+1 <= High(parts)) then
    begin
      Val(parts[p+1], ival, code);
      if (code <> 0) or (ival < 1) or (ival > 65535) then
      begin PushErr('invalid port: ' + parts[p+1]); Exit; end;
      cfg.InternetPort := Word(ival);
      Inc(p, 2);
    end
    else if (LowerCase(parts[p]) = 'base') and (p+1 <= High(parts)) then
    begin
      { accept hex with $ prefix or plain decimal }
      Val(parts[p+1], ival, code);
      if code <> 0 then begin PushErr('invalid base address: ' + parts[p+1]); Exit; end;
      cfg.BaseAddress := Word(ival);
      Inc(p, 2);
    end
    else if (LowerCase(parts[p]) = 'buffer') and (p+1 <= High(parts)) then
    begin
      Val(parts[p+1], ival, code);
      if (code <> 0) or (ival < 1024) or (ival > 8192) then
      begin PushErr('invalid buffer size: ' + parts[p+1] + ' (1024..8192)'); Exit; end;
      cfg.BufferSize := Word(ival);
      Inc(p, 2);
    end
    else if (LowerCase(parts[p]) = 'alwaysactive') and (p+1 <= High(parts)) then
    begin cfg.AlwaysActive := parts[p+1] = '1'; Inc(p, 2); end
    else if (LowerCase(parts[p]) = 'lockedbaud') and (p+1 <= High(parts)) then
    begin cfg.LockedBaudRate := parts[p+1] = '1'; Inc(p, 2); end
    else if (LowerCase(parts[p]) = 'timeslice') and (p+1 <= High(parts)) then
    begin cfg.ManageTimeSlice := parts[p+1] = '1'; Inc(p, 2); end
    else if (LowerCase(parts[p]) = 'enabled') and (p+1 <= High(parts)) then
    begin cfg.Enabled := parts[p+1] = '1'; Inc(p, 2); end
    else
    begin PushErr('unexpected token: ' + parts[p]); Exit; end;
  end;

  { store }
  p := FindNode(idx);
  if p < 0 then begin
    SetLength(FNodes, Length(FNodes) + 1);
    p := High(FNodes);
  end;
  FNodes[p] := cfg;
  Result := True;
end;

function TNMConfig.ParseText(const AText: string): Integer;
var i, lineStart: Integer; line: string;
begin
  Result := 0; lineStart := 1;
  for i := 1 to Length(AText) + 1 do
    if (i > Length(AText)) or (AText[i] = #10) or (AText[i] = #13) then begin
      if i > lineStart then begin
        line := Copy(AText, lineStart, i - lineStart);
        if ParseLine(line) then Inc(Result);
      end;
      lineStart := i + 1;
    end;
end;

function TNMConfig.GetNode(AIndex: Integer; out ACfg: TNodeConfig): Boolean;
var pp: Integer;
begin pp := FindNode(AIndex); Result := pp >= 0; if Result then ACfg := FNodes[pp]; end;

function TNMConfig.NodeCount: Integer;
begin Result := Length(FNodes); end;

function TNMConfig.NodeByPosition(APos: Integer; out ACfg: TNodeConfig): Boolean;
begin
  Result := (APos >= 0) and (APos <= High(FNodes));
  if Result then ACfg := FNodes[APos];
end;

function TNMConfig.ErrorCount: Integer;
begin Result := Length(FErrors); end;

function TNMConfig.ErrorText(APos: Integer): string;
begin
  if (APos >= 0) and (APos <= High(FErrors)) then Result := FErrors[APos]
  else Result := '';
end;

function TNMConfig.IsValid: Boolean;
begin Result := Length(FErrors) = 0; end;

end.
