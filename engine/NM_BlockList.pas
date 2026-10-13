{ ===========================================================================
  netmodem2irc - part of the NetModem/32 revival
  Copyright (C) 2025-2026 Antonio Rico (Reapern66 / verta1878)

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
  =========================================================================== }

unit NM_BlockList;
{ ===========================================================================
  IP-based allow/block list for incoming connections.
  Checked before RING — blocked IPs get DisplayBlockedFile and disconnect.
  Forwarded IPs get redirected to a different host:port.

  File: BLOCKLIST.DAT (CSV: action,pattern,forward_host,forward_port,comment)
  Actions: ALLOW, BLOCK, FORWARD
  Patterns: exact IP, wildcard (192.168.*), CIDR (10.0.0.0/8)
  =========================================================================== }
{$MODE OBJFPC}{$H+}
interface
uses
  Classes, SysUtils;

const
  BLOCKLIST_FILENAME = 'BLOCKLIST.DAT';

type
  TBlockAction = (baAllow, baBlock, baForward);

  TBlockEntry = record
    Action:      TBlockAction;
    Pattern:     string;       { IP pattern: exact, wildcard, or CIDR }
    ForwardHost: string;       { only for baForward }
    ForwardPort: Integer;      { only for baForward }
    Comment:     string;
  end;

  TNMBlockList = class
  private
    FEntries: TList;
    FDefaultAction: TBlockAction;  { what to do if no rule matches }
    function GetEntry(Index: Integer): TBlockEntry;
    function GetCount: Integer;
    function MatchWildcard(const AIP, APattern: string): Boolean;
    function MatchCIDR(const AIP, ACIDR: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);
    procedure AddEntry(AAction: TBlockAction; const APattern: string;
                       const AForwardHost: string; AForwardPort: Integer;
                       const AComment: string);
    procedure DeleteEntry(Index: Integer);
    function  CheckIP(const AIP: string; out AForwardHost: string;
                      out AForwardPort: Integer): TBlockAction;
    property  Count: Integer read GetCount;
    property  Entries[Index: Integer]: TBlockEntry read GetEntry;
    property  DefaultAction: TBlockAction read FDefaultAction write FDefaultAction;
  end;

implementation

type
  PBlockEntry = ^TBlockEntry;

constructor TNMBlockList.Create;
begin
  inherited Create;
  FEntries := TList.Create;
  FDefaultAction := baAllow;  { default: allow all }
end;

destructor TNMBlockList.Destroy;
begin
  Clear;
  FEntries.Free;
  inherited Destroy;
end;

procedure TNMBlockList.Clear;
var
  i: Integer;
  P: PBlockEntry;
begin
  for i := 0 to FEntries.Count - 1 do
  begin
    P := PBlockEntry(FEntries[i]);
    Dispose(P);
  end;
  FEntries.Clear;
end;

function TNMBlockList.GetCount: Integer;
begin
  Result := FEntries.Count;
end;

function TNMBlockList.GetEntry(Index: Integer): TBlockEntry;
begin
  Result := PBlockEntry(FEntries[Index])^;
end;

procedure TNMBlockList.AddEntry(AAction: TBlockAction; const APattern: string;
                                const AForwardHost: string; AForwardPort: Integer;
                                const AComment: string);
var
  P: PBlockEntry;
begin
  New(P);
  P^.Action := AAction;
  P^.Pattern := APattern;
  P^.ForwardHost := AForwardHost;
  P^.ForwardPort := AForwardPort;
  P^.Comment := AComment;
  FEntries.Add(P);
end;

procedure TNMBlockList.DeleteEntry(Index: Integer);
var
  P: PBlockEntry;
begin
  if (Index < 0) or (Index >= FEntries.Count) then Exit;
  P := PBlockEntry(FEntries[Index]);
  Dispose(P);
  FEntries.Delete(Index);
end;

procedure TNMBlockList.LoadFromFile(const AFileName: string);
var
  F: TextFile;
  Line, ActionStr: string;
  Parts: TStringList;
  Action: TBlockAction;
begin
  Clear;
  if not FileExists(AFileName) then Exit;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ',';
    Parts.StrictDelimiter := True;
    AssignFile(F, AFileName);
    Reset(F);
    try
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        Line := Trim(Line);
        if (Line = '') or (Line[1] = '#') then Continue;
        Parts.DelimitedText := Line;
        if Parts.Count < 2 then Continue;

        ActionStr := UpperCase(Trim(Parts[0]));
        if ActionStr = 'ALLOW' then Action := baAllow
        else if ActionStr = 'BLOCK' then Action := baBlock
        else if ActionStr = 'FORWARD' then Action := baForward
        else Continue;

        AddEntry(Action, Trim(Parts[1]),
          {ForwardHost} IfThen(Parts.Count >= 3, Trim(Parts[2]), ''),
          {ForwardPort} StrToIntDef(IfThen(Parts.Count >= 4, Trim(Parts[3]), ''), 23),
          {Comment}     IfThen(Parts.Count >= 5, Trim(Parts[4]), ''));
      end;
    finally
      CloseFile(F);
    end;
  finally
    Parts.Free;
  end;
end;

procedure TNMBlockList.SaveToFile(const AFileName: string);
var
  F: TextFile;
  i: Integer;
  E: TBlockEntry;
  ActionStr: string;
begin
  AssignFile(F, AFileName);
  Rewrite(F);
  try
    WriteLn(F, '# NetModem/32 Block/Allow/Forward List');
    WriteLn(F, '# Format: action,pattern,forward_host,forward_port,comment');
    WriteLn(F, '# Actions: ALLOW, BLOCK, FORWARD');
    WriteLn(F, '# Patterns: exact IP, wildcard (192.168.*), CIDR (10.0.0.0/8)');
    for i := 0 to FEntries.Count - 1 do
    begin
      E := PBlockEntry(FEntries[i])^;
      case E.Action of
        baAllow:   ActionStr := 'ALLOW';
        baBlock:   ActionStr := 'BLOCK';
        baForward: ActionStr := 'FORWARD';
      end;
      WriteLn(F, Format('%s,%s,%s,%d,%s',
        [ActionStr, E.Pattern, E.ForwardHost, E.ForwardPort, E.Comment]));
    end;
  finally
    CloseFile(F);
  end;
end;

function TNMBlockList.MatchWildcard(const AIP, APattern: string): Boolean;
var
  IPParts, PatParts: TStringList;
  i: Integer;
begin
  Result := False;
  IPParts := TStringList.Create;
  PatParts := TStringList.Create;
  try
    IPParts.Delimiter := '.';
    IPParts.StrictDelimiter := True;
    IPParts.DelimitedText := AIP;
    PatParts.Delimiter := '.';
    PatParts.StrictDelimiter := True;
    PatParts.DelimitedText := APattern;
    if IPParts.Count <> PatParts.Count then Exit;
    for i := 0 to IPParts.Count - 1 do
    begin
      if PatParts[i] = '*' then Continue;
      if IPParts[i] <> PatParts[i] then Exit;
    end;
    Result := True;
  finally
    IPParts.Free;
    PatParts.Free;
  end;
end;

function TNMBlockList.MatchCIDR(const AIP, ACIDR: string): Boolean;
var
  SlashPos: Integer;
  BaseIP: string;
  Bits, i: Integer;
  Mask, IPVal, BaseVal: LongWord;
  IPParts, BaseParts: TStringList;
begin
  Result := False;
  SlashPos := Pos('/', ACIDR);
  if SlashPos = 0 then
  begin
    Result := (AIP = ACIDR);
    Exit;
  end;
  BaseIP := Copy(ACIDR, 1, SlashPos - 1);
  Bits := StrToIntDef(Copy(ACIDR, SlashPos + 1, Length(ACIDR)), 32);
  if (Bits < 0) or (Bits > 32) then Exit;

  Mask := LongWord($FFFFFFFF) shl (32 - Bits);

  IPParts := TStringList.Create;
  BaseParts := TStringList.Create;
  try
    IPParts.Delimiter := '.'; IPParts.StrictDelimiter := True;
    IPParts.DelimitedText := AIP;
    BaseParts.Delimiter := '.'; BaseParts.StrictDelimiter := True;
    BaseParts.DelimitedText := BaseIP;
    if (IPParts.Count <> 4) or (BaseParts.Count <> 4) then Exit;

    IPVal := 0; BaseVal := 0;
    for i := 0 to 3 do
    begin
      IPVal := (IPVal shl 8) or LongWord(StrToIntDef(IPParts[i], 0));
      BaseVal := (BaseVal shl 8) or LongWord(StrToIntDef(BaseParts[i], 0));
    end;
    Result := (IPVal and Mask) = (BaseVal and Mask);
  finally
    IPParts.Free;
    BaseParts.Free;
  end;
end;

function TNMBlockList.CheckIP(const AIP: string; out AForwardHost: string;
                              out AForwardPort: Integer): TBlockAction;
var
  i: Integer;
  E: TBlockEntry;
  Matched: Boolean;
begin
  AForwardHost := '';
  AForwardPort := 0;
  for i := 0 to FEntries.Count - 1 do
  begin
    E := PBlockEntry(FEntries[i])^;
    if Pos('/', E.Pattern) > 0 then
      Matched := MatchCIDR(AIP, E.Pattern)
    else if Pos('*', E.Pattern) > 0 then
      Matched := MatchWildcard(AIP, E.Pattern)
    else
      Matched := (AIP = E.Pattern);

    if Matched then
    begin
      Result := E.Action;
      if E.Action = baForward then
      begin
        AForwardHost := E.ForwardHost;
        AForwardPort := E.ForwardPort;
      end;
      Exit;
    end;
  end;
  Result := FDefaultAction;
end;

end.
