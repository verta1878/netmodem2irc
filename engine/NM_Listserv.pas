unit NM_Listserv;
{ ===========================================================================
  netmodem2irc — BBS Listserv feature
  ---------------------------------------------------------------------------
  Matches original NetModem/32 CPL TForm2 (Listserv Information).
  When enabled, the server registers with a central BBS directory so other
  NetModem users can discover and connect to this BBS.

  Fields (from CPL TForm2):
    BBS Name      *required  (max 50)
    Software       optional  (max 50)
    Speed          optional  (max 25)
    Hostname      *required  (max 255)
    IP Address    *required  (max 15)
    Internet Port  optional  (max 4 digits)
    Comment        optional  (max 255)
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils;

type
  TListservInfo = record
    BBSName      : string;   // *required
    Software     : string;
    Speed        : string;
    Hostname     : string;   // *required
    IPAddress    : string;   // *required
    InternetPort : Word;
    Comment      : string;
  end;

  TNMListserv = class
  private
    FEnabled : Boolean;
    FInfo    : TListservInfo;
  public
    constructor Create;
    function IsValid: Boolean;
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);
    property Enabled: Boolean read FEnabled write FEnabled;
    property Info: TListservInfo read FInfo write FInfo;
  end;

implementation

constructor TNMListserv.Create;
begin
  inherited Create;
  FEnabled := False;
  FillChar(FInfo, SizeOf(FInfo), 0);
  FInfo.InternetPort := 23;
end;

function TNMListserv.IsValid: Boolean;
begin
  Result := (FInfo.BBSName <> '') and
            (FInfo.Hostname <> '') and
            (FInfo.IPAddress <> '');
end;

procedure TNMListserv.LoadFromFile(const AFileName: string);
var
  F: TextFile;
  S, Key, Val: string;
  EqPos: Integer;
begin
  if not FileExists(AFileName) then Exit;
  AssignFile(F, AFileName);
  Reset(F);
  while not EOF(F) do
  begin
    ReadLn(F, S);
    S := Trim(S);
    if (S = '') or (S[1] = ';') or (S[1] = '#') then Continue;
    EqPos := Pos('=', S);
    if EqPos = 0 then Continue;
    Key := Trim(Copy(S, 1, EqPos - 1));
    Val := Trim(Copy(S, EqPos + 1, Length(S)));
    if Key = 'BBSName'       then FInfo.BBSName := Val
    else if Key = 'Software' then FInfo.Software := Val
    else if Key = 'Speed'    then FInfo.Speed := Val
    else if Key = 'Hostname' then FInfo.Hostname := Val
    else if Key = 'IPAddress' then FInfo.IPAddress := Val
    else if Key = 'InternetPort' then FInfo.InternetPort := StrToIntDef(Val, 23)
    else if Key = 'Comment'  then FInfo.Comment := Val;
  end;
  CloseFile(F);
end;

procedure TNMListserv.SaveToFile(const AFileName: string);
var F: TextFile;
begin
  AssignFile(F, AFileName);
  Rewrite(F);
  WriteLn(F, '; NetModem/32 BBS Listserv Information');
  WriteLn(F, 'BBSName=', FInfo.BBSName);
  WriteLn(F, 'Software=', FInfo.Software);
  WriteLn(F, 'Speed=', FInfo.Speed);
  WriteLn(F, 'Hostname=', FInfo.Hostname);
  WriteLn(F, 'IPAddress=', FInfo.IPAddress);
  WriteLn(F, 'InternetPort=', FInfo.InternetPort);
  WriteLn(F, 'Comment=', FInfo.Comment);
  CloseFile(F);
end;

end.
