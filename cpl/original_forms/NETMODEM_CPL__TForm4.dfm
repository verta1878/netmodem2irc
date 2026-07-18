object Form4: TForm4
  Left = 365
  Top = 156
  Width = 600
  Height = 277
  Caption = 'View Log'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  Icon.Data = <binary 766 bytes>
  KeyPreview = True
  OldCreateOrder = False
  OnActivate = FormActivate
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ToolBar1: TToolBar
    Left = 0
    Top = 3
    Width = 331
    Height = 25
    Align = alNone
    ButtonWidth = 26
    Caption = '     '
    EdgeBorders = []
    Flat = True
    Images = ImageList1
    TabOrder = 0
    object ToolButton1: TToolButton
      Left = 0
      Top = 0
      Width = 8
      Caption = 'ToolButton1'
      Style = tbsSeparator
    end
    object ComboBox1: TComboBox
      Left = 8
      Top = 0
      Width = 135
      Height = 21
      HelpContext = 25
      Style = csDropDownList
      ItemHeight = 13
      TabOrder = 0
      OnChange = ComboBox1Change
    end
    object ToolButton5: TToolButton
      Left = 143
      Top = 0
      Width = 8
      Caption = 'ToolButton5'
      ImageIndex = 5
      Style = tbsSeparator
    end
    object ToolButton6: TToolButton
      Left = 151
      Top = 0
      Hint = 'Refresh'
      Caption = 'ToolButton6'
      ImageIndex = 5
      ParentShowHint = False
      ShowHint = True
      OnClick = ToolButton6Click
    end
    object ToolButton8: TToolButton
      Left = 177
      Top = 0
      Hint = 'Abort'
      Caption = 'ToolButton8'
      ImageIndex = 6
      ParentShowHint = False
      ShowHint = True
      OnClick = ToolButton8Click
    end
    object ToolButton10: TToolButton
      Left = 203
      Top = 0
      Hint = 'Legend'
      Caption = 'ToolButton10'
      ImageIndex = 7
      ParentShowHint = False
      ShowHint = True
      OnClick = ToolButton10Click
    end
    object ToolButton7: TToolButton
      Left = 229
      Top = 0
      Width = 5
      Caption = 'ToolButton7'
      ImageIndex = 5
      Style = tbsSeparator
    end
    object ToolButton2: TToolButton
      Left = 234
      Top = 0
      Hint = 'Print'
      Caption = 'ToolButton2'
      ImageIndex = 3
      ParentShowHint = False
      ShowHint = True
      OnClick = ToolButton2Click
    end
    object ToolButton9: TToolButton
      Left = 260
      Top = 0
      Width = 8
      Caption = 'ToolButton9'
      ImageIndex = 5
      Style = tbsSeparator
    end
    object ToolButton3: TToolButton
      Left = 268
      Top = 0
      Hint = 'Clear'
      Caption = 'ToolButton3'
      ImageIndex = 4
      ParentShowHint = False
      ShowHint = True
      OnClick = ToolButton3Click
    end
    object ToolButton4: TToolButton
      Left = 294
      Top = 0
      Width = 8
      Caption = 'ToolButton4'
      ImageIndex = 4
      Style = tbsSeparator
    end
  end
  object ListView1: TListView
    Left = 1
    Top = 28
    Width = 590
    Height = 201
    Anchors = [akLeft, akTop, akRight, akBottom]
    <collection>
      MaxWidth = 20
      MinWidth = 20
      Width = 20
      Alignment = taCenter
      Caption = '#'
      MaxWidth = 25
      MinWidth = 25
      Width = 25
      Caption = 'Date/Time'
      Width = 175
      Caption = 'Information'
      Width = 350
    HotTrackStyles = []
    ReadOnly = True
    SmallImages = ImageList1
    TabOrder = 1
    ViewStyle = vsReport
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 231
    Width = 592
    Height = 19
    <collection>
      Text = '     '
      Width = 50
    SimplePanel = False
  end
  object ImageList1: TImageList
    Left = 13
    Top = 184
    Bitmap = <binary 12966 bytes>
  end
  object PrintDialog1: TPrintDialog
    Left = 69
    Top = 184
  end
  object FontDialog1: TFontDialog
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    Device = fdBoth
    MinFontSize = 0
    MaxFontSize = 0
    Left = 41
    Top = 184
  end
end