unit InnoComponentReg;
{$MODE DELPHI}
{ Registers custom Inno Setup components with LCL's streaming system
  so that LFM resources can instantiate them at runtime. }

interface

procedure RegisterInnoComponents;

implementation

uses
  Classes,
  BitmapImage, NewStaticText, NewCheckListBox, NewNotebook,
  BidiCtrls, NewProgressBar, PasswordEdit, FolderTreeView,
  RichEditViewer, DropListBox, NewTabSet;

procedure RegisterInnoComponents;
begin
  RegisterClass(TBitmapImage);
  RegisterClass(TNewStaticText);
  RegisterClass(TNewCheckListBox);
  RegisterClass(TNewNotebook);
  RegisterClass(TNewNotebookPage);
  RegisterClass(TNewProgressBar);
  RegisterClass(TPasswordEdit);
  RegisterClass(TFolderTreeView);
  RegisterClass(TStartMenuFolderTreeView);
  RegisterClass(TRichEditViewer);
  RegisterClass(TDropListBox);
  RegisterClass(TNewTabSet);
  { BidiCtrls }
  RegisterClass(TNewEdit);
  RegisterClass(TNewMemo);
  RegisterClass(TNewComboBox);
  RegisterClass(TNewListBox);
  RegisterClass(TNewButton);
  RegisterClass(TNewRadioButton);
end;

initialization
  RegisterInnoComponents;

end.
