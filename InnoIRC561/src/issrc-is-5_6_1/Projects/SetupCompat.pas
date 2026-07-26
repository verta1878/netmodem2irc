unit SetupCompat;
{$MODE DELPHI}
interface
uses Windows, SysUtils, Classes;

function ListContains(const List, Item: String): Boolean;
function ExpandSetupMessage(const Msg: String): String;

type
  TAlphaFormat = (afIgnored, afDefined, afPremultiplied);
  TAlphaBitmap = class
  public
    AlphaFormat: TAlphaFormat;
  end;

implementation

function ListContains(const List, Item: String): Boolean;
begin Result := Pos(Item, List) > 0; end;

function ExpandSetupMessage(const Msg: String): String;
begin Result := Msg; end;

end.
