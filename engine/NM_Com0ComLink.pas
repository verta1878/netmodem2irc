{ ===========================================================================
  NM_Com0ComLink — ISocketLink over a com0com virtual COM port pair
  GPLv3 — Copyright (C) 2026 wrench (netmodem2irc)
  ---------------------------------------------------------------------------
  M4 Virtual COM path (Option B). Uses com0com or any virtual
  create paired virtual COM ports. The BBS opens one side (COM3),
  NMServer opens the other side (COM4) via this link.

  Architecture:
    BBS Door → COM3 (virtual) → com0com pair → COM4 (virtual) → this unit
    This unit implements ISocketLink, so it plugs directly into
    TNetTransport and TNetModemNode unchanged.

  Platform: Windows NT/2000/XP/7/8/10/11
  Optional: com0com or any virtual null-modem (user-installed).
            or any virtual null-modem (e.g. VSPE, Virtual Serial Port Driver)

  Build: ppc386 -Twin32 NM_Com0ComLink.pas (or ppcx64 -Twin64)
  =========================================================================== }

{$MODE OBJFPC}{$H+}

unit NM_Com0ComLink;

interface

uses
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  SysUtils, NetTransport;

type
  { ISocketLink implementation over a Win32 COM port handle. }
  TCom0ComLink = class(TInterfacedObject, ISocketLink)
  private
    {$IFDEF WINDOWS}
    FHandle : THandle;
    {$ELSE}
    FHandle : PtrInt;
    {$ENDIF}
    FPortName : string;
    FConnected: Boolean;
  public
    constructor Create;
    destructor  Destroy; override;

    { Open the B-side of a com0com pair (e.g. 'COM4').
      Configures: 115200 8N1, non-blocking (10ms read timeout).
      Returns True on success. }
    function Open(const APortName: string; ABaud: LongInt = 115200): Boolean;

    { ISocketLink }
    function Connect(const AHost: string; APort: Word): TLinkResult;
    function Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
    function Recv(var Buf; Len: Integer; out Got: Integer): TLinkResult;
    procedure Close;
    function IsConnected: Boolean;

    property PortName: string read FPortName;
  end;

implementation

constructor TCom0ComLink.Create;
begin
  inherited Create;
  {$IFDEF WINDOWS}
  FHandle := INVALID_HANDLE_VALUE;
  {$ELSE}
  FHandle := -1;  { PtrInt: safe on 32 and 64-bit }
  {$ENDIF}
  FPortName := '';
  FConnected := False;
end;

destructor TCom0ComLink.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TCom0ComLink.Open(const APortName: string; ABaud: LongInt): Boolean;
{$IFDEF WINDOWS}
var
  DevName: string;
  DCB: TDCB;
  Timeouts: TCommTimeouts;
begin
  Result := False;
  Close;

  { COM10+ needs \\.\COM10 syntax }
  if (Length(APortName) > 4) or
     (StrToIntDef(Copy(APortName, 4, Length(APortName)), 0) >= 10) then
    DevName := '\\.\' + APortName
  else
    DevName := APortName;

  FHandle := CreateFile(PChar(DevName),
    GENERIC_READ or GENERIC_WRITE, 0, nil,
    OPEN_EXISTING, 0, 0);

  if FHandle = INVALID_HANDLE_VALUE then Exit;

  { Configure: 8N1, requested baud }
  FillChar(DCB, SizeOf(DCB), 0);
  DCB.DCBlength := SizeOf(DCB);
  if not GetCommState(FHandle, DCB) then
  begin
    CloseHandle(FHandle);
    FHandle := INVALID_HANDLE_VALUE;
    Exit;
  end;

  DCB.BaudRate := ABaud;
  DCB.ByteSize := 8;
  DCB.Parity := NOPARITY;
  DCB.StopBits := ONESTOPBIT;
  DCB.Flags := DCB.Flags or $01;  { fBinary = 1 }

  if not SetCommState(FHandle, DCB) then
  begin
    CloseHandle(FHandle);
    FHandle := INVALID_HANDLE_VALUE;
    Exit;
  end;

  { Non-blocking reads: return immediately if no data,
    but wait up to 10ms for at least 1 byte }
  Timeouts.ReadIntervalTimeout := MAXDWORD;
  Timeouts.ReadTotalTimeoutMultiplier := 0;
  Timeouts.ReadTotalTimeoutConstant := 10;
  Timeouts.WriteTotalTimeoutMultiplier := 0;
  Timeouts.WriteTotalTimeoutConstant := 1000;
  SetCommTimeouts(FHandle, Timeouts);

  { Raise DTR + RTS }
  EscapeCommFunction(FHandle, SETDTR);
  EscapeCommFunction(FHandle, SETRTS);

  FPortName := APortName;
  FConnected := True;
  Result := True;
end;
{$ELSE}
begin
  { Non-Windows: com0com doesn't exist. Use NM_SynapseLink instead. }
  Result := False;
end;
{$ENDIF}

function TCom0ComLink.Connect(const AHost: string; APort: Word): TLinkResult;
begin
  { For com0com, "connect" means Open() was called with the port name.
    This method is here for ISocketLink compatibility.
    AHost = port name (e.g. 'COM4'), APort ignored. }
  if Open(AHost) then
    Result := lrOk
  else
    Result := lrError;
end;

function TCom0ComLink.Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
{$IFDEF WINDOWS}
var Written: DWORD;
begin
  Sent := 0;
  if FHandle = INVALID_HANDLE_VALUE then begin Result := lrClosed; Exit; end;
  if WriteFile(FHandle, Buf, Len, Written, nil) then
  begin
    Sent := Written;
    Result := lrOk;
  end
  else
  begin
    FConnected := False;
    Result := lrClosed;
  end;
end;
{$ELSE}
begin Sent := 0; Result := lrClosed; end;
{$ENDIF}

function TCom0ComLink.Recv(var Buf; Len: Integer; out Got: Integer): TLinkResult;
{$IFDEF WINDOWS}
var BytesRead: DWORD;
begin
  Got := 0;
  if FHandle = INVALID_HANDLE_VALUE then begin Result := lrClosed; Exit; end;
  if ReadFile(FHandle, Buf, Len, BytesRead, nil) then
  begin
    Got := BytesRead;
    if Got = 0 then
      Result := lrWouldBlock   { no data available right now }
    else
      Result := lrOk;
  end
  else
  begin
    FConnected := False;
    Result := lrClosed;
  end;
end;
{$ELSE}
begin Got := 0; Result := lrClosed; end;
{$ENDIF}

procedure TCom0ComLink.Close;
{$IFDEF WINDOWS}
begin
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    EscapeCommFunction(FHandle, CLRDTR);
    CloseHandle(FHandle);
  end;
  FHandle := INVALID_HANDLE_VALUE;
  FConnected := False;
end;
{$ELSE}
begin
  FHandle := -1;  { PtrInt: safe on 32 and 64-bit }
  FConnected := False;
end;
{$ENDIF}

function TCom0ComLink.IsConnected: Boolean;
begin
  {$IFDEF WINDOWS}
  Result := FConnected and (FHandle <> INVALID_HANDLE_VALUE);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

end.
