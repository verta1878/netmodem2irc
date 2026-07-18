unit ConfigMain;
{ Main configuration dialog — rebuilt from NETMODEM.CPL::TForm1.
  Reads/writes HKLM\Software\Allen Software\NetModem (ComportConfig, IRQ).
  On save, calls IOCTL 03 (reload config) so the VxD picks up changes
  without a reboot. }
{$MODE OBJFPC}{$H+}
interface
uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, Buttons, ExtCtrls,
  {$IFDEF WINDOWS}Registry, Windows,{$ENDIF}
  NMVxD, NM_DefaultConfig;
type
  TfrmConfig = class(TForm)
    Nav: TListBox;
    Pages: TPageControl;
    cboComport: TComboBox;
    cboBaud: TComboBox;
    cboMode: TComboBox;
    chkEnabled: TCheckBox;
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure NavClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FDriver: TNetModemDriver;
    procedure LoadFromRegistry;
    procedure SaveToRegistry;
  public
  end;
var
  frmConfig: TfrmConfig;
implementation
{$R *.lfm}

procedure TfrmConfig.FormCreate(Sender: TObject);
begin
  FDriver := TNetModemDriver.Create;
  cboBaud.Items.CommaText := '9600,19200,38400,57600,115200';
  cboBaud.ItemIndex := 2;
  cboMode.Items.CommaText := 'FOSSIL,UART';
  cboMode.ItemIndex := 0;

  { If no registry config exists, write defaults first }
  if not RegistryConfigExists then
    WriteDefaultRegistry;

  LoadFromRegistry;
end;

procedure TfrmConfig.NavClick(Sender: TObject);
begin
  if Nav.ItemIndex >= 0 then Pages.PageIndex := Nav.ItemIndex;
end;

procedure TfrmConfig.LoadFromRegistry;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
  Cfg: TRegComportStruct;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly(REG_KEY) then
    begin
      if Reg.GetDataSize(REG_CONFIG_VALUE) >= SizeOf(Cfg) then
      begin
        FillChar(Cfg, SizeOf(Cfg), 0);
        Reg.ReadBinaryData(REG_CONFIG_VALUE, Cfg, SizeOf(Cfg));
        cboComport.Text := IntToStr(Cfg.ComportNumber);
        chkEnabled.Checked := Cfg.Enabled = 1;
        case Cfg.Baudrate of
          9600:   cboBaud.ItemIndex := 0;
          19200:  cboBaud.ItemIndex := 1;
          38400:  cboBaud.ItemIndex := 2;
          57600:  cboBaud.ItemIndex := 3;
          115200: cboBaud.ItemIndex := 4;
        else      cboBaud.ItemIndex := 2;
        end;
        if Cfg.Emulation = 1 then cboMode.ItemIndex := 0  { FOSSIL }
        else cboMode.ItemIndex := 1;  { UART }
      end;
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;
{$ELSE}
begin
  { non-Windows: show defaults }
end;
{$ENDIF}

procedure TfrmConfig.SaveToRegistry;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
  Cfg: TRegComportStruct;
  IRQ: DWORD;
  Code: Integer;
begin
  FillChar(Cfg, SizeOf(Cfg), 0);
  Cfg.Node := 1;
  if chkEnabled.Checked then Cfg.Enabled := 1 else Cfg.Enabled := 0;
  Val(cboComport.Text, Cfg.ComportNumber, Code);
  Cfg.szComportName := 'COM' + AnsiChar(Ord('0') + Cfg.ComportNumber) + #0#0#0;
  if cboMode.ItemIndex = 0 then Cfg.Emulation := 1 else Cfg.Emulation := 0;
  Val(cboBaud.Text, Cfg.Baudrate, Code);
  Cfg.Internetport := DEFAULT_TELNET_PORT;
  Cfg.Baseaddress := DEFAULT_BASEADDR;
  Cfg.Lockedbaudrate := 1;
  Cfg.Managetimeslice := 1;
  Cfg.Buffersize := DEFAULT_BUFSIZE;

  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKey(REG_KEY, True) then
    begin
      Reg.WriteBinaryData(REG_CONFIG_VALUE, Cfg, SizeOf(Cfg));
      IRQ := 0;
      Reg.WriteBinaryData(REG_IRQ_VALUE, IRQ, SizeOf(IRQ));
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;

  { Tell the driver to reload — IOCTL 03, no reboot needed }
  FDriver.ReloadConfig(1);
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TfrmConfig.btnOKClick(Sender: TObject);
begin
  SaveToRegistry;
  Close;
end;

end.
