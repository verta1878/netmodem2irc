{ ===========================================================================
  netmodem2irc - part of the NetModem/32 revival
  Copyright (C) 2025-2026 Antonio Rico (Reapern66 / verta1878)

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.

  Dedrick Allen's original NetModem/32 material preserved in driver/src/,
  history/ and cpl/original_forms/ remains under GPLv2 - see LICENSES.md.
  =========================================================================== }

unit SplashForm;
{ Startup splash — rebuilt from NETMODEM.EXE::TSplashForm. }
{$MODE OBJFPC}{$H+}
interface
uses Classes, SysUtils, Forms, ExtCtrls, StdCtrls;
type
  TfrmSplash = class(TForm)
    Image1: TImage;
    lblVersion: TLabel;
  end;
var
  frmSplash: TfrmSplash;
implementation
{$R *.lfm}
end.
