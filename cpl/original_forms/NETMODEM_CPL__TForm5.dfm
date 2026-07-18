object Form5: TForm5
  Left = 651
  Top = 172
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Icon Legend'
  ClientHeight = 148
  ClientWidth = 172
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poScreenCenter
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  TextHeight = 13
  object ListView1: TListView
    Left = 1
    Top = 2
    Width = 170
    Height = 145
    <collection>
      Caption = 'None'
      Width = 150
    HotTrackStyles = []
    Items.Data = <binary 327 bytes>
    ReadOnly = True
    ShowColumnHeaders = False
    SmallImages = Form4.ImageList1
    TabOrder = 0
    ViewStyle = vsReport
  end
end