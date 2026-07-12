unit NM_Config;
{ ===========================================================================
  netmodem2irc — configuration (per-node comport/host/port)
  ---------------------------------------------------------------------------
  Turns netmodem2irc from "constructed in code" into "configured and deployable."
  A config is a list of node entries; each says: which comport/node index, and
  the server host+port that node's link connects to.

  Format (simple, BBS-era INI-like, one node per line):
      node <index> <host> <port>
  e.g.
      node 3 bbs.example.com 23
      node 4 chat.example.org 6667
  Lines that are blank or start with ';' or '#' are comments.

  DESIGN: parsing/validation is plain Pascal, host-testable. Every field is
  RANGE-CHECKED on load (structural-sight discipline: a config value is untrusted
  input crossing a boundary, same as a wire value — index 0..NM_MAX_NODES-1,
  port 1..65535, host non-empty). Bad lines are reported, not silently accepted.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, NM_Node;   { for NM_MAX_NODES }

type
  { one configured node }
  TNodeConfig = record
    NodeIndex : Integer;    // comport/node, 0 .. NM_MAX_NODES-1
    Host      : string;     // server host to connect to
    Port      : Word;       // server port, 1..65535
  end;

  { the whole configuration: a set of node entries }
  TNetModemConfig = class
  private
    FNodes : array of TNodeConfig;
    FErrors: array of string;   { human-readable problems found during parse }
    function FindNode(AIndex: Integer): Integer;   { -1 if absent }
  public
    constructor Create;

    { Parse one config line. Returns True if it added/updated a node, False if the
      line was a comment/blank (not an error) or invalid (an error is recorded).
      Kept public so it's unit-testable line by line. }
    function ParseLine(const ALine: string): Boolean;

    { Parse a whole config text (newline-separated). Returns the number of node
      entries successfully loaded. Errors accumulate in Errors. }
    function ParseText(const AText: string): Integer;

    { Look up a node's config by index; returns True and fills ACfg if present. }
    function GetNode(AIndex: Integer; out ACfg: TNodeConfig): Boolean;

    function NodeCount: Integer;
    function NodeByPosition(APos: Integer; out ACfg: TNodeConfig): Boolean;
    function ErrorCount: Integer;
    function ErrorText(APos: Integer): string;

    { True if the whole config parsed with no errors. }
    function IsValid: Boolean;
  end;

implementation

constructor TNetModemConfig.Create;
begin
  inherited Create;
  SetLength(FNodes, 0);
  SetLength(FErrors, 0);
end;

function TNetModemConfig.FindNode(AIndex: Integer): Integer;
var i: Integer;
begin
  Result := -1;
  for i := 0 to High(FNodes) do
    if FNodes[i].NodeIndex = AIndex then
    begin
      Result := i;
      Exit;
    end;
end;

function TNetModemConfig.ParseLine(const ALine: string): Boolean;
var
  s, keyword, host: string;
  parts: array of string;
  p, idx, prt: Integer;
  code: Integer;
  n: Integer;

  procedure PushErr(const Msg: string);
  begin
    SetLength(FErrors, Length(FErrors) + 1);
    FErrors[High(FErrors)] := Msg;
  end;

  { split on whitespace runs }
  procedure Split(const line: string);
  var i: Integer; cur: string;
  begin
    SetLength(parts, 0);
    cur := '';
    for i := 1 to Length(line) do
    begin
      if (line[i] = ' ') or (line[i] = #9) then
      begin
        if cur <> '' then
        begin
          SetLength(parts, Length(parts)+1);
          parts[High(parts)] := cur;
          cur := '';
        end;
      end
      else
        cur := cur + line[i];
    end;
    if cur <> '' then
    begin
      SetLength(parts, Length(parts)+1);
      parts[High(parts)] := cur;
    end;
  end;

begin
  Result := False;
  s := Trim(ALine);
  { comment or blank -> not an error, just nothing to add }
  if (s = '') or (s[1] = ';') or (s[1] = '#') then Exit;

  Split(s);
  if Length(parts) = 0 then Exit;

  keyword := LowerCase(parts[0]);
  if keyword <> 'node' then
  begin
    PushErr('unknown keyword: ' + parts[0]);
    Exit;
  end;

  if Length(parts) <> 4 then
  begin
    PushErr('expected: node <index> <host> <port>  (got ' +
            IntToStr(Length(parts)) + ' fields): ' + s);
    Exit;
  end;

  { field 1: node index — RANGE-CHECKED 0..NM_MAX_NODES-1 }
  Val(parts[1], idx, code);
  if code <> 0 then
  begin
    PushErr('node index not a number: ' + parts[1]);
    Exit;
  end;
  if (idx < 0) or (idx >= NM_MAX_NODES) then
  begin
    PushErr('node index ' + IntToStr(idx) + ' out of range (0..' +
            IntToStr(NM_MAX_NODES-1) + ')');
    Exit;
  end;

  { field 2: host — must be non-empty }
  host := parts[2];
  if host = '' then
  begin
    PushErr('empty host for node ' + IntToStr(idx));
    Exit;
  end;

  { field 3: port — RANGE-CHECKED 1..65535 }
  Val(parts[3], prt, code);
  if code <> 0 then
  begin
    PushErr('port not a number: ' + parts[3]);
    Exit;
  end;
  if (prt < 1) or (prt > 65535) then
  begin
    PushErr('port ' + IntToStr(prt) + ' out of range (1..65535) for node ' +
            IntToStr(idx));
    Exit;
  end;

  { valid — add or update the node }
  p := FindNode(idx);
  if p < 0 then
  begin
    SetLength(FNodes, Length(FNodes) + 1);
    p := High(FNodes);
  end;
  FNodes[p].NodeIndex := idx;
  FNodes[p].Host := host;
  FNodes[p].Port := Word(prt);
  Result := True;
end;

function TNetModemConfig.ParseText(const AText: string): Integer;
var
  i, lineStart: Integer;
  line: string;
begin
  Result := 0;
  lineStart := 1;
  for i := 1 to Length(AText) + 1 do
  begin
    if (i > Length(AText)) or (AText[i] = #10) or (AText[i] = #13) then
    begin
      if i > lineStart then
      begin
        line := Copy(AText, lineStart, i - lineStart);
        if ParseLine(line) then Inc(Result);
      end;
      lineStart := i + 1;
    end;
  end;
end;

function TNetModemConfig.GetNode(AIndex: Integer; out ACfg: TNodeConfig): Boolean;
var p: Integer;
begin
  p := FindNode(AIndex);
  Result := p >= 0;
  if Result then ACfg := FNodes[p];
end;

function TNetModemConfig.NodeCount: Integer;
begin
  Result := Length(FNodes);
end;

function TNetModemConfig.NodeByPosition(APos: Integer; out ACfg: TNodeConfig): Boolean;
begin
  Result := (APos >= 0) and (APos <= High(FNodes));
  if Result then ACfg := FNodes[APos];
end;

function TNetModemConfig.ErrorCount: Integer;
begin
  Result := Length(FErrors);
end;

function TNetModemConfig.ErrorText(APos: Integer): string;
begin
  if (APos >= 0) and (APos <= High(FErrors)) then
    Result := FErrors[APos]
  else
    Result := '';
end;

function TNetModemConfig.IsValid: Boolean;
begin
  Result := Length(FErrors) = 0;
end;

end.
