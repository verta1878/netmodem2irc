object Form3: TForm3
  Left = 654
  Top = 159
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Global Configuration'
  ClientHeight = 213
  ClientWidth = 292
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ListView1: TListView
    Left = 5
    Top = 5
    Width = 200
    Height = 150
    Checkboxes = True
    <collection>
      Caption = 'Select the destination node(s).'
      MaxWidth = 180
      MinWidth = 180
      Width = 180
    HotTrack = True
    HotTrackStyles = []
    MultiSelect = True
    ReadOnly = True
    TabOrder = 0
    ViewStyle = vsReport
  end
  object Button1: TButton
    Left = 211
    Top = 10
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 211
    Top = 43
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
  end
  object Button3: TButton
    Left = 211
    Top = 135
    Width = 20
    Height = 20
    Caption = '...'
    TabOrder = 3
    OnClick = Button3Click
  end
  object Panel1: TPanel
    Left = 5
    Top = 162
    Width = 200
    Height = 45
    BevelInner = bvRaised
    BevelOuter = bvLowered
    TabOrder = 4
    object Label1: TLabel
      Left = 90
      Top = 6
      Width = 15
      Height = 13
      Caption = '     '
    end
    object Label2: TLabel
      Left = 80
      Top = 23
      Width = 15
      Height = 13
      Caption = '     '
    end
    object StaticText1: TStaticText
      Left = 10
      Top = 6
      Width = 81
      Height = 17
      Caption = 'Source section: '
      TabOrder = 0
    end
    object StaticText2: TStaticText
      Left = 10
      Top = 23
      Width = 71
      Height = 17
      Caption = 'Source node: '
      TabOrder = 1
    end
  end
end