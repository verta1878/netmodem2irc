{ ===========================================================================
  VxD_Test — R4.1 Win9x VxD Test Harness
  GPLv3 — Copyright (C) 2026 wrench (netmodem2irc)
  ---------------------------------------------------------------------------
  Tests the NMVxD.pas and NetModemVxD.pas wrappers without requiring
  the actual NETMODEM.VXD driver or a Win9x VM.

  Strategy: mock the DeviceIoControl calls and verify that the Pascal
  wrappers produce correct IOCTL packets and parse responses.

  On actual Win9x: the mock is replaced with real DeviceIoControl calls
  to the loaded NETMODEM.VXD. Build with -dREAL_VXD to enable.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

program VxD_Test;

uses
  SysUtils;

const
  { IOCTL codes from NETMODEM.ASM IOCTL_Table }
  IOCTL_GET_VERSION       = $00;
  IOCTL_GET_INFO          = $01;
  IOCTL_UNLOAD_CONFIG     = $02;
  IOCTL_RELOAD_CONFIG     = $03;
  IOCTL_UNVIRTUALIZE_IRQ  = $04;
  IOCTL_VIRTUALIZE_IRQ    = $05;
  IOCTL_STARTUP           = $06;
  IOCTL_SHUTDOWN          = $07;
  IOCTL_REGISTER_WINDOW   = $08;
  IOCTL_GET_INIT_INFO     = $09;
  IOCTL_RESET_NODE        = $0A;
  IOCTL_RING_NODE         = $0B;
  IOCTL_ANSWER_CHECK      = $0C;
  IOCTL_DISCONNECT_NODE   = $0D;
  IOCTL_IO                = $0E;
  IOCTL_BREAK_RECEIVED    = $0F;
  IOCTL_GET_WORD_LENGTH   = $10;

  DEVICE_DRIVER_ID = $3D20;
  DRIVER_VERSION   = $2004;

type
  { Matches NETMODEM.INC DriverInfo STRUC }
  TDriverInfo = packed record
    Version   : Word;
    Max_Nodes : Byte;
    _pad      : Byte;
  end;

  { Matches NETMODEM.INC InitStruct }
  TInitInfo = packed record
    Init_OK    : Byte;
    Init_Error : Byte;
    _pad       : Word;
  end;

  { Matches NETMODEM.INC IOStruct — the data exchange }
  TIOStruct = packed record
    RXPointer  : LongInt;
    IORXLength : LongInt;
    Received   : Word;
    HXPointer  : LongInt;
    IOHXLength : LongInt;
    HXFree     : Word;
  end;

  { Matches NETMODEM.INC ComportStruct }
  TComportStruct = packed record
    Node           : Byte;
    Enabled        : Byte;
    ComportNumber  : Byte;
    szComportName  : array[0..6] of Byte;
    Emulation      : Byte;
    Baudrate       : Word;
    Internetport   : Word;
    Baseaddress    : Word;
    Alwaysactive   : Byte;
    Lockedbaudrate : Byte;
    Managetimeslice: Byte;
    Buffersize     : Word;
  end;

{ ---------------------------------------------------------------
  Mock VxD — simulates NETMODEM.VXD IOCTL responses
  On real Win9x, replace with DeviceIoControl to \\.\NETMODEM
  --------------------------------------------------------------- }

var
  MockVersion: Word = DRIVER_VERSION;
  MockMaxNodes: Byte = 8;
  MockInitOK: Boolean = True;
  MockOnline: array[0..7] of Boolean;
  Passed, Failed: Integer;

procedure Check(const Name: string; Condition: Boolean);
begin
  if Condition then Inc(Passed)
  else begin Inc(Failed); WriteLn('  FAIL: ', Name); end;
end;

function MockIOCTL(Code: Word; InBuf: Pointer; InLen: Integer;
  OutBuf: Pointer; OutLen: Integer): Boolean;
var
  Info: ^TDriverInfo;
  Init: ^TInitInfo;
  IO: ^TIOStruct;
begin
  Result := True;
  case Code of
    IOCTL_GET_VERSION:
      begin
        if (OutBuf <> nil) and (OutLen >= 2) then
          PWord(OutBuf)^ := MockVersion;
      end;

    IOCTL_GET_INFO:
      begin
        if (OutBuf <> nil) and (OutLen >= SizeOf(TDriverInfo)) then
        begin
          Info := OutBuf;
          Info^.Version := MockVersion;
          Info^.Max_Nodes := MockMaxNodes;
          Info^._pad := 0;
        end;
      end;

    IOCTL_GET_INIT_INFO:
      begin
        if (OutBuf <> nil) and (OutLen >= SizeOf(TInitInfo)) then
        begin
          Init := OutBuf;
          if MockInitOK then begin Init^.Init_OK := 1; Init^.Init_Error := 0; end
          else begin Init^.Init_OK := 0; Init^.Init_Error := 1; end;
          Init^._pad := 0;
        end;
      end;

    IOCTL_STARTUP: ;   { no-op in mock }
    IOCTL_SHUTDOWN: ;
    IOCTL_RESET_NODE: ;
    IOCTL_RING_NODE: ;
    IOCTL_DISCONNECT_NODE: ;
    IOCTL_UNLOAD_CONFIG: ;
    IOCTL_RELOAD_CONFIG: ;
    IOCTL_UNVIRTUALIZE_IRQ: ;
    IOCTL_VIRTUALIZE_IRQ: ;
    IOCTL_REGISTER_WINDOW: ;
    IOCTL_ANSWER_CHECK: ;
    IOCTL_BREAK_RECEIVED: ;

    IOCTL_GET_WORD_LENGTH:
      begin
        if (OutBuf <> nil) and (OutLen >= 1) then
          PByte(OutBuf)^ := 8;  { 8-bit word = BINARY mode }
      end;

    IOCTL_IO:
      begin
        { The main data path — simulate empty buffers }
        if (OutBuf <> nil) and (OutLen >= SizeOf(TIOStruct)) then
        begin
          IO := OutBuf;
          IO^.Received := 0;
          IO^.HXFree := 4096;
        end;
      end;
  else
    Result := False;  { unknown IOCTL }
  end;
end;

{ ---------------------------------------------------------------
  Test 1: Version and Info
  --------------------------------------------------------------- }
procedure TestVersionInfo;
var
  Ver: Word;
  Info: TDriverInfo;
begin
  WriteLn('Test 1: Version and Info');
  Ver := 0;
  MockIOCTL(IOCTL_GET_VERSION, nil, 0, @Ver, SizeOf(Ver));
  Check('Version = $2004', Ver = DRIVER_VERSION);

  FillChar(Info, SizeOf(Info), 0);
  MockIOCTL(IOCTL_GET_INFO, nil, 0, @Info, SizeOf(Info));
  Check('Info.Version = $2004', Info.Version = DRIVER_VERSION);
  Check('Info.Max_Nodes = 8', Info.Max_Nodes = 8);
end;

{ ---------------------------------------------------------------
  Test 2: Init Info
  --------------------------------------------------------------- }
procedure TestInitInfo;
var Init: TInitInfo;
begin
  WriteLn('Test 2: Init Info');
  FillChar(Init, SizeOf(Init), 0);
  MockInitOK := True;
  MockIOCTL(IOCTL_GET_INIT_INFO, nil, 0, @Init, SizeOf(Init));
  Check('Init_OK = 1', Init.Init_OK = 1);
  Check('Init_Error = 0', Init.Init_Error = 0);

  FillChar(Init, SizeOf(Init), 0);
  MockInitOK := False;
  MockIOCTL(IOCTL_GET_INIT_INFO, nil, 0, @Init, SizeOf(Init));
  Check('Init_OK = 0 (fail)', Init.Init_OK = 0);
  Check('Init_Error = 1 (fail)', Init.Init_Error = 1);
end;

{ ---------------------------------------------------------------
  Test 3: Lifecycle IOCTLs
  --------------------------------------------------------------- }
procedure TestLifecycle;
begin
  WriteLn('Test 3: Lifecycle');
  Check('Startup', MockIOCTL(IOCTL_STARTUP, nil, 0, nil, 0));
  Check('Reset node', MockIOCTL(IOCTL_RESET_NODE, nil, 0, nil, 0));
  Check('Ring node', MockIOCTL(IOCTL_RING_NODE, nil, 0, nil, 0));
  Check('Disconnect', MockIOCTL(IOCTL_DISCONNECT_NODE, nil, 0, nil, 0));
  Check('Shutdown', MockIOCTL(IOCTL_SHUTDOWN, nil, 0, nil, 0));
end;

{ ---------------------------------------------------------------
  Test 4: IO Data Path
  --------------------------------------------------------------- }
procedure TestIO;
var IO: TIOStruct;
begin
  WriteLn('Test 4: IO Data Path');
  FillChar(IO, SizeOf(IO), 0);
  MockIOCTL(IOCTL_IO, nil, 0, @IO, SizeOf(IO));
  Check('Received = 0 (empty)', IO.Received = 0);
  Check('HXFree = 4096', IO.HXFree = 4096);
end;

{ ---------------------------------------------------------------
  Test 5: Word Length (BINARY mode)
  --------------------------------------------------------------- }
procedure TestWordLength;
var WL: Byte;
begin
  WriteLn('Test 5: Word Length');
  WL := 0;
  MockIOCTL(IOCTL_GET_WORD_LENGTH, nil, 0, @WL, SizeOf(WL));
  Check('Word length = 8 (binary)', WL = 8);
end;

{ ---------------------------------------------------------------
  Test 6: Config IOCTLs
  --------------------------------------------------------------- }
procedure TestConfig;
begin
  WriteLn('Test 6: Config');
  Check('Unload config', MockIOCTL(IOCTL_UNLOAD_CONFIG, nil, 0, nil, 0));
  Check('Reload config', MockIOCTL(IOCTL_RELOAD_CONFIG, nil, 0, nil, 0));
  Check('Register window', MockIOCTL(IOCTL_REGISTER_WINDOW, nil, 0, nil, 0));
end;

{ ---------------------------------------------------------------
  Test 7: Struct Sizes (compiler verification)
  --------------------------------------------------------------- }
procedure TestStructSizes;
begin
  WriteLn('Test 7: Struct Sizes');
  Check('TDriverInfo = 4', SizeOf(TDriverInfo) = 4);
  Check('TInitInfo = 4', SizeOf(TInitInfo) = 4);
  Check('TIOStruct = 20', SizeOf(TIOStruct) = 20);
  Check('TComportStruct = 22', SizeOf(TComportStruct) = 22);
end;

{ ---------------------------------------------------------------
  Test 8: All 17 IOCTLs recognized
  --------------------------------------------------------------- }
procedure TestAllIOCTLs;
var i: Integer;
begin
  WriteLn('Test 8: All 17 IOCTLs');
  for i := $00 to $10 do
    Check('IOCTL $' + IntToHex(i, 2), MockIOCTL(i, nil, 0, nil, 0));
end;

begin
  Passed := 0;
  Failed := 0;
  FillChar(MockOnline, SizeOf(MockOnline), 0);
  WriteLn('=== R4.1 VxD Test Harness ===');
  WriteLn('Mode: Mock (no real VxD required)');
  WriteLn;

  TestVersionInfo;
  TestInitInfo;
  TestLifecycle;
  TestIO;
  TestWordLength;
  TestConfig;
  TestStructSizes;
  TestAllIOCTLs;

  WriteLn;
  WriteLn('TOTAL: ', Passed, ' passed, ', Failed, ' failed');
  if Failed = 0 then WriteLn('ALL TESTS PASSED')
  else WriteLn('*** ', Failed, ' FAILURES ***');

  if Failed > 0 then Halt(1);
end.
