{ ===========================================================================
  ConfigMain_listserv.pas — Listserv tab additions for ConfigMain.pas
  Ported from NETMODEM_CPL__TForm2.dfm (derk's original).

  ADD to TfrmConfig class declaration:
    tsListserv: TTabSheet;
    grpListserv: TGroupBox;
    edtLSBBSName, edtLSSoftware, edtLSSpeed: TEdit;
    edtLSHostname, edtLSIPAddress, edtLSPort, edtLSComment: TEdit;
    chkLSEnabled: TCheckBox;
    btnLSRegister, btnLSExport: TButton;
    procedure btnLSRegisterClick(Sender: TObject);
    procedure btnLSExportClick(Sender: TObject);

  ADD to private:
    FListserv: TNMListserv;
    procedure LoadListservToControls;
    procedure SaveControlsToListserv;

  ADD to uses:
    NM_Listserv, Clipbrd
  =========================================================================== }

{ In FormCreate, add: }
{
  Nav.Items.Add('Listserv');
  FListserv := TNMListserv.Create;
  FListserv.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'LISTSERV.CNF');
  LoadListservToControls;
}

{ In FormDestroy, add: }
{
  FListserv.Free;
}

{ In btnOKClick, before Close, add: }
{
  SaveControlsToListserv;
  FListserv.SaveToFile(ExtractFilePath(ParamStr(0)) + 'LISTSERV.CNF');
}

procedure TfrmConfig.LoadListservToControls;
begin
  edtLSBBSName.Text   := FListserv.Info.BBSName;
  edtLSSoftware.Text  := FListserv.Info.Software;
  edtLSSpeed.Text     := FListserv.Info.Speed;
  edtLSHostname.Text  := FListserv.Info.Hostname;
  edtLSIPAddress.Text := FListserv.Info.IPAddress;
  edtLSPort.Text      := IntToStr(FListserv.Info.InternetPort);
  edtLSComment.Text   := FListserv.Info.Comment;
  chkLSEnabled.Checked := FListserv.Enabled;
end;

procedure TfrmConfig.SaveControlsToListserv;
var
  Info: TListservInfo;
begin
  Info.BBSName      := edtLSBBSName.Text;
  Info.Software     := edtLSSoftware.Text;
  Info.Speed        := edtLSSpeed.Text;
  Info.Hostname     := edtLSHostname.Text;
  Info.IPAddress    := edtLSIPAddress.Text;
  Info.InternetPort := StrToIntDef(edtLSPort.Text, 23);
  Info.Comment      := edtLSComment.Text;
  FListserv.Info    := Info;
  FListserv.Enabled := chkLSEnabled.Checked;
end;

procedure TfrmConfig.btnLSRegisterClick(Sender: TObject);
begin
  SaveControlsToListserv;
  if not FListserv.IsValid then
  begin
    MessageDlg('BBS Name, Hostname, and IP Address are required.',
               mtError, [mbOK], 0);
    Exit;
  end;
  { TODO: configurable registry server address }
  if FListserv.RegisterBBS('listserv.netmodem.org', 2323) then
    MessageDlg('Registration successful.', mtInformation, [mbOK], 0)
  else
    MessageDlg('Registration failed — server unreachable or rejected.',
               mtWarning, [mbOK], 0);
end;

procedure TfrmConfig.btnLSExportClick(Sender: TObject);
begin
  SaveControlsToListserv;
  if not FListserv.IsValid then
  begin
    MessageDlg('BBS Name, Hostname, and IP Address are required.',
               mtError, [mbOK], 0);
    Exit;
  end;
  Clipboard.AsText := FListserv.ExportRecord;
  MessageDlg('Record copied to clipboard.', mtInformation, [mbOK], 0);
end;

