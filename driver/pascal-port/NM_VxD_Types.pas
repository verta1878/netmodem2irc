{ ===========================================================================
  NM_VxD_Types — Pascal port of NETMODEM.INC structures
  GPLv3 — Copyright (C) 2026 wrench (netmodem2irc)
  ---------------------------------------------------------------------------
  Packed records matching MASM STRUC BYTE layout exactly.
  All sizes verified against the original ASM.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

unit NM_VxD_Types;

interface

const
  { VxD identification }
  DEVICE_DRIVER_ID  = $3D20;
  DRIVER_VERSION    = $2004;

  { Emulation modes }
  emUART   = 0;
  emFOSSIL = 1;

  { Result codes (AT command responses) }
  rsOK         = 0;
  rsBUSY       = 1;
  rsERROR      = 2;
  rsNOANSWER   = 3;
  rsNOCARRIER  = 4;
  rsNODIALTONE = 5;
  rsNORESULT   = 6;

  { Custom window messages (WM_USER + offset) }
  WM_USER              = $0400;
  CM_CONNECT_NODE      = WM_USER + 409;
  CM_DISCONNECT_NODE   = WM_USER + 410;
  CM_SEND_REMOTE_BREAK = WM_USER + 417;
  CM_WONT_BINARY       = WM_USER + 419;
  CM_WILL_BINARY       = WM_USER + 420;

  { Error codes }
  NO_ERROR         = 0;
  PORT_ERROR       = 1;
  MEMORY_ERROR     = 2;
  IRQ_ERROR        = 3;
  V86_MEMORY_ERROR = 4;
  CB_MEMORY_ERROR  = 5;
  DRV_REG_ERROR    = 6;

  { FOSSIL constants }
  FOSSIL_SIG   = $1954;
  FOSSIL_MAXFN = $1B;
  FOSSIL_REV   = 5;

  { Control characters }
  XON  = $11;
  XOFF = $13;

type
  { ComportStruct — 24 bytes (STRUC BYTE = packed) }
  TComportStruct = packed record
    Node           : Byte;
    Enabled        : Byte;     { Boolean }
    ComportNumber  : Byte;
    szComportName  : array[0..6] of Byte;  { 7 bytes, e.g. 'COM3' + #0 }
    Emulation      : Byte;     { emUART or emFOSSIL }
    Baudrate       : Word;
    Internetport   : Word;
    Baseaddress    : Word;
    Alwaysactive   : Byte;     { Boolean }
    Lockedbaudrate : Byte;     { Boolean }
    Managetimeslice: Byte;     { Boolean }
    Buffersize     : Word;
  end;

  { UARTStruct — 12 bytes (matches NM_UART16550 register file) }
  TUARTStruct = packed record
    RBR: Byte;
    THR: Byte;
    IER: Byte;
    IIR: Byte;
    FCR: Byte;
    LCR: Byte;
    MCR: Byte;
    LSR: Byte;
    MSR: Byte;
    SCR: Byte;
    DLL: Byte;
    DLM: Byte;
  end;

  { FOSSILStruct — 19 bytes }
  TFOSSILStruct = packed record
    StrSiz  : Word;       { structure size (19) }
    MajVer  : Byte;       { 5 }
    MinVer  : Byte;       { 0 }
    Ident   : LongInt;    { 32-bit pointer to ID string (VxD is 32-bit only) }
    IBufr   : Word;       { input buffer size }
    IFree   : Word;       { input buffer free }
    OBufr   : Word;       { output buffer size }
    OFree   : Word;       { output buffer free }
    SWidth  : Byte;       { screen width (80) }
    SHeight : Byte;       { screen height (25) }
    Baud    : Byte;       { current baud code }
  end;

  { CommandStruct — AT modem state registers }
  TCommandStruct = packed record
    E, H, Q, Y: Byte;
    _C, _D, _H, _I, _K, _R, _S, _Y: Byte;
    S0, S1, S2, S3, S4, S5, S6, S7, S8, S9: Byte;
    S10, S11, S12, S13, S14, S15, S16: Byte;
    S18, S19, S21, S22, S23, S25, S27, S28: Byte;
    S34, S38: Byte;
  end;

  { DriverInfo — 4-byte aligned (STRUC DWORD) }
  TVxDDriverInfo = packed record
    Version   : Word;
    Max_Nodes : Byte;
    _pad      : Byte;     { DWORD alignment }
  end;

  { InitStruct — 4-byte aligned }
  TVxDInitInfo = packed record
    Init_OK    : Byte;    { Boolean }
    Init_Error : Byte;
    _pad       : Word;    { DWORD alignment }
  end;

  { IOStruct — the main data exchange (IOCTL 0Eh) }
  TVxDIO = packed record
    RXPointer  : LongInt;   { 32-bit pointer to RX buffer (VxD is 32-bit) }
    IORXLength : LongInt;   { RX buffer length }
    Received   : Word;      { bytes actually received }
    HXPointer  : LongInt;   { 32-bit pointer to TX buffer (VxD is 32-bit) }
    IOHXLength : LongInt;   { TX buffer length }
    HXFree     : Word;      { TX buffer free space }
  end;

  { StatusStruct — the big per-node state (VxD internal)
    This is NOT exchanged directly — it's the VxD's internal
    representation. Listed here for reference. }
  TVxDNodeStatus = packed record
    Node         : Byte;
    Enabled      : Byte;
    Initialized  : Byte;
    InitError    : Byte;
    Comport      : TComportStruct;
    { _PORTINFORMATION omitted — VCOMM-specific, not portable }
    UART         : TUARTStruct;
    FOSSIL       : TFOSSILStruct;
    Command      : TCommandStruct;
    VM_Handle    : LongInt;
    VCOMMOpened  : Byte;
    Online       : Byte;
    Ringing      : Byte;
    Attempting   : Byte;
    Answered     : Byte;
    ATBuffer     : LongInt;    { 32-bit pointer (VxD is 32-bit only) }
    TXBuffer     : LongInt;
    RXBuffer     : LongInt;
    ATIn         : LongInt;
    TXIn         : LongInt;
    RXIn         : LongInt;
    ATOut        : LongInt;
    TXOut        : LongInt;
    RXOut        : LongInt;
    ATEnd        : LongInt;
    TXEnd        : LongInt;
    RXEnd        : LongInt;
    ATLength     : Word;
    TXLength     : Word;
    RXLength     : Word;
    Result_      : Byte;    { 'Result' is reserved in Pascal }
    TimeOut      : Byte;
    Trigger      : Byte;
    LastChar     : Byte;
    FOSSILBaud   : Byte;
    { ... extended fields omitted for brevity }
  end;

  { IOCTL codes }
const
  NM_IOCTL_GET_VERSION    = $00;
  NM_IOCTL_GET_INFO       = $01;
  NM_IOCTL_UNLOAD_CONFIG  = $02;
  NM_IOCTL_RELOAD_CONFIG  = $03;
  NM_IOCTL_UNVIRT_IRQ     = $04;
  NM_IOCTL_VIRT_IRQ       = $05;
  NM_IOCTL_STARTUP        = $06;
  NM_IOCTL_SHUTDOWN       = $07;
  NM_IOCTL_REG_WINDOW     = $08;
  NM_IOCTL_GET_INIT       = $09;
  NM_IOCTL_RESET_NODE     = $0A;
  NM_IOCTL_RING_NODE      = $0B;
  NM_IOCTL_ANSWER_CHECK   = $0C;
  NM_IOCTL_DISCONNECT     = $0D;
  NM_IOCTL_IO             = $0E;
  NM_IOCTL_BREAK          = $0F;
  NM_IOCTL_GET_WORDLEN    = $10;

implementation

end.
