{ ===========================================================================
  ConfigMain_blocking.pas — Blocking tab additions for ConfigMain.pas

  ADD to TfrmConfig class declaration:
    tsBlocking: TTabSheet;
    lvBlockList: TListView;
    btnBLAdd, btnBLEdit, btnBLDelete: TButton;
    btnBLMoveUp, btnBLMoveDown: TButton;
    cboBLDefault: TComboBox;
    procedure btnBLAddClick(Sender: TObject);
    procedure btnBLEditClick(Sender: TObject);
    procedure btnBLDeleteClick(Sender: TObject);
    procedure btnBLMoveUpClick(Sender: TObject);
    procedure btnBLMoveDownClick(Sender: TObject);

  ADD to private:
    FBlockList: TNMBlockList;
    procedure LoadBlockListToList;

  ADD to uses:
    NM_BlockList
  =========================================================================== }

{ In FormCreate, add: }
{
  Nav.Items.Add('Blocking');
  cboBLDefault.Items.CommaText := 'Allow,Block';
  cboBLDefault.ItemIndex := 0;
  FBlockList := TNMBlockList.Create;
  FBlockList.LoadFromFile(ExtractFilePath(ParamStr(0)) + BLOCKLIST_FILENAME);
  LoadBlockListToList;
}

{ In FormDestroy: FBlockList.Free; }
{ In btnOKClick: FBlockList.SaveToFile(...); }

procedure TfrmConfig.LoadBlockListToList;
var
  i: Integer;
  E: TBlockEntry;
  Item: TListItem;
begin
  lvBlockList.Items.Clear;
  for i := 0 to FBlockList.Count - 1 do
  begin
    E := FBlockList.Entries[i];
    Item := lvBlockList.Items.Add;
    case E.Action of
      baAllow:   Item.Caption := 'ALLOW';
      baBlock:   Item.Caption := 'BLOCK';
      baForward: Item.Caption := 'FORWARD';
    end;
    Item.SubItems.Add(E.Pattern);
    if E.Action = baForward then
      Item.SubItems.Add(E.ForwardHost + ':' + IntToStr(E.ForwardPort))
    else
      Item.SubItems.Add('');
    Item.SubItems.Add(E.Comment);
  end;
end;

procedure TfrmConfig.btnBLAddClick(Sender: TObject);
var
  ActionStr, PatternStr, ForwardStr, CommentStr: string;
  Action: TBlockAction;
  FwdHost: string;
  FwdPort: Integer;
  ColonPos: Integer;
begin
  ActionStr := 'BLOCK';
  if not InputQuery('Add Rule', 'Action (ALLOW, BLOCK, FORWARD):', ActionStr) then Exit;
  ActionStr := UpperCase(Trim(ActionStr));
  if ActionStr = 'ALLOW' then Action := baAllow
  else if ActionStr = 'BLOCK' then Action := baBlock
  else if ActionStr = 'FORWARD' then Action := baForward
  else begin MessageDlg('Invalid action.', mtError, [mbOK], 0); Exit; end;

  PatternStr := '';
  if not InputQuery('Add Rule', 'IP pattern (exact, 192.168.*, or 10.0.0.0/8):', PatternStr) then Exit;

  FwdHost := ''; FwdPort := 23;
  if Action = baForward then
  begin
    ForwardStr := '';
    if not InputQuery('Add Rule', 'Forward to (host:port):', ForwardStr) then Exit;
    ColonPos := Pos(':', ForwardStr);
    if ColonPos > 0 then begin
      FwdHost := Copy(ForwardStr, 1, ColonPos - 1);
      FwdPort := StrToIntDef(Copy(ForwardStr, ColonPos + 1, Length(ForwardStr)), 23);
    end else
      FwdHost := ForwardStr;
  end;

  CommentStr := '';
  InputQuery('Add Rule', 'Comment (optional):', CommentStr);

  FBlockList.AddEntry(Action, PatternStr, FwdHost, FwdPort, CommentStr);
  LoadBlockListToList;
end;

procedure TfrmConfig.btnBLEditClick(Sender: TObject);
begin
  { TODO: edit selected rule — reuse Add dialog with pre-filled values }
  MessageDlg('Select entry, delete, and re-add with new values.', mtInformation, [mbOK], 0);
end;

procedure TfrmConfig.btnBLDeleteClick(Sender: TObject);
var
  Sel: TListItem;
begin
  Sel := lvBlockList.Selected;
  if Sel = nil then begin MessageDlg('Select a rule.', mtInformation, [mbOK], 0); Exit; end;
  if MessageDlg('Delete this rule?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FBlockList.DeleteEntry(Sel.Index);
    LoadBlockListToList;
  end;
end;

procedure TfrmConfig.btnBLMoveUpClick(Sender: TObject);
var
  Sel: TListItem;
  Idx: Integer;
begin
  Sel := lvBlockList.Selected;
  if (Sel = nil) or (Sel.Index = 0) then Exit;
  Idx := Sel.Index;
  FBlockList.FEntries.Exchange(Idx, Idx - 1);
  LoadBlockListToList;
  lvBlockList.Items[Idx - 1].Selected := True;
end;

procedure TfrmConfig.btnBLMoveDownClick(Sender: TObject);
var
  Sel: TListItem;
  Idx: Integer;
begin
  Sel := lvBlockList.Selected;
  if (Sel = nil) or (Sel.Index >= FBlockList.Count - 1) then Exit;
  Idx := Sel.Index;
  FBlockList.FEntries.Exchange(Idx, Idx + 1);
  LoadBlockListToList;
  lvBlockList.Items[Idx + 1].Selected := True;
end;

