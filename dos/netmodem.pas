{ netmodem - DOS serial-to-TCP bridge (FOSSIL + fpcirc TCP/IP)
  A dumb relay: bytes from FOSSIL serial go to TCP socket,
  bytes from TCP socket go to FOSSIL serial. No protocol awareness.
  Usage: netfossl <host> <port> [comport]
  Requires: FOSSIL driver loaded, fpcirc TCP/IP stack configured }

Program netmodem;

{$IFDEF FPC}{$MODE FPC}{$ENDIF}

Uses
  DOS, fossil_dos;

Const
  BUF_SIZE    = 512;
  BAUD_9600   = $E3;
  SOCK_SIZE   = 8192;  { opaque buffer for tcp_Socket }

Type
  TSockBuf = Array[0..SOCK_SIZE-1] of Byte;
  PSockBuf = ^TSockBuf;

{ fpcirc TCP/IP — 16-bit large model, linked via fpc264irc }
Function  fpcirc_sock_init: SmallInt; external name 'sock_init_';
Function  fpcirc_tcp_open(s: PSockBuf; lport: Word; ip: LongWord;
            rport: Word; handler: Pointer): SmallInt; external name '_w32_tcp_open_';
Function  fpcirc_tcp_tick(s: PSockBuf): Word; external name '_w32_tcp_tick_';
Function  fpcirc_sock_read(s: PSockBuf; buf: Pointer; maxlen: Word): SmallInt; external name '_w32_sock_read_';
Function  fpcirc_sock_write(s: PSockBuf; data: Pointer; len: SmallInt): SmallInt; external name '_w32_sock_write_';
Function  fpcirc_sock_close(s: PSockBuf): SmallInt; external name '_w32_sock_close_';
Function  fpcirc_sock_established(s: PSockBuf): SmallInt; external name '_w32_sock_established_';
Function  fpcirc_sock_dataready(s: PSockBuf): Word; external name '_w32_sock_dataready_';
Function  fpcirc_resolve(name: PChar): LongWord; external name '_w32_resolve_';
Procedure fpcirc_sock_exit; external name '_w32_sock_exit_';

Var
  Host     : String;
  HostZ    : Array[0..255] of Char;
  PortNum  : Word;
  ComPort  : Word;
  Sock     : TSockBuf;
  RxBuf    : Array[1..BUF_SIZE] of Byte;
  TxBuf    : Array[1..BUF_SIZE] of Byte;
  RxLen    : SmallInt;
  TxLen    : Word;
  Done     : Boolean;
  B        : Byte;
  I        : Word;
  IP       : LongWord;

Begin
  WriteLn('netmodem - DOS serial-to-TCP bridge');
  WriteLn('-----------------------------------');

  If ParamCount < 2 Then Begin
    WriteLn('Usage: netfossl <host> <port> [comport]');
    Halt(1);
  End;

  Host := ParamStr(1);
  Val(ParamStr(2), PortNum, I);
  If PortNum = 0 Then Begin WriteLn('Invalid port'); Halt(1); End;

  ComPort := 0;
  If ParamCount >= 3 Then Val(ParamStr(3), ComPort, I);

  { FOSSIL init }
  Write('FOSSIL COM', ComPort + 1, '... ');
  If Not Fossil_Init(ComPort) Then Begin
    WriteLn('FAILED'); Halt(2);
  End;
  WriteLn('OK');
  Fossil_SetBaud(ComPort, BAUD_9600);
  Fossil_PurgeIn(ComPort);
  Fossil_PurgeOut(ComPort);

  { TCP/IP init }
  Write('TCP/IP... ');
  If fpcirc_sock_init <> 0 Then Begin
    WriteLn('FAILED'); Fossil_Deinit(ComPort); Halt(3);
  End;
  WriteLn('OK');

  { Resolve host }
  For I := 1 to Length(Host) Do HostZ[I-1] := Host[I];
  HostZ[Length(Host)] := #0;

  Write('Resolving ', Host, '... ');
  IP := fpcirc_resolve(@HostZ[0]);
  If IP = 0 Then Begin
    WriteLn('FAILED');
    fpcirc_sock_exit; Fossil_Deinit(ComPort); Halt(4);
  End;
  WriteLn('OK');

  { Connect }
  Write('Connecting ', Host, ':', PortNum, '... ');
  FillChar(Sock, SizeOf(Sock), 0);
  If fpcirc_tcp_open(@Sock, 0, IP, PortNum, Nil) = 0 Then Begin
    WriteLn('FAILED');
    fpcirc_sock_exit; Fossil_Deinit(ComPort); Halt(4);
  End;

  { Wait for connection }
  While fpcirc_sock_established(@Sock) = 0 Do Begin
    If fpcirc_tcp_tick(@Sock) = 0 Then Begin
      WriteLn('FAILED (timeout)');
      fpcirc_sock_exit; Fossil_Deinit(ComPort); Halt(4);
    End;
  End;
  WriteLn('OK');

  WriteLn('Bridge active. Carrier loss disconnects.');
  Done := False;

  Repeat
    { Process incoming packets }
    If fpcirc_tcp_tick(@Sock) = 0 Then Begin
      WriteLn; WriteLn('Remote closed.'); Done := True;
    End;

    { TCP -> FOSSIL }
    If fpcirc_sock_dataready(@Sock) > 0 Then Begin
      RxLen := fpcirc_sock_read(@Sock, @RxBuf[1], BUF_SIZE);
      If RxLen > 0 Then
        For I := 1 to RxLen Do Fossil_SendByte(ComPort, RxBuf[I]);
    End;

    { FOSSIL -> TCP }
    TxLen := 0;
    While Fossil_RxReady(ComPort) and (TxLen < BUF_SIZE) Do Begin
      If Fossil_RecvByte(ComPort, B) Then Begin
        Inc(TxLen); TxBuf[TxLen] := B;
      End;
    End;
    If TxLen > 0 Then Begin
      RxLen := fpcirc_sock_write(@Sock, @TxBuf[1], TxLen);
      If RxLen < 0 Then Begin
        WriteLn; WriteLn('Send error.'); Done := True;
      End;
    End;

    { Carrier check }
    If Not Fossil_Carrier(ComPort) Then Begin
      WriteLn; WriteLn('Carrier lost.'); Done := True;
    End;
  Until Done;

  WriteLn('Disconnecting...');
  fpcirc_sock_close(@Sock);
  fpcirc_sock_exit;
  Fossil_SetDTR(ComPort, False);
  Fossil_Deinit(ComPort);
  WriteLn('Done.');
End.
