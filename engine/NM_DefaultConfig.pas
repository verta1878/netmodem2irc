unit NM_DefaultConfig;
{ ===========================================================================
  netmodem2irc — default registry configuration
  ---------------------------------------------------------------------------
  Writes factory defaults to the Windows registry so the VxD driver has a
  valid config on first run. The CPL (NMConfig) reads/writes the same keys.
  The server does NOT read config — the driver reads the registry directly.

  Registry key: HKLM\Software\Allen Software\NetModem
  Values:
    ComportConfig  REG_BINARY  array of TRegComportStruct (one per node)
    IRQ            REG_DWORD   IRQ number (0 = no virtualization)

  Original NetModem v1 defaults:
    Node 0, COM3, 38400 baud, FOSSIL mode, telnet port 23, 2048 byte buffers
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils;

const
  DEFAULT_COMPORT     = 3;
  DEFAULT_BAUD        = 38400;
  DEFAULT_TELNET_PORT = 23;
  DEFAULT_BUFSIZE     = 2048;
  DEFAULT_BASEADDR    = $03E8;    { standard COM3 I/O base }

  REG_KEY          = 'Software\Allen Software\NetModem';
  REG_CONFIG_VALUE = 'ComportConfig';
  REG_IRQ_VALUE    = 'IRQ';

type
  { Matches the VxD's ComportStruct byte-for-byte (22 bytes per node) }
  TRegComportStruct = packed record
    Node            : Byte;
    Enabled         : Byte;
    ComportNumber   : Byte;
    szComportName   : array[0..6] of AnsiChar;
    Emulation       : Byte;      { 0=UART, 1=FOSSIL }
    Baudrate        : Word;
    Internetport    : Word;
    Baseaddress     : Word;
    Alwaysactive    : Byte;
    Lockedbaudrate  : Byte;
    Managetimeslice : Byte;
    Buffersize      : Word;
  end;

{ Write v1 factory defaults to registry. Windows only — no-op elsewhere. }
procedure WriteDefaultRegistry;

{ Check if registry config exists. Windows only — False elsewhere. }
function RegistryConfigExists: Boolean;

implementation

{$IFDEF WINDOWS}
uses Registry, Windows;
{$ENDIF}

procedure WriteDefaultRegistry;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
  Cfg: TRegComportStruct;
  IRQ: DWORD;
begin
  FillChar(Cfg, SizeOf(Cfg), 0);
  Cfg.Node := 1;
  Cfg.Enabled := 1;
  Cfg.ComportNumber := DEFAULT_COMPORT;
  Cfg.szComportName := 'COM3'#0#0#0;
  Cfg.Emulation := 1;  { emFOSSIL }
  Cfg.Baudrate := DEFAULT_BAUD;
  Cfg.Internetport := DEFAULT_TELNET_PORT;
  Cfg.Baseaddress := DEFAULT_BASEADDR;
  Cfg.Alwaysactive := 0;
  Cfg.Lockedbaudrate := 1;
  Cfg.Managetimeslice := 1;
  Cfg.Buffersize := DEFAULT_BUFSIZE;

  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKey(REG_KEY, True) then
    begin
      Reg.WriteBinaryData(REG_CONFIG_VALUE, Cfg, SizeOf(Cfg));
      IRQ := 0;
      Reg.WriteBinaryData(REG_IRQ_VALUE, IRQ, SizeOf(IRQ));
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;
{$ELSE}
begin
end;
{$ENDIF}

function RegistryConfigExists: Boolean;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
begin
  Result := False;
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly(REG_KEY) then
    begin
      Result := Reg.ValueExists(REG_CONFIG_VALUE);
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

end.
