{ ===========================================================================
  netmodem2irc — NM_DebugView
  GPLv3 — Copyright (C) 2026 verta1878, sysop/0, wrench, kiddo, evga
  ---------------------------------------------------------------------------
  Real-time data stream viewer for NMServer. Think browser dev tools
  or Wireshark, but for the virtual modem engine.

  Three panels:

  1. HEX STREAM — live hex+ASCII dump of bytes flowing both directions.
     Network→UART shows in green, UART→Network shows in yellow.
     IAC sequences highlighted in red. Zmodem headers detected.

  2. UART STATE — register dashboard. Live view of:
     - LSR (Line Status Register): TX empty, data ready, errors
     - MSR (Modem Status Register): DCD, DSR, CTS, RI
     - IER (Interrupt Enable Register): what interrupts are armed
     - MCR (Modem Control Register): DTR, RTS, OUT1, OUT2
     - RX ring: fill level bar + count
     - TX ring: fill level bar + count
     - Baud rate, data bits, parity, stop bits

  3. EVENT LOG — tagged events with timestamps:
     - CONNECT/DISCONNECT
     - Telnet WILL/DO/WONT/DONT negotiations
     - FOSSIL function calls (Fn $00-$1B)
     - BREAK signal
     - DTR raise/lower
     - Carrier detect changes
     - Flow control changes

  The viewer attaches to a node and taps the data path without
  changing it. Zero-copy: it reads from the same ring buffers
  the engine uses, plus event callbacks from NM_Debug.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

unit NM_DebugView;

interface

uses
  SysUtils, Classes, NM_UART16550, NM_Debug;

const
  MAX_STREAM_LINES = 2000;    { hex stream history }
  MAX_EVENTS       = 5000;    { event log history }
  BYTES_PER_LINE   = 16;      { hex dump width }

type
  TStreamDirection = (sdNetToUart, sdUartToNet);

  TStreamEntry = record
    Timestamp: TDateTime;
    Direction: TStreamDirection;
    Data: array[0..15] of Byte;
    Len: Integer;
    Offset: LongInt;            { running byte offset }
  end;

  TEventKind = (
    evConnect, evDisconnect,
    evTelnetWill, evTelnetDo, evTelnetWont, evTelnetDont, evTelnetSB,
    evFossilCall,
    evDTRRaise, evDTRLower,
    evCarrierOn, evCarrierOff,
    evRingOn, evRingOff,
    evBreakStart, evBreakStop,
    evFlowControl,
    evZmodemDetected,
    evError,
    { Session lifecycle (new) }
    evTelnetBinaryOn,     { Telnet BINARY mode negotiated }
    evTelnetSGAOn,        { Telnet SGA (suppress go-ahead) negotiated }
    evFossilInit,         { FOSSIL Fn $04 called — BBS starting up }
    evFossilDeinit,       { FOSSIL Fn $05 called — BBS shutting down }
    evFossilSetBaud,      { FOSSIL Fn $00 — baud rate set }
    evFossilStatus,       { FOSSIL Fn $03 — status check (frequent, can filter) }
    evFossilReadChar,     { FOSSIL Fn $02 — BBS reading a character }
    evFossilWriteChar,    { FOSSIL Fn $01 — BBS sending a character }
    evFossilBlockRead,    { FOSSIL Fn $18 — BBS reading a block (file transfer) }
    evFossilBlockWrite,   { FOSSIL Fn $19 — BBS writing a block (file transfer) }
    evFossilPurgeRX,      { FOSSIL Fn $0A — BBS cleared input buffer }
    evFossilPurgeTX,      { FOSSIL Fn $09 — BBS cleared output buffer }
    evFossilFlush,        { FOSSIL Fn $08 — BBS waiting for TX to drain }
    evFossilGetInfo,      { FOSSIL Fn $1B — BBS queried driver info }
    evLoginPromptSent,    { BBS sent "name" or "login" text }
    evPasswordPromptSent, { BBS sent "password" text }
    evUserTyping,         { Printable text from caller }
    evMenuSent,           { BBS sent menu/ANSI screen }
    evGoodbyeSent,        { BBS sent "goodbye" or "logoff" text }
    evSessionSummary      { Session ended — summary stats }
  );

  TSessionStats = record
    ConnectTime: TDateTime;
    DisconnectTime: TDateTime;
    Duration: TDateTime;
    BytesReceived: LongInt;    { network -> UART }
    BytesSent: LongInt;        { UART -> network }
    FossilCalls: LongInt;      { total FOSSIL function calls }
    CharsSent: LongInt;        { printable chars BBS -> caller }
    CharsReceived: LongInt;    { printable chars caller -> BBS }
    ZmodemTransfers: Integer;  { number of Zmodem sessions detected }
    LoginDetected: Boolean;
    UserName: String;
    RemoteIP: String;
    RemotePort: Word;
    { Throughput tracking }
    PeakBytesPerSec: LongInt;  { highest throughput seen }
    CurrentBPS: LongInt;       { rolling 1-second average }
    LastSecondBytes: LongInt;  { bytes in current 1-sec window }
    LastSecondTime: TDateTime; { start of current window }
    { AT command tracking }
    ATCommandsSeen: Integer;   { total AT commands from guest }
    LastATCommand: String;     { most recent AT command }
    { File transfer progress }
    TransferActive: Boolean;
    TransferFileName: String;
    TransferBytesTotal: LongInt;
    TransferBytesDone: LongInt;
    TransferStartTime: TDateTime;
    { ANSI tracking }
    ANSISequencesSent: LongInt;   { total ANSI escape sequences }
    ClearScreenCount: Integer;    { number of screen clears }
    ColorChanges: LongInt;        { SGR color changes }
  end;

  { ANSI sequence types we detect }
  TANSIEventKind = (
    aeColorChange,    { ESC[...m — SGR color }
    aeCursorMove,     { ESC[...H/A/B/C/D — cursor position/move }
    aeClearScreen,    { ESC[2J — clear screen }
    aeClearLine,      { ESC[K — clear to end of line }
    aeScrollRegion,   { ESC[...r — set scroll region }
    aeSaveCursor,     { ESC[s — save cursor position }
    aeRestoreCursor,  { ESC[u — restore cursor position }
    aeUnknown
  );

  TDebugEvent = record
    Timestamp: TDateTime;
    Kind: TEventKind;
    NodeIndex: Integer;
    Detail: String;
  end;

  TUartSnapshot = record
    LSR: Byte;      { Line Status Register }
    MSR: Byte;      { Modem Status Register }
    IER: Byte;      { Interrupt Enable Register }
    MCR: Byte;      { Modem Control Register }
    LCR: Byte;      { Line Control Register }
    DLL: Byte;      { Divisor Latch Low }
    DLM: Byte;      { Divisor Latch High }
    RXCount: Word;  { bytes in RX ring }
    RXSize: Word;   { RX ring capacity }
    TXCount: Word;  { bytes in TX ring }
    TXSize: Word;   { TX ring capacity }
    BaudRate: LongInt;
    DataBits: Byte;
    StopBits: Byte;
    Parity: Char;   { N, E, O, M, S }
    DCD: Boolean;
    DSR: Boolean;
    CTS: Boolean;
    RI: Boolean;
    DTR: Boolean;
    RTS: Boolean;
  end;

  { TDebugViewer — attaches to a node and captures everything }
  TDebugViewer = class
  private
    FNodeIndex: Integer;
    FAttached: Boolean;
    FPaused: Boolean;

    { Hex stream }
    FStream: array of TStreamEntry;
    FStreamCount: Integer;
    FNetToUartOffset: LongInt;
    FUartToNetOffset: LongInt;

    { Event log }
    FEvents: array of TDebugEvent;
    FEventCount: Integer;

    { UART snapshot }
    FSnapshot: TUartSnapshot;

    { Filters }
    FShowNetToUart: Boolean;
    FShowUartToNet: Boolean;
    FShowTelnet: Boolean;
    FShowFossil: Boolean;
    FShowStatusPolls: Boolean;   { show Fn $03 status checks (noisy) }
    FHighlightIAC: Boolean;
    FHighlightZmodem: Boolean;

    { Session lifecycle tracking }
    FSession: TSessionStats;
    FCallerTextBuf: String;     { accumulates printable chars from caller }
    FBBSTextBuf: String;        { accumulates printable chars from BBS }
    FLastCallerLine: String;    { last complete line the caller typed }
    FAwaitingPassword: Boolean; { true after login prompt detected }

    { LED activity tracking (USR Courier style) }
    FLedRDActive: Boolean;     { receive data flickering }
    FLedSDActive: Boolean;     { send data flickering }
    FLedRDTime: TDateTime;     { last RD activity }
    FLedSDTime: TDateTime;     { last SD activity }

    { ANSI parser state }
    FANSIState: Integer;       { 0=normal, 1=saw ESC, 2=in CSI sequence }
    FANSIBuf: String;          { accumulates CSI parameter bytes }

    { AT command parser state }
    FATBuf: String;            { accumulates AT command characters }
    FATState: Integer;         { 0=idle, 1=saw A, 2=in command }

    procedure AddStreamEntry(Dir: TStreamDirection;
      const Data: array of Byte; Len: Integer);
    procedure DetectZmodem(const Data: array of Byte; Len: Integer);
    procedure ScanCallerText(const Data: array of Byte; Len: Integer);
    procedure ScanBBSText(const Data: array of Byte; Len: Integer);
    procedure ScanATCommands(const Data: array of Byte; Len: Integer);
    procedure ScanANSI(const Data: array of Byte; Len: Integer);
    procedure UpdateThroughput(ByteCount: Integer);
    procedure DetectTransferProgress(const Data: array of Byte; Len: Integer);
  public
    constructor Create(ANodeIndex: Integer);
    destructor Destroy; override;

    { Attach/detach from a node }
    procedure Attach;
    procedure Detach;

    { Data tap — called by the engine's pump loop }
    procedure OnNetToUart(const Data: array of Byte; Len: Integer);
    procedure OnUartToNet(const Data: array of Byte; Len: Integer);

    { Event tap — called by various engine components }
    procedure OnEvent(Kind: TEventKind; const Detail: String);

    { FOSSIL function decoder — call with function number + registers }
    procedure OnFossilCall(Fn: Byte; AL, AH: Byte; CX: Word);

    { Telnet negotiation decoder }
    procedure OnTelnetNeg(Cmd, Option: Byte);

    { Session lifecycle }
    procedure BeginSession(const RemoteIP: String; RemotePort: Word);
    procedure EndSession;
    function FormatSessionSummary: String;

    { Take a snapshot of the UART state }
    procedure SnapshotUart(var Uart: TUart16550);

    { Pause/resume capture (data still flows, just not recorded) }
    procedure Pause;
    procedure Resume;
    procedure Clear;

    { Export entire session trace to a text file }
    procedure ExportToFile(const FileName: String);

    { Format throughput stats:
      "THROUGHPUT: 2,847 bytes/sec (peak: 14,200 bytes/sec)" }
    function FormatThroughput: String;

    { Format file transfer progress:
      "TRANSFER: GAME.ZIP  ████████░░ 82% (201 KB / 245 KB)  4.2 KB/sec" }
    function FormatTransferProgress: String;

    { Format AT command status:
      "AT COMMANDS: 3 seen, last: ATDT192.168.1.5:23" }
    function FormatATStatus: String;

    { Format ANSI stats:
      "ANSI: 847 sequences, 12 screen clears, 423 color changes" }
    function FormatANSIStats: String;

    { === USR Courier-style LED modem panel === }

    { Format the modem front panel like a real USR Courier:
        ●AA  ●CD  ○OH  ◐RD  ◑SD  ●TR  ●MR  ●CS  ○HS  ○ARQ
      Filled = on, empty = off, half = activity (blinking) }
    function FormatModemLEDs: String;

    { Individual LED descriptions for the panel }
    function FormatLEDDetail: String;

    { === Human-readable formatting === }

    { Format a stream entry for humans:
      "12:34:56 CALLER → BBS  "Hello sysop!"" }
    function FormatStreamHuman(Index: Integer): String;

    { Format an event for humans with icons:
      "12:34:56 ☎ Caller connected from 192.168.1.5" }
    function FormatEventHuman(Index: Integer): String;

    { Format modem status as plain English with indicator lights:
      "CARRIER: ON  RING: OFF  READY: ON  DTR: ON" }
    function FormatModemHuman: String;

    { Format buffer status with visual bar:
      "RX ████░░░░ 142/4096  TX ░░░░░░░░ 0/4096" }
    function FormatBufferHuman: String;

    { === Technical formatting === }

    { Format a hex stream entry as a string:
      "12:34:56.789 >>> 41 42 43 44 45 46 47 48  ABCDEFGH" }
    function FormatStreamLine(Index: Integer): String;

    { Format an event as a string:
      "12:34:56.789 [CONNECT] Node 0 from 192.168.1.5:4321" }
    function FormatEvent(Index: Integer): String;

    { Format the UART snapshot as multi-line string }
    function FormatSnapshot: String;

    { Format register as bit string: "LSR: 01100001 [DR THRE TEMT]" }
    function FormatLSR: String;
    function FormatMSR: String;
    function FormatMCR: String;
    function FormatRingStatus: String;

    property NodeIndex: Integer read FNodeIndex;
    property Attached: Boolean read FAttached;
    property Paused: Boolean read FPaused;
    property StreamCount: Integer read FStreamCount;
    property EventCount: Integer read FEventCount;
    property Snapshot: TUartSnapshot read FSnapshot;
    property ShowNetToUart: Boolean read FShowNetToUart write FShowNetToUart;
    property ShowUartToNet: Boolean read FShowUartToNet write FShowUartToNet;
  end;

implementation

const
  DIR_ARROW: array[TStreamDirection] of String = ('>>>', '<<<');
  BAUD_TABLE: array[0..7] of LongInt = (
    19200, 38400, 300, 600, 1200, 2400, 4800, 9600);
  PARITY_CHAR: array[0..4] of Char = ('N', 'O', 'N', 'E', 'N');

  EVENT_TAG: array[TEventKind] of String = (
    'CONNECT', 'DISCONNECT',
    'TELNET WILL', 'TELNET DO', 'TELNET WONT', 'TELNET DONT', 'TELNET SB',
    'FOSSIL',
    'DTR UP', 'DTR DOWN',
    'CARRIER ON', 'CARRIER OFF',
    'RING ON', 'RING OFF',
    'BREAK START', 'BREAK STOP',
    'FLOW',
    'ZMODEM',
    'ERROR',
    'BINARY ON', 'SGA ON',
    'FOSSIL INIT', 'FOSSIL DEINIT', 'SET BAUD',
    'STATUS', 'READ', 'WRITE',
    'BLOCK READ', 'BLOCK WRITE',
    'PURGE RX', 'PURGE TX', 'FLUSH', 'GET INFO',
    'LOGIN PROMPT', 'PASSWORD PROMPT',
    'USER TYPING', 'MENU', 'GOODBYE', 'SUMMARY'
  );

constructor TDebugViewer.Create(ANodeIndex: Integer);
begin
  inherited Create;
  FNodeIndex := ANodeIndex;
  FAttached := False;
  FPaused := False;
  FStreamCount := 0;
  FEventCount := 0;
  FNetToUartOffset := 0;
  FUartToNetOffset := 0;
  FShowNetToUart := True;
  FShowUartToNet := True;
  FShowTelnet := True;
  FShowFossil := True;
  FHighlightIAC := True;
  FHighlightZmodem := True;
  SetLength(FStream, MAX_STREAM_LINES);
  SetLength(FEvents, MAX_EVENTS);
  FillChar(FSnapshot, SizeOf(FSnapshot), 0);
end;

destructor TDebugViewer.Destroy;
begin
  SetLength(FStream, 0);
  SetLength(FEvents, 0);
  inherited;
end;

procedure TDebugViewer.Attach;
begin
  FAttached := True;
  FCallerTextBuf := '';
  FBBSTextBuf := '';
  FLastCallerLine := '';
  FAwaitingPassword := False;
  FShowStatusPolls := False;   { hide noisy Fn $03 by default }
  FillChar(FSession, SizeOf(FSession), 0);
  DebugLog('DebugView', 'Attached to node ' + IntToStr(FNodeIndex));
end;

procedure TDebugViewer.Detach;
begin
  FAttached := False;
  DebugLog('DebugView', 'Detached from node ' + IntToStr(FNodeIndex));
end;

procedure TDebugViewer.AddStreamEntry(Dir: TStreamDirection;
  const Data: array of Byte; Len: Integer);
var
  Pos, ChunkLen, I: Integer;
begin
  if FPaused then Exit;
  if (Dir = sdNetToUart) and not FShowNetToUart then Exit;
  if (Dir = sdUartToNet) and not FShowUartToNet then Exit;

  { Split into 16-byte lines }
  Pos := 0;
  while Pos < Len do
  begin
    ChunkLen := Len - Pos;
    if ChunkLen > BYTES_PER_LINE then ChunkLen := BYTES_PER_LINE;

    if FStreamCount >= MAX_STREAM_LINES then
    begin
      { Shift array — drop oldest }
      Move(FStream[1], FStream[0],
           (MAX_STREAM_LINES - 1) * SizeOf(TStreamEntry));
      Dec(FStreamCount);
    end;

    with FStream[FStreamCount] do
    begin
      Timestamp := Now;
      Direction := Dir;
      FillChar(Data, SizeOf(Data), 0);
      for I := 0 to ChunkLen - 1 do
        FStream[FStreamCount].Data[I] := Data[Pos + I];
      FStream[FStreamCount].Len := ChunkLen;
      if Dir = sdNetToUart then
      begin
        FStream[FStreamCount].Offset := FNetToUartOffset;
        Inc(FNetToUartOffset, ChunkLen);
      end
      else
      begin
        FStream[FStreamCount].Offset := FUartToNetOffset;
        Inc(FUartToNetOffset, ChunkLen);
      end;
    end;
    Inc(FStreamCount);
    Inc(Pos, ChunkLen);
  end;
end;

procedure TDebugViewer.DetectZmodem(const Data: array of Byte; Len: Integer);
var I: Integer;
begin
  { Look for ZPAD ZPAD ZDLE pattern }
  for I := 0 to Len - 3 do
    if (Data[I] = $2A) and (Data[I+1] = $2A) and (Data[I+2] = $18) then
    begin
      OnEvent(evZmodemDetected, 'ZPAD ZPAD ZDLE at offset ' +
              IntToStr(FNetToUartOffset + I));
      Exit;
    end;
end;

procedure TDebugViewer.OnNetToUart(const Data: array of Byte; Len: Integer);
begin
  if not FAttached then Exit;
  AddStreamEntry(sdNetToUart, Data, Len);
  Inc(FSession.BytesReceived, Len);
  FLedRDActive := True; FLedRDTime := Now;   { RD LED flicker }
  if FHighlightZmodem then DetectZmodem(Data, Len);
  ScanCallerText(Data, Len);
  ScanATCommands(Data, Len);
  DetectTransferProgress(Data, Len);
  UpdateThroughput(Len);
end;

procedure TDebugViewer.OnUartToNet(const Data: array of Byte; Len: Integer);
begin
  if not FAttached then Exit;
  AddStreamEntry(sdUartToNet, Data, Len);
  Inc(FSession.BytesSent, Len);
  FLedSDActive := True; FLedSDTime := Now;   { SD LED flicker }
  ScanBBSText(Data, Len);
  ScanANSI(Data, Len);
  UpdateThroughput(Len);
end;

procedure TDebugViewer.ScanCallerText(const Data: array of Byte; Len: Integer);
{ Watch what the caller types. Detect username entry after login prompt. }
var I: Integer;
begin
  for I := 0 to Len - 1 do
  begin
    if (Data[I] >= 32) and (Data[I] < 127) then
    begin
      FCallerTextBuf := FCallerTextBuf + Chr(Data[I]);
      Inc(FSession.CharsReceived);
    end
    else if (Data[I] = 13) or (Data[I] = 10) then
    begin
      if Length(FCallerTextBuf) > 0 then
      begin
        FLastCallerLine := FCallerTextBuf;
        OnEvent(evUserTyping, 'User typed: "' + FCallerTextBuf + '"');

        { If we were awaiting a password, this was the username }
        if FAwaitingPassword then
        begin
          FSession.UserName := FLastCallerLine;
          FSession.LoginDetected := True;
          FAwaitingPassword := False;
          OnEvent(evLoginPromptSent, 'Username entered: "' + FSession.UserName + '"');
        end;
      end;
      FCallerTextBuf := '';
    end;
  end;
end;

procedure TDebugViewer.ScanBBSText(const Data: array of Byte; Len: Integer);
{ Watch what the BBS sends. Detect login prompts, goodbye messages, menus. }
var
  I: Integer;
  LowerBuf: String;
begin
  for I := 0 to Len - 1 do
  begin
    if (Data[I] >= 32) and (Data[I] < 127) then
    begin
      FBBSTextBuf := FBBSTextBuf + Chr(Data[I]);
      Inc(FSession.CharsSent);
    end
    else if (Data[I] = 13) or (Data[I] = 10) then
    begin
      if Length(FBBSTextBuf) > 2 then
      begin
        LowerBuf := LowerCase(FBBSTextBuf);

        { Detect login prompt }
        if (Pos('name', LowerBuf) > 0) or
           (Pos('login', LowerBuf) > 0) or
           (Pos('enter your', LowerBuf) > 0) then
        begin
          if not FSession.LoginDetected then
          begin
            OnEvent(evLoginPromptSent, 'BBS asking for login: "' + FBBSTextBuf + '"');
            FAwaitingPassword := True;
          end;
        end;

        { Detect password prompt }
        if Pos('password', LowerBuf) > 0 then
          OnEvent(evPasswordPromptSent, 'BBS asking for password');

        { Detect goodbye }
        if (Pos('goodbye', LowerBuf) > 0) or
           (Pos('logoff', LowerBuf) > 0) or
           (Pos('logging off', LowerBuf) > 0) or
           (Pos('thanks for calling', LowerBuf) > 0) or
           (Pos('call again', LowerBuf) > 0) then
          OnEvent(evGoodbyeSent, 'BBS saying goodbye: "' + FBBSTextBuf + '"');

        { Detect menu (common BBS patterns) }
        if (Pos('main menu', LowerBuf) > 0) or
           (Pos('command', LowerBuf) > 0) or
           (Pos('select:', LowerBuf) > 0) or
           (Pos('choice:', LowerBuf) > 0) then
          OnEvent(evMenuSent, 'BBS sent menu: "' + FBBSTextBuf + '"');
      end;
      FBBSTextBuf := '';
    end;
  end;
end;

procedure TDebugViewer.OnFossilCall(Fn: Byte; AL, AH: Byte; CX: Word);
{ Decode every FOSSIL function call into a human-readable event. }
begin
  if not FAttached then Exit;
  Inc(FSession.FossilCalls);

  case Fn of
    $00: OnEvent(evFossilSetBaud, 'Set speed: AL=$' + IntToHex(AL, 2));
    $01: OnEvent(evFossilWriteChar, 'Send byte: $' + IntToHex(AL, 2) +
           ' (' + Chr(AL) + ')');
    $02: OnEvent(evFossilReadChar, 'Read byte');
    $03: if FShowStatusPolls then
           OnEvent(evFossilStatus, 'Status check');
    $04: OnEvent(evFossilInit, 'FOSSIL initialized — BBS starting up');
    $05: OnEvent(evFossilDeinit, 'FOSSIL shutdown — BBS closing connection');
    $06: if AL = 1 then
           OnEvent(evDTRRaise, 'BBS raised DTR — ready for calls')
         else
           OnEvent(evDTRLower, 'BBS dropped DTR — hanging up');
    $08: OnEvent(evFossilFlush, 'BBS waiting for transmit buffer to drain');
    $09: OnEvent(evFossilPurgeTX, 'BBS cleared outgoing data');
    $0A: OnEvent(evFossilPurgeRX, 'BBS cleared incoming data');
    $0B: OnEvent(evFossilWriteChar, 'Send byte (non-blocking): $' +
           IntToHex(AL, 2));
    $0C: OnEvent(evFossilCall, 'Peek at next byte');
    $0F: OnEvent(evFlowControl, 'Flow control set: AL=$' + IntToHex(AL, 2));
    $18: OnEvent(evFossilBlockRead, 'Block read: ' + IntToStr(CX) + ' bytes');
    $19: OnEvent(evFossilBlockWrite, 'Block write: ' + IntToStr(CX) + ' bytes');
    $1A: if AL = 1 then
           OnEvent(evBreakStart, 'Break signal started')
         else
           OnEvent(evBreakStop, 'Break signal stopped');
    $1B: OnEvent(evFossilGetInfo, 'BBS queried driver info');
  else
    OnEvent(evFossilCall, 'FOSSIL Fn $' + IntToHex(Fn, 2));
  end;
end;

procedure TDebugViewer.OnTelnetNeg(Cmd, Option: Byte);
{ Decode Telnet negotiation into human-readable events. }
const
  OPT_NAMES: array[0..39] of String = (
    'BINARY', 'ECHO', 'RECONNECT', 'SGA', 'APPROX-MSG-SIZE',
    'STATUS', 'TIMING-MARK', 'REMOTE-CTRL', 'OUTPUT-LINE-WIDTH',
    'OUTPUT-PAGE-SIZE', 'OUTPUT-CR', 'OUTPUT-HTABS', 'OUTPUT-HTAB-STOPS',
    'OUTPUT-FF', 'OUTPUT-VTABS', 'OUTPUT-VTAB-STOPS', 'OUTPUT-LF',
    'EXTENDED-ASCII', 'LOGOUT', 'BYTE-MACRO', 'DATA-ENTRY-TERM',
    'SUPDUP', 'SUPDUP-OUTPUT', 'SEND-LOCATION', 'TERMINAL-TYPE',
    'END-OF-RECORD', 'TUID', 'OUTMRK', 'TTYLOC', 'OPT-3270',
    'X.3-PAD', 'WINDOW-SIZE', 'TERMINAL-SPEED', 'REMOTE-FLOW',
    'LINEMODE', 'X-DISPLAY-LOC', 'OLD-ENVIRON', 'AUTHENTICATION',
    'ENCRYPT', 'NEW-ENVIRON'
  );
var
  OptName, CmdName: String;
begin
  if not FAttached then Exit;

  if Option <= 39 then OptName := OPT_NAMES[Option]
  else OptName := 'OPT-' + IntToStr(Option);

  case Cmd of
    $FB: begin CmdName := 'WILL'; OnEvent(evTelnetWill, CmdName + ' ' + OptName); end;
    $FC: begin CmdName := 'WONT'; OnEvent(evTelnetWont, CmdName + ' ' + OptName); end;
    $FD: begin CmdName := 'DO';   OnEvent(evTelnetDo,   CmdName + ' ' + OptName); end;
    $FE: begin CmdName := 'DONT'; OnEvent(evTelnetDont, CmdName + ' ' + OptName); end;
  end;

  { Track binary and SGA negotiation }
  if (Option = 0) and (Cmd in [$FB, $FD]) then
    OnEvent(evTelnetBinaryOn, 'Binary mode active — 8-bit clean data path');
  if (Option = 3) and (Cmd in [$FB, $FD]) then
    OnEvent(evTelnetSGAOn, 'Suppress Go-Ahead active — character-at-a-time mode');
end;

procedure TDebugViewer.BeginSession(const RemoteIP: String; RemotePort: Word);
begin
  FillChar(FSession, SizeOf(FSession), 0);
  FSession.ConnectTime := Now;
  FSession.RemoteIP := RemoteIP;
  FSession.RemotePort := RemotePort;
  FCallerTextBuf := '';
  FBBSTextBuf := '';
  FLastCallerLine := '';
  FAwaitingPassword := False;
  OnEvent(evConnect, 'from ' + RemoteIP + ':' + IntToStr(RemotePort));
end;

procedure TDebugViewer.EndSession;
begin
  FSession.DisconnectTime := Now;
  FSession.Duration := FSession.DisconnectTime - FSession.ConnectTime;
  OnEvent(evDisconnect, FormatSessionSummary);
  OnEvent(evSessionSummary, FormatSessionSummary);
end;

function TDebugViewer.FormatSessionSummary: String;
var
  Mins, Secs: Integer;
  TotalKB: Double;
begin
  Secs := Round(FSession.Duration * 86400);
  Mins := Secs div 60;
  Secs := Secs mod 60;
  TotalKB := (FSession.BytesReceived + FSession.BytesSent) / 1024;

  Result := '--- SESSION SUMMARY ---' + #13#10;
  if FSession.RemoteIP <> '' then
    Result := Result + 'Caller: ' + FSession.RemoteIP + ':' +
              IntToStr(FSession.RemotePort) + #13#10;
  if FSession.LoginDetected then
    Result := Result + 'Username: ' + FSession.UserName + #13#10;
  Result := Result + 'Duration: ' + IntToStr(Mins) + ' min ' +
            IntToStr(Secs) + ' sec' + #13#10;
  Result := Result + 'Data received: ' + IntToStr(FSession.BytesReceived) +
            ' bytes (' + IntToStr(FSession.CharsReceived) + ' chars typed)' + #13#10;
  Result := Result + 'Data sent: ' + IntToStr(FSession.BytesSent) +
            ' bytes (' + IntToStr(FSession.CharsSent) + ' chars displayed)' + #13#10;
  Result := Result + 'Total transferred: ' + FormatFloat('0.1', TotalKB) + ' KB' + #13#10;
  Result := Result + 'FOSSIL calls: ' + IntToStr(FSession.FossilCalls) + #13#10;
  if FSession.ZmodemTransfers > 0 then
    Result := Result + 'Zmodem transfers: ' + IntToStr(FSession.ZmodemTransfers) + #13#10;
  Result := Result + '-----------------------';
end;

procedure TDebugViewer.OnEvent(Kind: TEventKind; const Detail: String);
begin
  if not FAttached then Exit;
  if FPaused then Exit;

  if FEventCount >= MAX_EVENTS then
  begin
    Move(FEvents[1], FEvents[0],
         (MAX_EVENTS - 1) * SizeOf(TDebugEvent));
    Dec(FEventCount);
  end;

  FEvents[FEventCount].Timestamp := Now;
  FEvents[FEventCount].Kind := Kind;
  FEvents[FEventCount].NodeIndex := FNodeIndex;
  FEvents[FEventCount].Detail := Detail;
  Inc(FEventCount);

  DebugLog('DebugView', '[' + EVENT_TAG[Kind] + '] ' + Detail);
end;

procedure TDebugViewer.SnapshotUart(var Uart: TUart16550);
begin
  FSnapshot.LSR := UartReadReg(Uart, 5);
  FSnapshot.MSR := UartReadReg(Uart, 6);
  FSnapshot.IER := UartReadReg(Uart, 1);
  FSnapshot.MCR := UartReadReg(Uart, 4);
  FSnapshot.LCR := UartReadReg(Uart, 3);

  { Decode LCR }
  FSnapshot.DataBits := (FSnapshot.LCR and $03) + 5;
  FSnapshot.StopBits := 1 + ((FSnapshot.LCR shr 2) and 1);
  FSnapshot.Parity := PARITY_CHAR[(FSnapshot.LCR shr 3) and $07];

  { Decode MSR }
  FSnapshot.DCD := (FSnapshot.MSR and $80) <> 0;
  FSnapshot.DSR := (FSnapshot.MSR and $20) <> 0;
  FSnapshot.CTS := (FSnapshot.MSR and $10) <> 0;
  FSnapshot.RI  := (FSnapshot.MSR and $40) <> 0;

  { Decode MCR }
  FSnapshot.DTR := (FSnapshot.MCR and $01) <> 0;
  FSnapshot.RTS := (FSnapshot.MCR and $02) <> 0;

  { Ring buffer levels }
  FSnapshot.RXCount := Uart.RX.Count;
  FSnapshot.RXSize  := RING_SIZE;
  FSnapshot.TXCount := Uart.TX.Count;
  FSnapshot.TXSize  := RING_SIZE;

  { Baud rate from divisor }
  FSnapshot.DLL := (Uart.DLL or (Uart.DLM shl 8)) and $FF;
  FSnapshot.DLM := ((Uart.DLL or (Uart.DLM shl 8)) shr 8) and $FF;
  if (Uart.DLL or (Uart.DLM shl 8)) > 0 then
    FSnapshot.BaudRate := 115200 div (Uart.DLL or (Uart.DLM shl 8))
  else
    FSnapshot.BaudRate := 0;
end;

procedure TDebugViewer.Pause;
begin
  FPaused := True;
end;

procedure TDebugViewer.Resume;
begin
  FPaused := False;
end;

procedure TDebugViewer.Clear;
begin
  FStreamCount := 0;
  FEventCount := 0;
  FNetToUartOffset := 0;
  FUartToNetOffset := 0;
end;

function TDebugViewer.FormatStreamLine(Index: Integer): String;
var
  I: Integer;
  HexPart, AscPart: String;
begin
  Result := '';
  if (Index < 0) or (Index >= FStreamCount) then Exit;

  with FStream[Index] do
  begin
    { Timestamp + direction }
    Result := FormatDateTime('hh:nn:ss.zzz', Timestamp) + ' ' +
              DIR_ARROW[Direction] + ' ';

    { Offset }
    Result := Result + IntToHex(Offset, 6) + '  ';

    { Hex bytes }
    HexPart := '';
    AscPart := '';
    for I := 0 to BYTES_PER_LINE - 1 do
    begin
      if I < Len then
      begin
        HexPart := HexPart + IntToHex(Data[I], 2) + ' ';
        if (Data[I] >= 32) and (Data[I] < 127) then
          AscPart := AscPart + Chr(Data[I])
        else
          AscPart := AscPart + '.';
      end
      else
      begin
        HexPart := HexPart + '   ';
        AscPart := AscPart + ' ';
      end;
      if I = 7 then HexPart := HexPart + ' ';  { mid-gap }
    end;

    Result := Result + HexPart + ' ' + AscPart;
  end;
end;

function TDebugViewer.FormatEvent(Index: Integer): String;
begin
  Result := '';
  if (Index < 0) or (Index >= FEventCount) then Exit;
  with FEvents[Index] do
    Result := FormatDateTime('hh:nn:ss.zzz', Timestamp) +
              ' [' + EVENT_TAG[Kind] + '] ' + Detail;
end;

function TDebugViewer.FormatLSR: String;
begin
  with FSnapshot do
  begin
    Result := 'LSR: ' + IntToHex(LSR, 2) + ' ';
    if (LSR and $01) <> 0 then Result := Result + 'DR ';
    if (LSR and $02) <> 0 then Result := Result + 'OE ';
    if (LSR and $04) <> 0 then Result := Result + 'PE ';
    if (LSR and $08) <> 0 then Result := Result + 'FE ';
    if (LSR and $10) <> 0 then Result := Result + 'BI ';
    if (LSR and $20) <> 0 then Result := Result + 'THRE ';
    if (LSR and $40) <> 0 then Result := Result + 'TEMT ';
  end;
end;

function TDebugViewer.FormatMSR: String;
begin
  with FSnapshot do
  begin
    Result := 'MSR: ' + IntToHex(MSR, 2) + ' ';
    if DCD then Result := Result + 'DCD ';
    if DSR then Result := Result + 'DSR ';
    if CTS then Result := Result + 'CTS ';
    if RI  then Result := Result + 'RI ';
  end;
end;

function TDebugViewer.FormatMCR: String;
begin
  with FSnapshot do
  begin
    Result := 'MCR: ' + IntToHex(MCR, 2) + ' ';
    if DTR then Result := Result + 'DTR ';
    if RTS then Result := Result + 'RTS ';
    if (MCR and $04) <> 0 then Result := Result + 'OUT1 ';
    if (MCR and $08) <> 0 then Result := Result + 'OUT2 ';
  end;
end;

function TDebugViewer.FormatRingStatus: String;
begin
  with FSnapshot do
    Result := Format('RX: %d/%d  TX: %d/%d  %d-%c-%d %d baud',
      [RXCount, RXSize, TXCount, TXSize,
       DataBits, Parity, StopBits, BaudRate]);
end;

procedure TDebugViewer.ScanATCommands(const Data: array of Byte; Len: Integer);
{ Detect AT modem commands in the guest→network stream.
  Pattern: "AT" followed by command chars, terminated by CR.
  Common: ATDT (dial), ATH (hangup), ATA (answer), ATZ (reset),
  ATE0/ATE1 (echo off/on), ATV0/ATV1 (numeric/verbal responses). }
var I: Integer; Ch: Char;
begin
  for I := 0 to Len - 1 do
  begin
    Ch := UpCase(Chr(Data[I]));
    case FATState of
      0: if Ch = 'A' then begin FATState := 1; FATBuf := 'A'; end;
      1: if Ch = 'T' then begin FATState := 2; FATBuf := 'AT'; end
         else FATState := 0;
      2: begin
           if Data[I] = 13 then
           begin
             { Complete AT command }
             Inc(FSession.ATCommandsSeen);
             FSession.LastATCommand := FATBuf;
             OnEvent(evFossilCall, 'AT command: ' + FATBuf);
             FATState := 0;
             FATBuf := '';
           end
           else if (Ch >= ' ') and (Length(FATBuf) < 80) then
             FATBuf := FATBuf + Chr(Data[I])
           else
             FATState := 0;
         end;
    end;
  end;
end;

procedure TDebugViewer.ScanANSI(const Data: array of Byte; Len: Integer);
{ Detect and classify ANSI escape sequences in BBS→caller data.
  Tracks: color changes (SGR), cursor moves, screen clears.
  Does NOT display the ANSI — just counts and logs events. }
var I: Integer; FinalChar: Char;
begin
  for I := 0 to Len - 1 do
  begin
    case FANSIState of
      0: { normal text }
        if Data[I] = 27 then FANSIState := 1;
      1: { saw ESC }
        if Data[I] = Ord('[') then
        begin
          FANSIState := 2;
          FANSIBuf := '';
        end
        else
          FANSIState := 0;
      2: { inside CSI sequence — accumulate until final byte }
        begin
          if (Data[I] >= $40) and (Data[I] <= $7E) then
          begin
            { Final byte — classify the sequence }
            FinalChar := Chr(Data[I]);
            Inc(FSession.ANSISequencesSent);

            case FinalChar of
              'm': begin { SGR — color/attribute change }
                     Inc(FSession.ColorChanges);
                   end;
              'J': begin { Erase display }
                     if (FANSIBuf = '2') or (FANSIBuf = '') then
                     begin
                       Inc(FSession.ClearScreenCount);
                       OnEvent(evMenuSent, 'Screen cleared (ESC[2J)');
                     end;
                   end;
              'H', 'f': ; { Cursor position — tracked silently }
              'A', 'B', 'C', 'D': ; { Cursor move — tracked silently }
              'K': ; { Erase line }
              's': ; { Save cursor }
              'u': ; { Restore cursor }
              'r': ; { Set scroll region }
            end;
            FANSIState := 0;
          end
          else
            { Parameter byte — accumulate }
            FANSIBuf := FANSIBuf + Chr(Data[I]);
        end;
    end;
  end;
end;

procedure TDebugViewer.UpdateThroughput(ByteCount: Integer);
{ Rolling 1-second throughput counter. }
var Elapsed: Double;
begin
  Elapsed := (Now - FSession.LastSecondTime) * 86400;
  if Elapsed >= 1.0 then
  begin
    { New 1-second window }
    FSession.CurrentBPS := FSession.LastSecondBytes;
    if FSession.CurrentBPS > FSession.PeakBytesPerSec then
      FSession.PeakBytesPerSec := FSession.CurrentBPS;
    FSession.LastSecondBytes := ByteCount;
    FSession.LastSecondTime := Now;
  end
  else
    Inc(FSession.LastSecondBytes, ByteCount);
end;

procedure TDebugViewer.DetectTransferProgress(const Data: array of Byte; Len: Integer);
{ Track Zmodem transfer progress by watching block headers.
  Zmodem ZDATA frames have a file position in the header. }
var I: Integer;
begin
  for I := 0 to Len - 3 do
  begin
    { ZPAD ZPAD ZDLE = Zmodem frame start }
    if (Data[I] = $2A) and (Data[I+1] = $2A) and (Data[I+2] = $18) then
    begin
      if not FSession.TransferActive then
      begin
        FSession.TransferActive := True;
        FSession.TransferStartTime := Now;
        FSession.TransferBytesDone := 0;
        Inc(FSession.ZmodemTransfers);
        OnEvent(evZmodemDetected, 'File transfer started');
      end;
    end;
  end;

  { Track bytes during active transfer }
  if FSession.TransferActive then
    Inc(FSession.TransferBytesDone, Len);
end;

procedure TDebugViewer.ExportToFile(const FileName: String);
{ Export the entire session trace to a human-readable text file. }
var
  F: TextFile;
  I: Integer;
begin
  AssignFile(F, FileName);
  Rewrite(F);
  try
    WriteLn(F, '=== NMServer Session Trace ===');
    WriteLn(F, 'Exported: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    WriteLn(F, 'Node: ', FNodeIndex);
    WriteLn(F);

    { LED panel }
    WriteLn(F, '--- MODEM STATUS ---');
    WriteLn(F, FormatModemHuman);
    WriteLn(F, FormatBufferHuman);
    WriteLn(F);

    { Throughput }
    WriteLn(F, '--- THROUGHPUT ---');
    WriteLn(F, FormatThroughput);
    WriteLn(F);

    { AT commands }
    if FSession.ATCommandsSeen > 0 then
    begin
      WriteLn(F, '--- AT COMMANDS ---');
      WriteLn(F, FormatATStatus);
      WriteLn(F);
    end;

    { ANSI stats }
    if FSession.ANSISequencesSent > 0 then
    begin
      WriteLn(F, '--- ANSI ---');
      WriteLn(F, FormatANSIStats);
      WriteLn(F);
    end;

    { Events }
    WriteLn(F, '--- EVENTS (', FEventCount, ') ---');
    for I := 0 to FEventCount - 1 do
      WriteLn(F, FormatEventHuman(I));
    WriteLn(F);

    { Data stream }
    WriteLn(F, '--- DATA STREAM (', FStreamCount, ' lines) ---');
    for I := 0 to FStreamCount - 1 do
      WriteLn(F, FormatStreamHuman(I));
    WriteLn(F);

    { Session summary }
    WriteLn(F, FormatSessionSummary);
  finally
    CloseFile(F);
  end;

  DebugLog('DebugView', 'Trace exported to ' + FileName);
end;

function TDebugViewer.FormatThroughput: String;
begin
  Result := 'THROUGHPUT: ' + IntToStr(FSession.CurrentBPS) + ' bytes/sec' +
            '  (peak: ' + IntToStr(FSession.PeakBytesPerSec) + ' bytes/sec)';
end;

function TDebugViewer.FormatTransferProgress: String;
var
  Pct, Filled, Empty, I: Integer;
  ElapsedSec: Double;
  BPS: LongInt;
  BarStr: String;
begin
  if not FSession.TransferActive then
  begin
    Result := 'TRANSFER: idle';
    Exit;
  end;

  if FSession.TransferBytesTotal > 0 then
    Pct := (FSession.TransferBytesDone * 100) div FSession.TransferBytesTotal
  else
    Pct := 0;

  Filled := Pct div 10;
  Empty := 10 - Filled;
  BarStr := '';
  for I := 1 to Filled do BarStr := BarStr + '#';
  for I := 1 to Empty do BarStr := BarStr + '.';

  ElapsedSec := (Now - FSession.TransferStartTime) * 86400;
  if ElapsedSec > 0 then
    BPS := Round(FSession.TransferBytesDone / ElapsedSec)
  else
    BPS := 0;

  if FSession.TransferFileName <> '' then
    Result := 'TRANSFER: ' + FSession.TransferFileName + '  '
  else
    Result := 'TRANSFER: ';

  Result := Result + BarStr + '  ' +
            IntToStr(FSession.TransferBytesDone div 1024) + ' KB' +
            '  ' + FormatFloat('0.1', BPS / 1024) + ' KB/sec';
end;

function TDebugViewer.FormatATStatus: String;
begin
  if FSession.ATCommandsSeen = 0 then
    Result := 'AT COMMANDS: none'
  else
    Result := 'AT COMMANDS: ' + IntToStr(FSession.ATCommandsSeen) +
              ' seen, last: ' + FSession.LastATCommand;
end;

function TDebugViewer.FormatANSIStats: String;
begin
  Result := 'ANSI: ' + IntToStr(FSession.ANSISequencesSent) + ' sequences, ' +
            IntToStr(FSession.ClearScreenCount) + ' screen clears, ' +
            IntToStr(FSession.ColorChanges) + ' color changes';
end;

function TDebugViewer.FormatSnapshot: String;
begin
  Result := FormatLSR + #13#10 +
            FormatMSR + #13#10 +
            FormatMCR + #13#10 +
            FormatRingStatus;
end;

function TDebugViewer.FormatStreamHuman(Index: Integer): String;
var
  I, PrintableStart, PrintableEnd: Integer;
  HasPrintable, IsZmodem, IsANSI: Boolean;
  TextPart: String;
  DirStr: String;
begin
  Result := '';
  if (Index < 0) or (Index >= FStreamCount) then Exit;

  with FStream[Index] do
  begin
    { Direction in plain English }
    if Direction = sdNetToUart then
      DirStr := 'CALLER -> BBS '
    else
      DirStr := 'BBS -> CALLER ';

    Result := FormatDateTime('hh:nn:ss', Timestamp) + '  ' + DirStr;

    { Detect what kind of data this is }
    IsZmodem := (Len >= 3) and (Data[0] = $2A) and (Data[1] = $2A) and (Data[2] = $18);
    IsANSI := (Len >= 2) and (Data[0] = 27) and (Data[1] = Ord('['));

    if IsZmodem then
    begin
      Result := Result + '[Zmodem transfer data]';
      Exit;
    end;

    if IsANSI then
    begin
      Result := Result + '[ANSI color/cursor code]';
      Exit;
    end;

    { Check if mostly printable text }
    HasPrintable := False;
    TextPart := '';
    for I := 0 to Len - 1 do
    begin
      if (Data[I] >= 32) and (Data[I] < 127) then
      begin
        HasPrintable := True;
        TextPart := TextPart + Chr(Data[I]);
      end
      else if Data[I] = 13 then
        { skip CR }
      else if Data[I] = 10 then
        TextPart := TextPart + ' '
      else if Data[I] = $FF then
      begin
        Result := Result + '[IAC escaped byte]';
        Exit;
      end
      else
        TextPart := TextPart + '.';
    end;

    if HasPrintable and (Length(TextPart) > 0) then
      Result := Result + '"' + TextPart + '"'
    else
      Result := Result + '[' + IntToStr(Len) + ' bytes binary data]';
  end;
end;

function TDebugViewer.FormatEventHuman(Index: Integer): String;
const
  HUMAN_PREFIX: array[TEventKind] of String = (
    'Caller connected',           { evConnect }
    'Caller disconnected',        { evDisconnect }
    'Connection negotiated',      { evTelnetWill }
    'Connection negotiated',      { evTelnetDo }
    'Connection option declined', { evTelnetWont }
    'Connection option declined', { evTelnetDont }
    'Connection subnegotiation',  { evTelnetSB }
    'BBS called FOSSIL driver',   { evFossilCall }
    'BBS is ready for calls',     { evDTRRaise }
    'BBS hung up the line',       { evDTRLower }
    'Carrier ON - call active',   { evCarrierOn }
    'Carrier OFF - call ended',   { evCarrierOff }
    'Incoming call ringing',      { evRingOn }
    'Ring stopped',               { evRingOff }
    'Break signal sent',          { evBreakStart }
    'Break signal stopped',       { evBreakStop }
    'Flow control changed',       { evFlowControl }
    'Zmodem transfer detected',   { evZmodemDetected }
    'ERROR',                      { evError }
    '8-bit clean data path ready',{ evTelnetBinaryOn }
    'Character-at-a-time mode',   { evTelnetSGAOn }
    'BBS starting up',            { evFossilInit }
    'BBS shutting down',          { evFossilDeinit }
    'Speed set',                  { evFossilSetBaud }
    'BBS checking for data',      { evFossilStatus }
    'BBS reading a character',    { evFossilReadChar }
    'BBS sending a character',    { evFossilWriteChar }
    'BBS reading a data block',   { evFossilBlockRead }
    'BBS sending a data block',   { evFossilBlockWrite }
    'BBS cleared incoming data',  { evFossilPurgeRX }
    'BBS cleared outgoing data',  { evFossilPurgeTX }
    'BBS waiting for data to send',{ evFossilFlush }
    'BBS queried driver info',    { evFossilGetInfo }
    'BBS asking for login',       { evLoginPromptSent }
    'BBS asking for password',    { evPasswordPromptSent }
    'User typed something',       { evUserTyping }
    'BBS sent a menu',            { evMenuSent }
    'BBS saying goodbye',         { evGoodbyeSent }
    'Session ended'               { evSessionSummary }
  );
  HUMAN_ICON: array[TEventKind] of String = (
    '[CALL]   ', '[HANGUP] ', '[SETUP]  ', '[SETUP]  ',
    '[SETUP]  ', '[SETUP]  ', '[SETUP]  ', '[BBS]    ',
    '[READY]  ', '[HANGUP] ', '[LINE]   ', '[LINE]   ',
    '[RING]   ', '[RING]   ', '[BREAK]  ', '[BREAK]  ',
    '[FLOW]   ', '[FILE]   ', '[ERROR]  ',
    '[SETUP]  ', '[SETUP]  ',
    '[START]  ', '[STOP]   ', '[SPEED]  ',
    '[POLL]   ', '[READ]   ', '[WRITE]  ',
    '[BULK]   ', '[BULK]   ',
    '[CLEAR]  ', '[CLEAR]  ', '[WAIT]   ', '[INFO]   ',
    '[LOGIN]  ', '[PASS]   ',
    '[TYPING] ', '[MENU]   ', '[BYE]    ', '[SUMMARY]'
  );
begin
  Result := '';
  if (Index < 0) or (Index >= FEventCount) then Exit;
  with FEvents[Index] do
  begin
    Result := FormatDateTime('hh:nn:ss', Timestamp) + '  ' +
              HUMAN_ICON[Kind] + ' ' + HUMAN_PREFIX[Kind];
    if Detail <> '' then
      Result := Result + ' - ' + Detail;
  end;
end;

function TDebugViewer.FormatModemHuman: String;

  function Light(On: Boolean): String;
  begin
    if On then Result := 'ON ' else Result := 'OFF';
  end;

begin
  with FSnapshot do
    Result := 'CARRIER: ' + Light(DCD) +
              '   RING: ' + Light(RI) +
              '   READY: ' + Light(DSR) +
              '   SEND READY: ' + Light(CTS) + #13#10 +
              'DTR: ' + Light(DTR) +
              '   RTS: ' + Light(RTS) + #13#10 +
              'SPEED: ' + IntToStr(BaudRate) + ' baud, ' +
              IntToStr(DataBits) + ' data bits, ' +
              'parity ' + Parity + ', ' +
              IntToStr(StopBits) + ' stop bit(s)';
end;

function TDebugViewer.FormatBufferHuman: String;

  function Bar(Count, Size: Word): String;
  var
    Filled, Empty, I: Integer;
  begin
    if Size = 0 then begin Result := '[empty]'; Exit; end;
    Filled := (Count * 8) div Size;
    Empty := 8 - Filled;
    Result := '';
    for I := 1 to Filled do Result := Result + '#';
    for I := 1 to Empty do Result := Result + '.';
  end;

begin
  with FSnapshot do
    Result := 'RECEIVE:  ' + Bar(RXCount, RXSize) +
              '  ' + IntToStr(RXCount) + '/' + IntToStr(RXSize) +
              ' bytes waiting for BBS' + #13#10 +
              'TRANSMIT: ' + Bar(TXCount, TXSize) +
              '  ' + IntToStr(TXCount) + '/' + IntToStr(TXSize) +
              ' bytes waiting to send';
end;

function TDebugViewer.FormatModemLEDs: String;
{ Render the front panel of a USR Courier modem.
  LED states: [*] = on, [ ] = off, [~] = activity (blinking)

  Real USR Courier V.Everything front panel (left to right):
    AA  Auto Answer      — modem will answer incoming calls
    CD  Carrier Detect   — connected to remote modem
    OH  Off Hook         — phone is off the hook (in a call)
    RD  Receive Data     — data coming FROM the remote
    SD  Send Data        — data going TO the remote
    TR  Terminal Ready   — DTR is raised (computer is ready)
    MR  Modem Ready      — DSR (modem powered and ready)
    CS  Clear to Send    — CTS handshake
    HS  High Speed       — connected at high speed
    ARQ Auto Reliable    — error correction active

  In our virtual modem:
    AA = always on (we always accept connections)
    CD = FSnapshot.DCD (carrier detect from UART MSR)
    OH = connected (any active session)
    RD = data received in last 200ms
    SD = data sent in last 200ms
    TR = FSnapshot.DTR (terminal ready from UART MCR)
    MR = FSnapshot.DSR (modem ready from UART MSR)
    CS = FSnapshot.CTS (clear to send from UART MSR)
    HS = baud >= 9600
    ARQ = always on (TCP is reliable) }

  function LED(On: Boolean; Active: Boolean = False): String;
  begin
    if Active then Result := '[~]'
    else if On then Result := '[*]'
    else Result := '[ ]';
  end;

var
  RDFlicker, SDFlicker: Boolean;
  Elapsed: Double;
begin
  { Check if RD/SD LEDs should be flickering (activity in last 200ms) }
  Elapsed := (Now - FLedRDTime) * 86400;
  RDFlicker := FLedRDActive and (Elapsed < 0.2);
  if not RDFlicker then FLedRDActive := False;

  Elapsed := (Now - FLedSDTime) * 86400;
  SDFlicker := FLedSDActive and (Elapsed < 0.2);
  if not SDFlicker then FLedSDActive := False;

  with FSnapshot do
  begin
    Result :=
      '  ╔══════════════════════════════════════════════════════╗' + #13#10 +
      '  ║  US Robotics    NetModem/32    Virtual Modem        ║' + #13#10 +
      '  ║                                                     ║' + #13#10 +
      '  ║  ' +
      LED(True) + '  ' +               { AA — always on }
      LED(DCD) + '  ' +                { CD }
      LED(FAttached and DCD) + '  ' +  { OH }
      LED(RDFlicker, RDFlicker) + '  ' + { RD }
      LED(SDFlicker, SDFlicker) + '  ' + { SD }
      LED(DTR) + '  ' +                { TR }
      LED(DSR) + '  ' +                { MR }
      LED(CTS) + '  ' +                { CS }
      LED(BaudRate >= 9600) + '  ' +   { HS }
      LED(True) +                       { ARQ — TCP is reliable }
      '  ║' + #13#10 +
      '  ║  AA   CD   OH   RD   SD   TR   MR   CS   HS  ARQ  ║' + #13#10 +
      '  ╚══════════════════════════════════════════════════════╝';
  end;
end;

function TDebugViewer.FormatLEDDetail: String;
{ Explain what each LED means in the current state. }
begin
  with FSnapshot do
  begin
    Result := '';
    Result := Result + 'AA  Auto Answer     [*] Always on - accepting connections' + #13#10;

    if DCD then
      Result := Result + 'CD  Carrier Detect  [*] Caller is connected' + #13#10
    else
      Result := Result + 'CD  Carrier Detect  [ ] No caller connected' + #13#10;

    if FAttached and DCD then
      Result := Result + 'OH  Off Hook        [*] In a call' + #13#10
    else
      Result := Result + 'OH  Off Hook        [ ] Idle - waiting for calls' + #13#10;

    if FLedRDActive then
      Result := Result + 'RD  Receive Data    [~] Receiving data from caller' + #13#10
    else
      Result := Result + 'RD  Receive Data    [ ] No incoming data' + #13#10;

    if FLedSDActive then
      Result := Result + 'SD  Send Data       [~] Sending data to caller' + #13#10
    else
      Result := Result + 'SD  Send Data       [ ] No outgoing data' + #13#10;

    if DTR then
      Result := Result + 'TR  Terminal Ready  [*] BBS is ready' + #13#10
    else
      Result := Result + 'TR  Terminal Ready  [ ] BBS not ready (DTR down)' + #13#10;

    if DSR then
      Result := Result + 'MR  Modem Ready     [*] Modem is ready' + #13#10
    else
      Result := Result + 'MR  Modem Ready     [ ] Modem not ready' + #13#10;

    if CTS then
      Result := Result + 'CS  Clear to Send   [*] OK to send data' + #13#10
    else
      Result := Result + 'CS  Clear to Send   [ ] Hold - not clear to send' + #13#10;

    if BaudRate >= 9600 then
      Result := Result + 'HS  High Speed      [*] ' + IntToStr(BaudRate) + ' baud' + #13#10
    else
      Result := Result + 'HS  High Speed      [ ] ' + IntToStr(BaudRate) + ' baud (low speed)' + #13#10;

    Result := Result + 'ARQ Error Correct   [*] TCP - reliable connection';
  end;
end;

end.
