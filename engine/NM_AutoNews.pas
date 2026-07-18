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
  SysUtils;

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
  Reset(F);
  while not EOF(F) do
  begin
    ReadLn(F, S);
    Result := Result + S + #13#10;
  end;
  CloseFile(F);
end;

end.
