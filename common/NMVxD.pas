unit NMVxD;
{ ===========================================================================
  NetModem 2 — Free Pascal / Lazarus interface unit for NETMODEM.VXD
  ---------------------------------------------------------------------------
  Reconstructed from the recovered MASM source (NETMODEM.ASM / NETMODEM.INC).
  Wraps the Ring-0 VxD's Ring-3 control interface so a Lazarus host/GUI app can
  drive the recovered driver WITHOUT the old Delphi ShortcutBar dependency.

  Target: Path A (Win9x / 86Box / PCem / VirtualBox running Win98).
  For Path B (modern Windows) point the same GUI at a com0com virtual port
  instead of the VxD and ignore the CreateFile/DeviceIoControl parts here.

  NOTE on calling convention (see guide §4.2): this driver passes the NODE
  index — and for RegisterServerWindow the HWND — through the value pointed to
  by lpcbBytesReturned, NOT through the in-buffer. That quirk is encapsulated
  in DoIoctl below.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  {$IFDEF WINDOWS}Windows,{$ENDIF} SysUtils;

{$IFNDEF WINDOWS}
type
  THandle = LongInt;
  HWND = LongInt;
  DWORD = LongWord;
const
  INVALID_HANDLE_VALUE = THandle(-1);
{$ENDIF}

const
  { --- driver identity (NETMODEM.INC) --- }
  NETMODEM_DEVICE_ID   = $3D20;
  NETMODEM_VERSION     = $2004;          // 2.0.0.4
  NETMODEM_VXD_NAME    = '\\.\NETMODEM.VXD';

  { --- IOCTL control codes (IOCTL_Table order, $00..$10) --- }
  IOCTL_GET_VERSION       = $00;
  IOCTL_GET_INFO          = $01;   // out: TDriverInfo
  IOCTL_UNLOAD_CONFIG     = $02;
  IOCTL_RELOAD_CONFIG     = $03;
  IOCTL_UNVIRTUALIZE_IRQ  = $04;
  IOCTL_VIRTUALIZE_IRQ    = $05;
  IOCTL_STARTUP           = $06;
  IOCTL_SHUTDOWN          = $07;
  IOCTL_REGISTER_WINDOW   = $08;   // HWND via node-slot (see DoIoctl)
  IOCTL_GET_INIT_INFO     = $09;   // out: TInitStruct
  IOCTL_RESET_NODE        = $0A;
  IOCTL_RING_NODE         = $0B;
  IOCTL_ANSWER_CHECK      = $0C;
  IOCTL_DISCONNECT_NODE   = $0D;
  IOCTL_IO                = $0E;   // in/out: TIOStruct  (the byte data path)
  IOCTL_BREAK_RECEIVED    = $0F;
  IOCTL_GET_WORD_LENGTH   = $10;

  { --- messages the driver POSTs to the registered window (WM_USER=$0400) --- }
  WM_USER_BASE           = $0400;
  CM_CONNECT_NODE        = WM_USER_BASE + 409;  // $0599  open the socket
  CM_DISCONNECT_NODE     = WM_USER_BASE + 410;  // $059A  close the socket
  CM_SEND_REMOTE_BREAK   = WM_USER_BASE + 417;  // $05A1  send telnet BREAK
  CM_WONT_BINARY         = WM_USER_BASE + 419;  // $05A3
  CM_WILL_BINARY         = WM_USER_BASE + 420;  // $05A4

  { --- emulation modes --- }
  emUART   = 0;
  emFOSSIL = 1;

  { --- result codes --- }
  rsOK = 0; rsBUSY = 1; rsERROR = 2; rsNOANSWER = 3;
  rsNOCARRIER = 4; rsNODIALTONE = 5; rsNORESULT = 6;

  { --- error codes --- }
  NO_ERROR_ = 0; PORT_ERROR = 1; MEMORY_ERROR = 2; IRQ_ERROR = 3;
  V86_MEMORY_ERROR = 4; CB_MEMORY_ERROR = 5; DRV_REG_ERROR = 6;

  { --- registry configuration location --- }
  REG_NETMODEM_KEY   = 'Software\Allen Software\NetModem';
  REG_CONFIG_VALUE   = 'ComportConfig';
  REG_IRQ_VALUE      = 'IRQ';

type
  { ComportStruct (NETMODEM.INC) — one per node. Packed to match the VxD. }
  TComportStruct = packed record
    Node            : Byte;
    Enabled         : Byte;
    ComportNumber   : Byte;
    szComportName   : array[0..6] of AnsiChar;
    Emulation       : Byte;      // emUART / emFOSSIL
    Baudrate        : Word;
    Internetport    : Word;      // TCP port for the network connection
    Baseaddress     : Word;
    Alwaysactive    : Byte;
    Lockedbaudrate  : Byte;
    Managetimeslice : Byte;
    Buffersize      : Word;
  end;

  { DriverInfo (IOCTL_GET_INFO) }
  TDriverInfo = packed record
    Version   : Word;
    Max_Nodes : Byte;
  end;

  { InitStruct (IOCTL_GET_INIT_INFO) }
  TInitStruct = packed record
    Init_OK    : Byte;   // Boolean
    Init_Error : Byte;   // one of the error codes above
  end;

  { IOStruct (IOCTL_IO) — RX = toward network, HX = from network }
  TIOStruct = packed record
    RXPointer  : DWORD;   // ptr to bytes the game wrote (send to socket)
    IORXLength : DWORD;
    Received   : Word;
    HXPointer  : DWORD;   // ptr to buffer for bytes from socket (give to game)
    IOHXLength : DWORD;
    HXFree     : Word;
  end;

  { Thin wrapper around the VxD handle. }
  TNetModemDriver = class
  private
    FHandle : THandle;
    function DoIoctl(Code: DWORD; NodeOrHwnd: DWORD;
                     Buf: Pointer; BufSize: DWORD): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function IsOpen: Boolean;

    function GetDriverInfo(out Info: TDriverInfo): Boolean;
    function RegisterServerWindow(AWnd: HWND): Boolean;
    function GetInitInfo(Node: Byte; out Init: TInitStruct): Boolean;

    function Startup(Node: Byte): Boolean;
    function Shutdown(Node: Byte): Boolean;
    function ReloadConfig(Node: Byte): Boolean;
    function RingNode(Node: Byte): Boolean;
    function AnswerCheck(Node: Byte): Boolean;
    function DisconnectNode(Node: Byte): Boolean;
    function ResetNode(Node: Byte): Boolean;

    { Move bytes both directions for one node. Fill IO.RXPointer/HXPointer
      with your own buffers before calling. }
    function IO(Node: Byte; var AIo: TIOStruct): Boolean;
  end;

implementation

{$IFDEF WINDOWS}
constructor TNetModemDriver.Create;
begin
  inherited Create;
  FHandle := CreateFile(NETMODEM_VXD_NAME, 0, 0, nil, 0,
                        FILE_FLAG_DELETE_ON_CLOSE, 0);
end;

destructor TNetModemDriver.Destroy;
begin
  if FHandle <> INVALID_HANDLE_VALUE then
    CloseHandle(FHandle);
  inherited Destroy;
end;

function TNetModemDriver.IsOpen: Boolean;
begin
  Result := FHandle <> INVALID_HANDLE_VALUE;
end;

function TNetModemDriver.DoIoctl(Code: DWORD; NodeOrHwnd: DWORD;
                                 Buf: Pointer; BufSize: DWORD): Boolean;
var
  Slot     : DWORD;
  Returned : DWORD;
begin
  Result := False;
  if not IsOpen then Exit;
  Slot := NodeOrHwnd;
  Result := DeviceIoControl(FHandle, Code,
              Buf, BufSize,
              Buf, BufSize,
              @Slot,
              nil);
  Returned := Slot;
  if Returned = 0 then ;
end;
{$ELSE}
{ Non-Windows stubs — driver interface not available on this platform }
constructor TNetModemDriver.Create;
begin
  inherited Create;
  FHandle := INVALID_HANDLE_VALUE;
end;

destructor TNetModemDriver.Destroy;
begin
  inherited Destroy;
end;

function TNetModemDriver.IsOpen: Boolean;
begin
  Result := False;
end;

function TNetModemDriver.DoIoctl(Code: DWORD; NodeOrHwnd: DWORD;
                                 Buf: Pointer; BufSize: DWORD): Boolean;
begin
  Result := False;
end;
{$ENDIF}

function TNetModemDriver.GetDriverInfo(out Info: TDriverInfo): Boolean;
begin
  FillChar(Info, SizeOf(Info), 0);
  Result := DoIoctl(IOCTL_GET_INFO, 0, @Info, SizeOf(Info));
end;

function TNetModemDriver.RegisterServerWindow(AWnd: HWND): Boolean;
begin
  { HWND travels through the node/HWND channel. }
  Result := DoIoctl(IOCTL_REGISTER_WINDOW, DWORD(AWnd), nil, 0);
end;

function TNetModemDriver.GetInitInfo(Node: Byte; out Init: TInitStruct): Boolean;
begin
  FillChar(Init, SizeOf(Init), 0);
  Result := DoIoctl(IOCTL_GET_INIT_INFO, Node, @Init, SizeOf(Init));
end;

function TNetModemDriver.Startup(Node: Byte): Boolean;
begin Result := DoIoctl(IOCTL_STARTUP, Node, nil, 0); end;

function TNetModemDriver.Shutdown(Node: Byte): Boolean;
begin Result := DoIoctl(IOCTL_SHUTDOWN, Node, nil, 0); end;

function TNetModemDriver.ReloadConfig(Node: Byte): Boolean;
begin Result := DoIoctl(IOCTL_RELOAD_CONFIG, Node, nil, 0); end;

function TNetModemDriver.RingNode(Node: Byte): Boolean;
begin Result := DoIoctl(IOCTL_RING_NODE, Node, nil, 0); end;

function TNetModemDriver.AnswerCheck(Node: Byte): Boolean;
begin Result := DoIoctl(IOCTL_ANSWER_CHECK, Node, nil, 0); end;

function TNetModemDriver.DisconnectNode(Node: Byte): Boolean;
begin Result := DoIoctl(IOCTL_DISCONNECT_NODE, Node, nil, 0); end;

function TNetModemDriver.ResetNode(Node: Byte): Boolean;
begin Result := DoIoctl(IOCTL_RESET_NODE, Node, nil, 0); end;

function TNetModemDriver.IO(Node: Byte; var AIo: TIOStruct): Boolean;
begin
  Result := DoIoctl(IOCTL_IO, Node, @AIo, SizeOf(AIo));
end;

end.
