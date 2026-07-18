unit NM_GlobalConfig;
{ ===========================================================================
  netmodem2irc — global configuration (server-level settings)
  ---------------------------------------------------------------------------
  Matches the original NetModem/32 CPL global settings from NETCONFIG.CNF.
  The VxD only reads ComportConfig + IRQ from the registry (per-node).
  All global settings are server-side, stored in NETCONFIG.CNF or the
  registry under HKLM\Software\Allen Software\NetModem.

  Original CPL forms:
    TForm1 Panel1 — global checkboxes + server options
    TForm2        — Listserv info
    TForm3        — Global config (node destination selector)
    TForm4        — Log viewer
    TForm5        — Icon legend
    TForm6        — Address book entry (blocking/forwarding)

  Config files:
    NETCONFIG.CNF  — main config (global settings)
    NETSERVER.CNF  — server config
    NETMODEM.BLK   — blocked addresses
    NETMODEM.EVT   — event log
    NETMODEM.PRF   — preferences
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils;

type
  TNMGlobalConfig = class
  private
    { Server behavior }
    FStartAsService    : Boolean;  // Start as system service
    FSuppressSplash    : Boolean;  // Suppress splash screen
    FAutoMinimize      : Boolean;  // Auto-minimize on startup
    FEnableSpinningGlobe: Boolean; // Enable spinning globe animation

    { Logging }
    FServerLogging     : Boolean;  // Server logging enabled
    FActivityLog       : Boolean;  // Server activity log
    FLogFileDays       : Integer;  // Days to keep log files
    FLogFileMaxSize    : Integer;  // Max log file size (KB)

    { Network }
    FRetrieveLocalHost : Boolean;  // Retrieve local host info
    FExplicitBind      : Boolean;  // Explicit bind to address
    FBindAddress       : string;   // Bind address (if explicit)
    FAllowUnknownHosts : Boolean;  // Allow unknown hosts
    FAllowDuplicateConn: Boolean;  // Allow duplicate connections

    { Display files }
    FDisplayBusyFile   : Boolean;  // Display busy file
    FDisplayOfflineFile: Boolean;  // Display offline file
    FDisplayBlockedFile: Boolean;  // Display blocked file
    FDisplayConnectFile: Boolean;  // Display connect file
    FDisplayDisconnectFile: Boolean; // Display disconnect file
    FDisplayErrorFile  : Boolean;  // Display error file
    FDisplayDuplicateFile: Boolean; // Display duplicate file

    { Features }
    FEnableAutoNews    : Boolean;  // Enable Auto-News
    FAutoNewsInterval  : Integer;  // Auto-News interval (minutes)
    FEnableListserv    : Boolean;  // Enable BBS Listserv

    { Buffers }
    FInternalCacheSize : Integer;  // Internal cache size
    FRingCount         : Integer;  // Ring count before answer

    { Paths }
    FNetModemDir       : string;   // NetModem installation directory
  public
    constructor Create;
    procedure LoadDefaults;

    {$IFDEF WINDOWS}
    procedure LoadFromRegistry;
    procedure SaveToRegistry;
    {$ENDIF}

    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);

    { Server behavior }
    property StartAsService: Boolean read FStartAsService write FStartAsService;
    property SuppressSplash: Boolean read FSuppressSplash write FSuppressSplash;
    property AutoMinimize: Boolean read FAutoMinimize write FAutoMinimize;
    property EnableSpinningGlobe: Boolean read FEnableSpinningGlobe write FEnableSpinningGlobe;

    { Logging }
    property ServerLogging: Boolean read FServerLogging write FServerLogging;
    property ActivityLog: Boolean read FActivityLog write FActivityLog;
    property LogFileDays: Integer read FLogFileDays write FLogFileDays;
    property LogFileMaxSize: Integer read FLogFileMaxSize write FLogFileMaxSize;

    { Network }
    property RetrieveLocalHost: Boolean read FRetrieveLocalHost write FRetrieveLocalHost;
    property ExplicitBind: Boolean read FExplicitBind write FExplicitBind;
    property BindAddress: string read FBindAddress write FBindAddress;
    property AllowUnknownHosts: Boolean read FAllowUnknownHosts write FAllowUnknownHosts;
    property AllowDuplicateConn: Boolean read FAllowDuplicateConn write FAllowDuplicateConn;

    { Display files }
    property DisplayBusyFile: Boolean read FDisplayBusyFile write FDisplayBusyFile;
    property DisplayOfflineFile: Boolean read FDisplayOfflineFile write FDisplayOfflineFile;
    property DisplayBlockedFile: Boolean read FDisplayBlockedFile write FDisplayBlockedFile;
    property DisplayConnectFile: Boolean read FDisplayConnectFile write FDisplayConnectFile;
    property DisplayDisconnectFile: Boolean read FDisplayDisconnectFile write FDisplayDisconnectFile;
    property DisplayErrorFile: Boolean read FDisplayErrorFile write FDisplayErrorFile;
    property DisplayDuplicateFile: Boolean read FDisplayDuplicateFile write FDisplayDuplicateFile;

    { Features }
    property EnableAutoNews: Boolean read FEnableAutoNews write FEnableAutoNews;
    property AutoNewsInterval: Integer read FAutoNewsInterval write FAutoNewsInterval;
    property EnableListserv: Boolean read FEnableListserv write FEnableListserv;

    { Buffers }
    property InternalCacheSize: Integer read FInternalCacheSize write FInternalCacheSize;
    property RingCount: Integer read FRingCount write FRingCount;

    { Paths }
    property NetModemDir: string read FNetModemDir write FNetModemDir;
  end;

implementation

{$IFDEF WINDOWS}
uses Registry, Windows;
{$ENDIF}

const
  REG_KEY = 'Software\Allen Software\NetModem';
  CFG_FILE = 'NETCONFIG.CNF';

constructor TNMGlobalConfig.Create;
begin
  inherited Create;
  LoadDefaults;
end;

procedure TNMGlobalConfig.LoadDefaults;
begin
  FStartAsService     := False;
  FSuppressSplash     := False;
  FAutoMinimize       := False;
  FEnableSpinningGlobe := True;
  FServerLogging      := True;
  FActivityLog        := True;
  FLogFileDays        := 30;
  FLogFileMaxSize     := 1024;
  FRetrieveLocalHost  := True;
  FExplicitBind       := False;
  FBindAddress        := '';
  FAllowUnknownHosts  := True;
  FAllowDuplicateConn := False;
  FDisplayBusyFile    := True;
  FDisplayOfflineFile := True;
  FDisplayBlockedFile := True;
  FDisplayConnectFile := False;
  FDisplayDisconnectFile := False;
  FDisplayErrorFile   := False;
  FDisplayDuplicateFile := False;
  FEnableAutoNews     := False;
  FAutoNewsInterval   := 60;
  FEnableListserv     := False;
  FInternalCacheSize  := 4096;
  FRingCount          := 1;
  FNetModemDir        := '';
end;

{$IFDEF WINDOWS}
procedure TNMGlobalConfig.LoadFromRegistry;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly(REG_KEY) then
    begin
      if Reg.ValueExists('StartasService')    then FStartAsService     := Reg.ReadBool('StartasService');
      if Reg.ValueExists('SuppressSplash')    then FSuppressSplash     := Reg.ReadBool('SuppressSplash');
      if Reg.ValueExists('AutoMinimize')      then FAutoMinimize       := Reg.ReadBool('AutoMinimize');
      if Reg.ValueExists('SpinningGlobe')     then FEnableSpinningGlobe := Reg.ReadBool('SpinningGlobe');
      if Reg.ValueExists('ServerLogging')     then FServerLogging      := Reg.ReadBool('ServerLogging');
      if Reg.ValueExists('ActivityLog')       then FActivityLog        := Reg.ReadBool('ActivityLog');
      if Reg.ValueExists('LogFileDays')       then FLogFileDays        := Reg.ReadInteger('LogFileDays');
      if Reg.ValueExists('LogFileMaxSize')    then FLogFileMaxSize     := Reg.ReadInteger('LogFileMaxSize');
      if Reg.ValueExists('RetrieveLocalHost') then FRetrieveLocalHost  := Reg.ReadBool('RetrieveLocalHost');
      if Reg.ValueExists('ExplicitBind')      then FExplicitBind       := Reg.ReadBool('ExplicitBind');
      if Reg.ValueExists('BindAddress')       then FBindAddress        := Reg.ReadString('BindAddress');
      if Reg.ValueExists('AllowUnknownHosts') then FAllowUnknownHosts  := Reg.ReadBool('AllowUnknownHosts');
      if Reg.ValueExists('AllowDuplicateConn') then FAllowDuplicateConn := Reg.ReadBool('AllowDuplicateConn');
      if Reg.ValueExists('DisplayBusyFile')   then FDisplayBusyFile    := Reg.ReadBool('DisplayBusyFile');
      if Reg.ValueExists('DisplayOfflineFile') then FDisplayOfflineFile := Reg.ReadBool('DisplayOfflineFile');
      if Reg.ValueExists('DisplayBlockedFile') then FDisplayBlockedFile := Reg.ReadBool('DisplayBlockedFile');
      if Reg.ValueExists('EnableAutoNews')    then FEnableAutoNews     := Reg.ReadBool('EnableAutoNews');
      if Reg.ValueExists('AutoNewsInterval')  then FAutoNewsInterval   := Reg.ReadInteger('AutoNewsInterval');
      if Reg.ValueExists('EnableListserv')    then FEnableListserv     := Reg.ReadBool('EnableListserv');
      if Reg.ValueExists('InternalCacheSize') then FInternalCacheSize  := Reg.ReadInteger('InternalCacheSize');
      if Reg.ValueExists('RingCount')         then FRingCount          := Reg.ReadInteger('RingCount');
      if Reg.ValueExists('NetModemDir')       then FNetModemDir        := Reg.ReadString('NetModemDir');
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

procedure TNMGlobalConfig.SaveToRegistry;
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKey(REG_KEY, True) then
    begin
      Reg.WriteBool('StartasService', FStartAsService);
      Reg.WriteBool('SuppressSplash', FSuppressSplash);
      Reg.WriteBool('AutoMinimize', FAutoMinimize);
      Reg.WriteBool('SpinningGlobe', FEnableSpinningGlobe);
      Reg.WriteBool('ServerLogging', FServerLogging);
      Reg.WriteBool('ActivityLog', FActivityLog);
      Reg.WriteInteger('LogFileDays', FLogFileDays);
      Reg.WriteInteger('LogFileMaxSize', FLogFileMaxSize);
      Reg.WriteBool('RetrieveLocalHost', FRetrieveLocalHost);
      Reg.WriteBool('ExplicitBind', FExplicitBind);
      Reg.WriteString('BindAddress', FBindAddress);
      Reg.WriteBool('AllowUnknownHosts', FAllowUnknownHosts);
      Reg.WriteBool('AllowDuplicateConn', FAllowDuplicateConn);
      Reg.WriteBool('DisplayBusyFile', FDisplayBusyFile);
      Reg.WriteBool('DisplayOfflineFile', FDisplayOfflineFile);
      Reg.WriteBool('DisplayBlockedFile', FDisplayBlockedFile);
      Reg.WriteBool('EnableAutoNews', FEnableAutoNews);
      Reg.WriteInteger('AutoNewsInterval', FAutoNewsInterval);
      Reg.WriteBool('EnableListserv', FEnableListserv);
      Reg.WriteInteger('InternalCacheSize', FInternalCacheSize);
      Reg.WriteInteger('RingCount', FRingCount);
      Reg.WriteString('NetModemDir', FNetModemDir);
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;
{$ENDIF}

procedure TNMGlobalConfig.LoadFromFile(const AFileName: string);
var
  F: TextFile;
  S, Key, Val: string;
  EqPos: Integer;
begin
  if not FileExists(AFileName) then Exit;
  AssignFile(F, AFileName);
  Reset(F);
  while not EOF(F) do
  begin
    ReadLn(F, S);
    S := Trim(S);
    if (S = '') or (S[1] = ';') or (S[1] = '#') then Continue;
    EqPos := Pos('=', S);
    if EqPos = 0 then Continue;
    Key := Trim(Copy(S, 1, EqPos - 1));
    Val := Trim(Copy(S, EqPos + 1, Length(S)));

    if Key = 'StartAsService'     then FStartAsService     := Val = '1'
    else if Key = 'SuppressSplash' then FSuppressSplash     := Val = '1'
    else if Key = 'AutoMinimize'   then FAutoMinimize       := Val = '1'
    else if Key = 'SpinningGlobe'  then FEnableSpinningGlobe := Val = '1'
    else if Key = 'ServerLogging'  then FServerLogging      := Val = '1'
    else if Key = 'ActivityLog'    then FActivityLog        := Val = '1'
    else if Key = 'LogFileDays'    then FLogFileDays        := StrToIntDef(Val, 30)
    else if Key = 'LogFileMaxSize' then FLogFileMaxSize     := StrToIntDef(Val, 1024)
    else if Key = 'RetrieveLocalHost' then FRetrieveLocalHost := Val = '1'
    else if Key = 'ExplicitBind'   then FExplicitBind       := Val = '1'
    else if Key = 'BindAddress'    then FBindAddress        := Val
    else if Key = 'AllowUnknownHosts' then FAllowUnknownHosts := Val = '1'
    else if Key = 'AllowDuplicateConn' then FAllowDuplicateConn := Val = '1'
    else if Key = 'DisplayBusyFile' then FDisplayBusyFile   := Val = '1'
    else if Key = 'DisplayOfflineFile' then FDisplayOfflineFile := Val = '1'
    else if Key = 'DisplayBlockedFile' then FDisplayBlockedFile := Val = '1'
    else if Key = 'EnableAutoNews' then FEnableAutoNews     := Val = '1'
    else if Key = 'AutoNewsInterval' then FAutoNewsInterval  := StrToIntDef(Val, 60)
    else if Key = 'EnableListserv' then FEnableListserv     := Val = '1'
    else if Key = 'InternalCacheSize' then FInternalCacheSize := StrToIntDef(Val, 4096)
    else if Key = 'RingCount'      then FRingCount          := StrToIntDef(Val, 1)
    else if Key = 'NetModemDir'    then FNetModemDir        := Val;
  end;
  CloseFile(F);
end;

procedure TNMGlobalConfig.SaveToFile(const AFileName: string);
var F: TextFile;

  procedure WB(const Key: string; Val: Boolean);
  begin if Val then WriteLn(F, Key, '=1') else WriteLn(F, Key, '=0'); end;
  procedure WI(const Key: string; Val: Integer);
  begin WriteLn(F, Key, '=', Val); end;
  procedure WS(const Key, Val: string);
  begin WriteLn(F, Key, '=', Val); end;

begin
  AssignFile(F, AFileName);
  Rewrite(F);
  WriteLn(F, '; NetModem/32 global configuration');
  WB('StartAsService', FStartAsService);
  WB('SuppressSplash', FSuppressSplash);
  WB('AutoMinimize', FAutoMinimize);
  WB('SpinningGlobe', FEnableSpinningGlobe);
  WB('ServerLogging', FServerLogging);
  WB('ActivityLog', FActivityLog);
  WI('LogFileDays', FLogFileDays);
  WI('LogFileMaxSize', FLogFileMaxSize);
  WB('RetrieveLocalHost', FRetrieveLocalHost);
  WB('ExplicitBind', FExplicitBind);
  WS('BindAddress', FBindAddress);
  WB('AllowUnknownHosts', FAllowUnknownHosts);
  WB('AllowDuplicateConn', FAllowDuplicateConn);
  WB('DisplayBusyFile', FDisplayBusyFile);
  WB('DisplayOfflineFile', FDisplayOfflineFile);
  WB('DisplayBlockedFile', FDisplayBlockedFile);
  WB('EnableAutoNews', FEnableAutoNews);
  WI('AutoNewsInterval', FAutoNewsInterval);
  WB('EnableListserv', FEnableListserv);
  WI('InternalCacheSize', FInternalCacheSize);
  WI('RingCount', FRingCount);
  WS('NetModemDir', FNetModemDir);
  CloseFile(F);
end;

end.
