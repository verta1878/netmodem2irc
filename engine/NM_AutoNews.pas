{ ===========================================================================
  netmodem2irc - part of the NetModem/32 revival
  Copyright (C) 2025-2026 Antonio Rico (Reapern66 / verta1878)

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.

  Dedrick Allen's original NetModem/32 material preserved in driver/src/,
  history/ and cpl/original_forms/ remains under GPLv2 - see LICENSES.md.
  =========================================================================== }

unit NM_AutoNews;
{ ===========================================================================
  netmodem2irc — Auto-News feature
  ---------------------------------------------------------------------------
  When enabled, the server periodically displays a news/announcement file
  to connected users at a configurable interval (minutes).

  Original CPL: CheckBox "Enable Auto-News" + Edit "minute intervals"
  Config: EnableAutoNews=1, AutoNewsInterval=60
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, NM_Node;

type
  TNMAutoNews = class
  private
    FEnabled      : Boolean;
    FIntervalMin  : Integer;   // interval in minutes
    FNewsFile     : string;    // path to news text file
    FLastSent     : TDateTime; // last time news was sent
  public
    constructor Create;
    function ShouldSend: Boolean;
    procedure MarkSent;
    function LoadNewsText: string;
    property Enabled: Boolean read FEnabled write FEnabled;
    property IntervalMin: Integer read FIntervalMin write FIntervalMin;
    { Deliver news to all connected nodes via manager.BroadcastStr.
      Call from the server's main timer tick. Returns True if sent. }
    function DeliverIfDue(AManager: TObject): Boolean;
    property NewsFile: string read FNewsFile write FNewsFile;
  end;

implementation

constructor TNMAutoNews.Create;
begin
  inherited Create;
  FEnabled := False;
  FIntervalMin := 60;
  FNewsFile := 'NETMODEM.NEWS';
  FLastSent := 0;
end;

function TNMAutoNews.ShouldSend: Boolean;
begin
  Result := FEnabled and (FIntervalMin > 0) and
            ((FLastSent = 0) or
             ((Now - FLastSent) * 24 * 60 >= FIntervalMin));
end;

procedure TNMAutoNews.MarkSent;
begin
  FLastSent := Now;
end;

function TNMAutoNews.LoadNewsText: string;
var
  F: TextFile;
  S: string;
begin
  Result := '';
  if not FileExists(FNewsFile) then Exit;
  AssignFile(F, FNewsFile);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then Exit;
  try
    while not EOF(F) do
    begin
      ReadLn(F, S);
      Result := Result + S + #13#10;
    end;
  finally
    CloseFile(F);
  end;
end;

function TNMAutoNews.DeliverIfDue(AManager: TObject): Boolean;
var
  News: string;
begin
  Result := False;
  if not ShouldSend then Exit;
  News := LoadNewsText;
  if News = '' then Exit;
  { AManager is TNodeManager — forward-declared to avoid circular ref }
  TNodeManager(AManager).BroadcastStr(#13#10 +
    '=== NetModem/32 Auto-News ===' + #13#10 +
    News +
    '=============================' + #13#10);
  MarkSent;
  Result := True;
end;

end.
