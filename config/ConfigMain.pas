unit ConfigMain;
{ Main configuration dialog — rebuilt from NETMODEM.CPL::TForm1.
  Original used a TShortcutList left nav (105px) to switch config sections;
  replaced here with a free TPageControl (hidden tabs) driven by a side list. }
{$MODE OBJFPC}{$H+}
interface
uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, Buttons, ExtCtrls,
  NetModemVxD;
type
  TfrmConfig = class(TForm)
    Nav: TListBox;             // replaces TShortcutList (left nav)
    Pages: TPageControl;       // hidden-tab pages, one per config section
    cboComport: TComboBox;     // was TComboBox: comport 3..99
    cboBaud: TComboBox;        // was TComboBox: 19200/38400/57600/115200
    cboEmulation: TComboBox;   // was TComboBox: UART / FOSSIL
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure NavClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FDriver: TNetModemDriver;
    procedure LoadConfig;      // read registry ComportConfig -> controls
    procedure SaveConfig;      // controls -> registry, then IOCTL 03 reload
  public
  end;
var
  frmConfig: TfrmConfig;
implementation
{$R *.lfm}
procedure TfrmConfig.FormCreate(Sender: TObject);
begin
  FDriver := TNetModemDriver.Create;
  LoadConfig;
end;
procedure TfrmConfig.NavClick(Sender: TObject);
begin
  if Nav.ItemIndex >= 0 then Pages.PageIndex := Nav.ItemIndex; // switch section
end;
procedure TfrmConfig.LoadConfig;
begin
  // TODO: read HKLM\Software\Allen Software\NetModem\ComportConfig (TComportStruct)
end;
procedure TfrmConfig.SaveConfig;
begin
  // TODO: write registry, then FDriver.ReloadConfig(node);  // IOCTL 03
end;
procedure TfrmConfig.btnOKClick(Sender: TObject);
begin
  SaveConfig; Close;
end;
end.
