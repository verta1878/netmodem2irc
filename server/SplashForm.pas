unit SplashForm;
{ Startup splash — rebuilt from NETMODEM.EXE::TSplashForm. }
{$MODE OBJFPC}{$H+}
interface
uses Classes, SysUtils, Forms, ExtCtrls, StdCtrls;
type
  TfrmSplash = class(TForm)
    Image1: TImage;
    lblVersion: TLabel;
  end;
var
  frmSplash: TfrmSplash;
implementation
{$R *.lfm}
end.
