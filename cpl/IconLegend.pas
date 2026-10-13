{ ===========================================================================
  netmodem2irc - part of the NetModem/32 revival
  Copyright (C) 2025-2026 Antonio Rico (Reapern66 / verta1878)
  GPLv3. Ported from NETMODEM_CPL__TForm5.dfm (derk's original).
  =========================================================================== }

unit IconLegend;
{ Icon Legend dialog — shows what each status icon color means.
  Called from Help menu or status bar double-click. }
{$MODE OBJFPC}{$H+}
interface
uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics;
type
  TfrmIconLegend = class(TForm)
    imgGreen, imgYellow, imgRed, imgBlue: TImage;
    lblGreen, lblYellow, lblRed, lblBlue: TLabel;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
  end;
implementation
{$R *.lfm}

procedure TfrmIconLegend.FormCreate(Sender: TObject);
  procedure FillIcon(Img: TImage; C: TColor);
  begin
    Img.Picture.Bitmap.SetSize(16, 16);
    Img.Picture.Bitmap.Canvas.Brush.Color := C;
    Img.Picture.Bitmap.Canvas.FillRect(0, 0, 16, 16);
  end;
begin
  FillIcon(imgGreen, clGreen);
  FillIcon(imgYellow, clYellow);
  FillIcon(imgRed, clRed);
  FillIcon(imgBlue, clBlue);
end;

end.
