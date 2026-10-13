{ ===========================================================================
  ConfigMain_phonebook.pas — Phonebook tab additions for ConfigMain.pas

  ADD to the TfrmConfig class declaration (after tsFeatures fields):

    { Page 5: Phonebook }
    tsPhonebook: TTabSheet;
    lvPhonebook: TListView;
    btnPBAdd: TButton;
    btnPBEdit: TButton;
    btnPBDelete: TButton;
    edtPBFile: TEdit;
    btnPBBrowse: TButton;
    procedure btnPBAddClick(Sender: TObject);
    procedure btnPBEditClick(Sender: TObject);
    procedure btnPBDeleteClick(Sender: TObject);
    procedure btnPBBrowseClick(Sender: TObject);

  ADD to private section:
    FPhonebook: TNMPhonebook;
    procedure LoadPhonebookToList;

  ADD to uses:
    NM_Phonebook, Dialogs

  =========================================================================== }

{ --- Implementation code to ADD to ConfigMain.pas --- }

{ In FormCreate, after Nav items, add: }
{
  Nav.Items.Add('Phonebook');

  FPhonebook := TNMPhonebook.Create(
    ExtractFilePath(ParamStr(0)) + PHONEBOOK_FILENAME);
  FPhonebook.LoadFromFile;
  LoadPhonebookToList;
}

{ In FormDestroy, add: }
{
  FPhonebook.Free;
}

{ In NavClick — already works because PageIndex maps to Nav.ItemIndex }

{ In btnOKClick, before Close, add: }
{
  FPhonebook.FilePath := edtPBFile.Text;
  FPhonebook.SaveToFile;
}

{ --- New procedures --- }

procedure TfrmConfig.LoadPhonebookToList;
var
  i: Integer;
  Entry: TPhonebookEntry;
  Item: TListItem;
begin
  lvPhonebook.Items.Clear;
  for i := 0 to PHONEBOOK_MAX_SLOTS - 1 do
  begin
    Entry := FPhonebook.GetEntry(i);
    if not Entry.InUse then Continue;
    Item := lvPhonebook.Items.Add;
    Item.Caption := IntToStr(Entry.Slot);
    Item.SubItems.Add(Entry.Host);
    Item.SubItems.Add(IntToStr(Entry.Port));
    Item.SubItems.Add(Entry.Description);
  end;
end;

procedure TfrmConfig.btnPBAddClick(Sender: TObject);
var
  SlotStr, HostStr, PortStr, DescStr: string;
  Slot, Port: Integer;
begin
  SlotStr := '';
  HostStr := '';
  PortStr := '23';
  DescStr := '';

  if not InputQuery('Add Phonebook Entry', 'Speed dial slot (0-99):', SlotStr) then Exit;
  Slot := StrToIntDef(SlotStr, -1);
  if (Slot < 0) or (Slot >= PHONEBOOK_MAX_SLOTS) then
  begin
    MessageDlg('Slot must be 0-99.', mtError, [mbOK], 0);
    Exit;
  end;
  if FPhonebook.SlotInUse(Slot) then
  begin
    if MessageDlg(Format('Slot %d already in use. Overwrite?', [Slot]),
                  mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  end;

  if not InputQuery('Add Phonebook Entry', 'Host (hostname or IP):', HostStr) then Exit;
  if not InputQuery('Add Phonebook Entry', 'Port (default 23):', PortStr) then Exit;
  InputQuery('Add Phonebook Entry', 'Description (optional):', DescStr);

  Port := StrToIntDef(PortStr, 23);
  FPhonebook.SetEntry(Slot, HostStr, Port, DescStr);
  LoadPhonebookToList;
end;

procedure TfrmConfig.btnPBEditClick(Sender: TObject);
var
  Sel: TListItem;
  Slot, Port: Integer;
  Entry: TPhonebookEntry;
  HostStr, PortStr, DescStr: string;
begin
  Sel := lvPhonebook.Selected;
  if Sel = nil then
  begin
    MessageDlg('Select an entry to edit.', mtInformation, [mbOK], 0);
    Exit;
  end;

  Slot := StrToIntDef(Sel.Caption, -1);
  Entry := FPhonebook.GetEntry(Slot);
  if not Entry.InUse then Exit;

  HostStr := Entry.Host;
  PortStr := IntToStr(Entry.Port);
  DescStr := Entry.Description;

  if not InputQuery('Edit Phonebook Entry', 'Host:', HostStr) then Exit;
  if not InputQuery('Edit Phonebook Entry', 'Port:', PortStr) then Exit;
  InputQuery('Edit Phonebook Entry', 'Description:', DescStr);

  Port := StrToIntDef(PortStr, 23);
  FPhonebook.SetEntry(Slot, HostStr, Port, DescStr);
  LoadPhonebookToList;
end;

procedure TfrmConfig.btnPBDeleteClick(Sender: TObject);
var
  Sel: TListItem;
  Slot: Integer;
begin
  Sel := lvPhonebook.Selected;
  if Sel = nil then
  begin
    MessageDlg('Select an entry to delete.', mtInformation, [mbOK], 0);
    Exit;
  end;

  Slot := StrToIntDef(Sel.Caption, -1);
  if MessageDlg(Format('Delete speed dial slot %d?', [Slot]),
                mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FPhonebook.DeleteEntry(Slot);
    LoadPhonebookToList;
  end;
end;

procedure TfrmConfig.btnPBBrowseClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Filter := 'Phonebook files (*.dat)|*.dat|All files (*.*)|*.*';
    Dlg.FileName := edtPBFile.Text;
    if Dlg.Execute then
      edtPBFile.Text := Dlg.FileName;
  finally
    Dlg.Free;
  end;
end;

