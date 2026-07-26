unit NewDisk;
{$MODE DELPHI}
interface
uses Windows, SysUtils, Classes, Forms;

function SelectDisk(const DiskNumber: Integer; const AFilename: String; var Path: String): Boolean;

implementation

function SelectDisk(const DiskNumber: Integer; const AFilename: String; var Path: String): Boolean;
begin
  Result := False;
end;

end.
