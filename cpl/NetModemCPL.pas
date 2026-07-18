library NetModemCPL;
{ NetModem/32 Control Panel Applet (.cpl)
  Exports CPlApplet. Appears in Control Panel.
  Reads/writes HKLM\Software\Allen Software\NetModem registry keys. }
{$MODE OBJFPC}{$H+}
{$R NetModemCPL.res}
uses
  Windows, SysUtils, Registry, NMVxD, NM_DefaultConfig;

const
  CPL_INIT       = 1;
  CPL_GETCOUNT   = 2;
  CPL_NEWINQUIRE = 8;
  CPL_DBLCLK     = 5;
  CPL_STOP       = 6;
  CPL_EXIT       = 7;

type
  TNewCplInfo = packed record
    dwSize : DWORD;
    dwFlags: DWORD;
    dwHelpContext: DWORD;
    lData  : LPARAM;
    hIcon  : HICON;
    szName : array[0..31] of AnsiChar;
    szInfo : array[0..63] of AnsiChar;
    szHelpFile: array[0..127] of AnsiChar;
  end;
  PNewCplInfo = ^TNewCplInfo;

procedure ShowConfigDialog(hOwner: HWND);
var
  Reg: TRegistry;
  Cfg: TRegComportStruct;
  Msg, sEnabled, sMode: string;
begin
  if not RegistryConfigExists then
    WriteDefaultRegistry;

  FillChar(Cfg, SizeOf(Cfg), 0);
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly(REG_KEY) then
    begin
      if Reg.GetDataSize(REG_CONFIG_VALUE) >= SizeOf(Cfg) then
        Reg.ReadBinaryData(REG_CONFIG_VALUE, Cfg, SizeOf(Cfg));
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;

  if Cfg.Enabled = 1 then sEnabled := 'Yes' else sEnabled := 'No';
  if Cfg.Emulation = 1 then sMode := 'FOSSIL' else sMode := 'UART';

  Msg := 'NetModem/32 Configuration' + #13#10 +
         '------------------------' + #13#10 +
         'Node: ' + IntToStr(Cfg.Node) + #13#10 +
         'Enabled: ' + sEnabled + #13#10 +
         'COM Port: ' + IntToStr(Cfg.ComportNumber) + #13#10 +
         'Baud Rate: ' + IntToStr(Cfg.Baudrate) + #13#10 +
         'Mode: ' + sMode + #13#10 +
         'Telnet Port: ' + IntToStr(Cfg.Internetport) + #13#10 +
         'Buffer Size: ' + IntToStr(Cfg.Buffersize) + #13#10 +
         #13#10 +
         'Registry: HKLM\' + REG_KEY;

  MessageBox(hOwner, PChar(Msg), 'NetModem/32', MB_OK or MB_ICONINFORMATION);
end;

function CPlApplet(hWndCPl: HWND; uMsg: DWORD;
                   lParam1, lParam2: LPARAM): LongInt; stdcall;
var
  NCI: PNewCplInfo;
begin
  Result := 0;
  case uMsg of
    CPL_INIT:      Result := 1;
    CPL_GETCOUNT:  Result := 1;
    CPL_NEWINQUIRE:
    begin
      NCI := PNewCplInfo(lParam2);
      FillChar(NCI^, SizeOf(TNewCplInfo), 0);
      NCI^.dwSize := SizeOf(TNewCplInfo);
      NCI^.hIcon := LoadIcon(0, IDI_APPLICATION);
      StrPCopy(@NCI^.szName[0], 'NetModem/32');
      StrPCopy(@NCI^.szInfo[0], 'Configure NetModem/32 FOSSIL Telnet Server');
    end;
    CPL_DBLCLK:    ShowConfigDialog(hWndCPl);
    CPL_STOP:      ;
    CPL_EXIT:      ;
  end;
end;

exports
  CPlApplet;

begin
end.
