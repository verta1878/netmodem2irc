unit ConfigMain;
{ Main configuration dialog — rebuilt from NETMODEM.CPL::TForm1.
  Per-node: reads/writes HKLM\Software\Allen Software\NetModem (ComportConfig, IRQ).
  Global: reads/writes same registry key (individual values) or NETCONFIG.CNF.
  On save, calls IOCTL 03 (reload config) so the VxD picks up changes
  without a reboot. }
{$MODE OBJFPC}{$H+}
interface
uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, Buttons, ExtCtrls,
  {$IFDEF WINDOWS}Registry, Windows,{$ENDIF}
  NMVxD, NM_DefaultConfig, NM_GlobalConfig;
type
  TfrmConfig = class(TForm)
    Nav: TListBox;
    Pages: TPageControl;
    { Page 0: Comports (per-node) }
    tsComports: TTabSheet;
    cboComport: TComboBox;
    cboBaud: TComboBox;
    cboMode: TComboBox;
    chkEnabled: TCheckBox;
    edtPort: TEdit;
    edtBaseAddr: TEdit;
    cboBuffer: TComboBox;
    chkAlwaysActive: TCheckBox;
    chkLockedBaud: TCheckBox;
    chkTimeSlice: TCheckBox;
    { Page 1: Server }
    tsServer: TTabSheet;
    chkStartAsService: TCheckBox;
    chkSuppressSplash: TCheckBox;
    chkAutoMinimize: TCheckBox;
    chkSpinningGlobe: TCheckBox;
    { Page 2: Logging }
    tsLogging: TTabSheet;
    chkServerLogging: TCheckBox;
    chkActivityLog: TCheckBox;
    edtLogDays: TEdit;
    edtLogMaxSize: TEdit;
    { Page 3: Options }
    tsOptions: TTabSheet;
    chkRetrieveLocalHost: TCheckBox;
    chkExplicitBind: TCheckBox;
    edtBindAddress: TEdit;
    chkAllowUnknownHosts: TCheckBox;
    chkAllowDuplicateConn: TCheckBox;
    chkDisplayBusyFile: TCheckBox;
    chkDisplayOfflineFile: TCheckBox;
    chkDisplayBlockedFile: TCheckBox;
    chkDisplayConnectFile: TCheckBox;
    chkDisplayDisconnectFile: TCheckBox;
    chkDisplayErrorFile: TCheckBox;
    chkDisplayDuplicateFile: TCheckBox;
    { Page 4: Features }
    tsFeatures: TTabSheet;
    chkAutoNews: TCheckBox;
    edtAutoNewsInterval: TEdit;
    chkListserv: TCheckBox;
    edtRingCount: TEdit;
    edtCacheSize: TEdit;
    { Buttons }
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure NavClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FDriver: TNetModemDriver;
    FGlobal: TNMGlobalConfig;
    procedure LoadFromRegistry;
    procedure SaveToRegistry;
    procedure LoadGlobalToControls;
    procedure SaveControlsToGlobal;
  public
  end;
var
  frmConfig: TfrmConfig;
implementation
{$R *.lfm}

procedure TfrmConfig.FormCreate(Sender: TObject);
begin
  FDriver := TNetModemDriver.Create;
  FGlobal := TNMGlobalConfig.Create;

  { Per-node controls }
  cboBaud.Items.CommaText := '300,1200,2400,9600,14400,16800,19200,21600,28800,33600,38400,57600,64000,115200';
  cboBaud.ItemIndex := 10;  { 38400 }
  cboMode.Items.CommaText := 'FOSSIL,UART';
  cboMode.ItemIndex := 0;
  cboBuffer.Items.CommaText := '1024,2048,3072,4096,5120,6144,7168,8192';
  cboBuffer.ItemIndex := 1;  { 2048 }

  { Nav panel }
  Nav.Items.Clear;
  Nav.Items.Add('Comports');
  Nav.Items.Add('Server');
  Nav.Items.Add('Logging');
  Nav.Items.Add('Options');
  Nav.Items.Add('Features');
  Nav.ItemIndex := 0;

  { If no registry config exists, write defaults first }
  if not RegistryConfigExists then
    WriteDefaultRegistry;

  LoadFromRegistry;

  { Load global settings }
  {$IFDEF WINDOWS}
  FGlobal.LoadFromRegistry;
  {$ELSE}
  FGlobal.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'NETCONFIG.CNF');
  {$ENDIF}
  LoadGlobalToControls;
end;

procedure TfrmConfig.FormDestroy(Sender: TObject);
begin
  FGlobal.Free;
  FDriver.Free;
end;

procedure TfrmConfig.NavClick(Sender: TObject);
begin
  if Nav.ItemIndex >= 0 then Pages.PageIndex := Nav.ItemIndex;
end;

procedure TfrmConfig.LoadGlobalToControls;
begin
  { Server }
  chkStartAsService.Checked    := FGlobal.StartAsService;
  chkSuppressSplash.Checked    := FGlobal.SuppressSplash;
  chkAutoMinimize.Checked      := FGlobal.AutoMinimize;
  chkSpinningGlobe.Checked     := FGlobal.EnableSpinningGlobe;
  { Logging }
  chkServerLogging.Checked     := FGlobal.ServerLogging;
  chkActivityLog.Checked       := FGlobal.ActivityLog;
  edtLogDays.Text              := IntToStr(FGlobal.LogFileDays);
  edtLogMaxSize.Text           := IntToStr(FGlobal.LogFileMaxSize);
  { Options }
  chkRetrieveLocalHost.Checked := FGlobal.RetrieveLocalHost;
  chkExplicitBind.Checked      := FGlobal.ExplicitBind;
  edtBindAddress.Text          := FGlobal.BindAddress;
  chkAllowUnknownHosts.Checked := FGlobal.AllowUnknownHosts;
  chkAllowDuplicateConn.Checked := FGlobal.AllowDuplicateConn;
  chkDisplayBusyFile.Checked   := FGlobal.DisplayBusyFile;
  chkDisplayOfflineFile.Checked := FGlobal.DisplayOfflineFile;
  chkDisplayBlockedFile.Checked := FGlobal.DisplayBlockedFile;
  chkDisplayConnectFile.Checked := FGlobal.DisplayConnectFile;
  chkDisplayDisconnectFile.Checked := FGlobal.DisplayDisconnectFile;
  chkDisplayErrorFile.Checked  := FGlobal.DisplayErrorFile;
  chkDisplayDuplicateFile.Checked := FGlobal.DisplayDuplicateFile;
  { Features }
  chkAutoNews.Checked          := FGlobal.EnableAutoNews;
  edtAutoNewsInterval.Text     := IntToStr(FGlobal.AutoNewsInterval);
  chkListserv.Checked          := FGlobal.EnableListserv;
  edtRingCount.Text            := IntToStr(FGlobal.RingCount);
  edtCacheSize.Text            := IntToStr(FGlobal.InternalCacheSize);
end;

procedure TfrmConfig.SaveControlsToGlobal;
begin
  { Server }
  FGlobal.StartAsService       := chkStartAsService.Checked;
  FGlobal.SuppressSplash       := chkSuppressSplash.Checked;
  FGlobal.AutoMinimize         := chkAutoMinimize.Checked;
  FGlobal.EnableSpinningGlobe  := chkSpinningGlobe.Checked;
  { Logging }
  FGlobal.ServerLogging        := chkServerLogging.Checked;
  FGlobal.ActivityLog          := chkActivityLog.Checked;
  FGlobal.LogFileDays          := StrToIntDef(edtLogDays.Text, 30);
  FGlobal.LogFileMaxSize       := StrToIntDef(edtLogMaxSize.Text, 1024);
  { Options }
  FGlobal.RetrieveLocalHost    := chkRetrieveLocalHost.Checked;
  FGlobal.ExplicitBind         := chkExplicitBind.Checked;
  FGlobal.BindAddress          := edtBindAddress.Text;
  FGlobal.AllowUnknownHosts    := chkAllowUnknownHosts.Checked;
  FGlobal.AllowDuplicateConn   := chkAllowDuplicateConn.Checked;
  FGlobal.DisplayBusyFile      := chkDisplayBusyFile.Checked;
  FGlobal.DisplayOfflineFile   := chkDisplayOfflineFile.Checked;
  FGlobal.DisplayBlockedFile   := chkDisplayBlockedFile.Checked;
  FGlobal.DisplayConnectFile   := chkDisplayConnectFile.Checked;
  FGlobal.DisplayDisconnectFile := chkDisplayDisconnectFile.Checked;
  FGlobal.DisplayErrorFile     := chkDisplayErrorFile.Checked;
  FGlobal.DisplayDuplicateFile := chkDisplayDuplicateFile.Checked;
  { Features }
  FGlobal.EnableAutoNews       := chkAutoNews.Checked;
  FGlobal.AutoNewsInterval     := StrToIntDef(edtAutoNewsInterval.Text, 60);
  FGlobal.EnableListserv       := chkListserv.Checked;
  FGlobal.RingCount            := StrToIntDef(edtRingCount.Text, 1);
  FGlobal.InternalCacheSize    := StrToIntDef(edtCacheSize.Text, 4096);
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
        edtPort.Text := IntToStr(Cfg.Internetport);
        edtBaseAddr.Text := '$' + IntToHex(Cfg.Baseaddress, 4);
        chkAlwaysActive.Checked := Cfg.Alwaysactive = 1;
        chkLockedBaud.Checked := Cfg.Lockedbaudrate = 1;
        chkTimeSlice.Checked := Cfg.Managetimeslice = 1;
        { Baud — find in list }
        case Cfg.Baudrate of
          300:    cboBaud.ItemIndex := 0;
          1200:   cboBaud.ItemIndex := 1;
          2400:   cboBaud.ItemIndex := 2;
          9600:   cboBaud.ItemIndex := 3;
          14400:  cboBaud.ItemIndex := 4;
          16800:  cboBaud.ItemIndex := 5;
          19200:  cboBaud.ItemIndex := 6;
          21600:  cboBaud.ItemIndex := 7;
          28800:  cboBaud.ItemIndex := 8;
          33600:  cboBaud.ItemIndex := 9;
          38400:  cboBaud.ItemIndex := 10;
          57600:  cboBaud.ItemIndex := 11;
          64000:  cboBaud.ItemIndex := 12;
          115200: cboBaud.ItemIndex := 13;
        else      cboBaud.ItemIndex := 10;
        end;
        if Cfg.Emulation = 1 then cboMode.ItemIndex := 0
        else cboMode.ItemIndex := 1;
        { Buffer — find in list }
        case Cfg.Buffersize of
          1024: cboBuffer.ItemIndex := 0;
          2048: cboBuffer.ItemIndex := 1;
          3072: cboBuffer.ItemIndex := 2;
          4096: cboBuffer.ItemIndex := 3;
          5120: cboBuffer.ItemIndex := 4;
          6144: cboBuffer.ItemIndex := 5;
          7168: cboBuffer.ItemIndex := 6;
          8192: cboBuffer.ItemIndex := 7;
        else    cboBuffer.ItemIndex := 1;
        end;
      end;
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;
{$ELSE}
begin
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
  Val(edtPort.Text, Cfg.Internetport, Code);
  if Cfg.Internetport = 0 then Cfg.Internetport := DEFAULT_TELNET_PORT;
  Val(edtBaseAddr.Text, Cfg.Baseaddress, Code);
  if Cfg.Baseaddress = 0 then Cfg.Baseaddress := DEFAULT_BASEADDR;
  Val(cboBuffer.Text, Cfg.Buffersize, Code);
  if Cfg.Buffersize = 0 then Cfg.Buffersize := DEFAULT_BUFSIZE;
  if chkAlwaysActive.Checked then Cfg.Alwaysactive := 1 else Cfg.Alwaysactive := 0;
  if chkLockedBaud.Checked then Cfg.Lockedbaudrate := 1 else Cfg.Lockedbaudrate := 0;
  if chkTimeSlice.Checked then Cfg.Managetimeslice := 1 else Cfg.Managetimeslice := 0;

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

  FDriver.ReloadConfig(1);
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TfrmConfig.btnOKClick(Sender: TObject);
begin
  { Save per-node config to registry }
  SaveToRegistry;
  { Save global config }
  SaveControlsToGlobal;
  {$IFDEF WINDOWS}
  FGlobal.SaveToRegistry;
  {$ELSE}
  FGlobal.SaveToFile(ExtractFilePath(ParamStr(0)) + 'NETCONFIG.CNF');
  {$ENDIF}
  Close;
end;

end.
