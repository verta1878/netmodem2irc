{ ===========================================================================
  netmodem2irc - part of the NetModem/32 revival
  Copyright (C) 2025-2026 Antonio Rico (Reapern66 / verta1878)

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
  =========================================================================== }

unit NM_Phonebook;
{ Virtual phone book for AT&Z / ATDS speed-dial.
  Stores entries as CSV: slot,host,port,description
  File: PHONEBOOK.DAT in the NetModem config directory.
  Own implementation — not derived from NetSerial or any other project. }
{$MODE OBJFPC}{$H+}
interface
uses
  Classes, SysUtils;

const
  PHONEBOOK_MAX_SLOTS = 100;  { 0-99 speed dial entries }
  PHONEBOOK_FILENAME  = 'PHONEBOOK.DAT';

type
  TPhonebookEntry = record
    Slot:        Integer;     { 0-99, matches ATDS<n> }
    Host:        string;      { hostname or IP }
    Port:        Integer;     { TCP port, default 23 }
    Description: string;      { user note }
    InUse:       Boolean;
  end;

  TNMPhonebook = class
  private
    FEntries: array[0..PHONEBOOK_MAX_SLOTS - 1] of TPhonebookEntry;
    FFilePath: string;
    procedure Clear;
  public
    constructor Create(const AFilePath: string);
    procedure LoadFromFile;
    procedure SaveToFile;
    function  GetEntry(Slot: Integer): TPhonebookEntry;
    procedure SetEntry(Slot: Integer; const AHost: string;
                       APort: Integer; const ADesc: string);
    procedure DeleteEntry(Slot: Integer);
    function  EntryCount: Integer;
    function  SlotInUse(Slot: Integer): Boolean;
    { AT command helpers }
    function  Dial(Slot: Integer; out AHost: string;
                   out APort: Integer): Boolean;
    procedure Store(Slot: Integer; const AHostPort: string);
    property  FilePath: string read FFilePath write FFilePath;
  end;

implementation

constructor TNMPhonebook.Create(const AFilePath: string);
begin
  inherited Create;
  FFilePath := AFilePath;
  Clear;
end;

procedure TNMPhonebook.Clear;
var
  i: Integer;
begin
  for i := 0 to PHONEBOOK_MAX_SLOTS - 1 do
  begin
    FEntries[i].Slot := i;
    FEntries[i].Host := '';
    FEntries[i].Port := 23;
    FEntries[i].Description := '';
    FEntries[i].InUse := False;
  end;
end;

procedure TNMPhonebook.LoadFromFile;
var
  F: TextFile;
  Line: string;
  Parts: TStringList;
  Slot: Integer;
begin
  Clear;
  if not FileExists(FFilePath) then Exit;

  Parts := TStringList.Create;
  try
    Parts.Delimiter := ',';
    Parts.StrictDelimiter := True;
    AssignFile(F, FFilePath);
    Reset(F);
    try
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        Line := Trim(Line);
        if (Line = '') or (Line[1] = '#') then Continue;

        Parts.DelimitedText := Line;
        if Parts.Count < 2 then Continue;

        Slot := StrToIntDef(Parts[0], -1);
        if (Slot < 0) or (Slot >= PHONEBOOK_MAX_SLOTS) then Continue;

        FEntries[Slot].Host := Parts[1];
        if Parts.Count >= 3 then
          FEntries[Slot].Port := StrToIntDef(Parts[2], 23)
        else
          FEntries[Slot].Port := 23;
        if Parts.Count >= 4 then
          FEntries[Slot].Description := Parts[3]
        else
          FEntries[Slot].Description := '';
        FEntries[Slot].InUse := True;
      end;
    finally
      CloseFile(F);
    end;
  finally
    Parts.Free;
  end;
end;

procedure TNMPhonebook.SaveToFile;
var
  F: TextFile;
  i: Integer;
begin
  AssignFile(F, FFilePath);
  Rewrite(F);
  try
    WriteLn(F, '# NetModem/32 Phonebook — ATDS speed dial');
    WriteLn(F, '# Format: slot,host,port,description');
    for i := 0 to PHONEBOOK_MAX_SLOTS - 1 do
    begin
      if not FEntries[i].InUse then Continue;
      WriteLn(F, Format('%d,%s,%d,%s',
        [i, FEntries[i].Host, FEntries[i].Port, FEntries[i].Description]));
    end;
  finally
    CloseFile(F);
  end;
end;

function TNMPhonebook.GetEntry(Slot: Integer): TPhonebookEntry;
begin
  if (Slot >= 0) and (Slot < PHONEBOOK_MAX_SLOTS) then
    Result := FEntries[Slot]
  else
  begin
    Result.Slot := -1;
    Result.InUse := False;
  end;
end;

procedure TNMPhonebook.SetEntry(Slot: Integer; const AHost: string;
                                APort: Integer; const ADesc: string);
begin
  if (Slot < 0) or (Slot >= PHONEBOOK_MAX_SLOTS) then Exit;
  FEntries[Slot].Host := AHost;
  FEntries[Slot].Port := APort;
  FEntries[Slot].Description := ADesc;
  FEntries[Slot].InUse := True;
end;

procedure TNMPhonebook.DeleteEntry(Slot: Integer);
begin
  if (Slot < 0) or (Slot >= PHONEBOOK_MAX_SLOTS) then Exit;
  FEntries[Slot].Host := '';
  FEntries[Slot].Port := 23;
  FEntries[Slot].Description := '';
  FEntries[Slot].InUse := False;
end;

function TNMPhonebook.EntryCount: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to PHONEBOOK_MAX_SLOTS - 1 do
    if FEntries[i].InUse then Inc(Result);
end;

function TNMPhonebook.SlotInUse(Slot: Integer): Boolean;
begin
  if (Slot >= 0) and (Slot < PHONEBOOK_MAX_SLOTS) then
    Result := FEntries[Slot].InUse
  else
    Result := False;
end;

function TNMPhonebook.Dial(Slot: Integer; out AHost: string;
                           out APort: Integer): Boolean;
begin
  Result := False;
  if (Slot < 0) or (Slot >= PHONEBOOK_MAX_SLOTS) then Exit;
  if not FEntries[Slot].InUse then Exit;
  AHost := FEntries[Slot].Host;
  APort := FEntries[Slot].Port;
  Result := True;
end;

procedure TNMPhonebook.Store(Slot: Integer; const AHostPort: string);
var
  ColonPos: Integer;
  H: string;
  P: Integer;
begin
  if (Slot < 0) or (Slot >= PHONEBOOK_MAX_SLOTS) then Exit;
  ColonPos := Pos(':', AHostPort);
  if ColonPos > 0 then
  begin
    H := Copy(AHostPort, 1, ColonPos - 1);
    P := StrToIntDef(Copy(AHostPort, ColonPos + 1, Length(AHostPort)), 23);
  end else begin
    H := AHostPort;
    P := 23;
  end;
  SetEntry(Slot, H, P, '');
end;

end.
