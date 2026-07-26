unit NM_NamedPipeLink;
{ ===========================================================================
  netmodem2irc — named-pipe socket link (the driver<->server seam)
  ---------------------------------------------------------------------------
  Implements ISocketLink over a Windows NAMED PIPE instead of a TCP socket.

  This is the seam that ties Option A together (see Option_A_scoping.md):

     [C/C++ UMDF2 virtual COM driver]  <-- presents COMx to DOS software
            |  \\.\pipe\netmodem-nodeN
            v
     [this unit: NamedPipeLink]         <-- ISocketLink over the pipe
            |
            v
     [NetTransport / UART / FOSSIL / AT]  <-- the tested Pascal brain
            |
            v
     [NM_SynapseLink]  ---------------->  the remote BBS over TCP

  So a byte written by the DOS door to its COM port travels: driver -> pipe ->
  NamedPipeLink -> our emulation/transport -> Synapse -> the BBS. And back.

  NOTE ON ROLE: unlike NM_SynapseLink (which DIALS OUT over TCP), this link is
  the LOCAL IPC to the driver. Its "Connect" opens/attaches the pipe; the driver
  is the other end. It reuses the SAME ISocketLink interface so the existing
  transport code drives it unchanged — the whole point of the abstraction.

  ---------------------------------------------------------------------------
  BUILD GUARD: real named-pipe I/O is Windows-only (CreateFile/ReadFile/
  WriteFile on \\.\pipe\...). Guarded by HAS_WINPIPE (-dHAS_WINPIPE). Without it
  the unit compiles to a stub (CreatePipeLink returns nil), so the repo builds
  anywhere. Define HAS_WINPIPE on a Windows build for the real pipe.

  VERIFICATION NOTE (honest): the pipe I/O path is written against the stable
  Win32 named-pipe API but can only be RUNTIME-tested on Windows against the
  actual driver. The link LOGIC (framing, non-blocking semantics, ISocketLink
  contract) is tested here with a fake pipe backend.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, NetTransport
  {$IFDEF HAS_WINPIPE}, Windows{$ENDIF};

type
  { A pluggable low-level pipe backend so the link logic is testable without a
    real pipe. The Windows backend uses the OS; the fake backend is in-memory. }
  IPipeBackend = interface
    ['{7E3A1C40-0002-4E00-9A00-000000000002}']
    function Open(const APipeName: string): Boolean;
    function WriteBytes(const Buf; Len: Integer; out Written: Integer): Boolean;
    function ReadBytes(var Buf; Len: Integer; out ReadCount: Integer): Boolean; // non-blocking
    procedure CloseBackend;
    function IsOpen: Boolean;
  end;

  { The ISocketLink implementation over a pipe backend. }
  TNamedPipeLink = class(TInterfacedObject, ISocketLink)
  private
    FBackend : IPipeBackend;
    FPipeName: string;
    FOpen    : Boolean;
  public
    constructor Create(ABackend: IPipeBackend; const APipeName: string);
    function Connect(const AHost: string; APort: Word): TLinkResult;
    function Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
    function Recv(var Buf; Len: Integer; out Got: Integer): TLinkResult;
    procedure Close;
    function IsConnected: Boolean;
  end;

{$IFDEF HAS_WINPIPE}
type
  { Real Windows named-pipe backend. }
  TWinPipeBackend = class(TInterfacedObject, IPipeBackend)
  private
    FHandle: THandle;
  public
    constructor Create;
    function Open(const APipeName: string): Boolean;
    function WriteBytes(const Buf; Len: Integer; out Written: Integer): Boolean;
    function ReadBytes(var Buf; Len: Integer; out ReadCount: Integer): Boolean;
    procedure CloseBackend;
    function IsOpen: Boolean;
  end;
{$ENDIF}

{ Factory: builds a NamedPipeLink over the real Windows pipe backend if built
  with -dHAS_WINPIPE, else nil (no backend). APipeName like
  '\\.\pipe\netmodem-node3'. }
function CreatePipeLink(const APipeName: string): ISocketLink;

implementation

{ ---------------- TNamedPipeLink ---------------- }

constructor TNamedPipeLink.Create(ABackend: IPipeBackend; const APipeName: string);
begin
  inherited Create;
  FBackend := ABackend;
  FPipeName := APipeName;
  FOpen := False;
end;

{ For a pipe, "Connect" ignores host/port and opens the named pipe instead —
  the driver is the other end. Host/port are part of the ISocketLink contract
  but not meaningful here; the pipe name was given at construction. }
function TNamedPipeLink.Connect(const AHost: string; APort: Word): TLinkResult;
begin
  if FBackend = nil then Exit(lrError);
  if FBackend.Open(FPipeName) then
  begin
    FOpen := True;
    Result := lrOk;
  end
  else
  begin
    FOpen := False;
    Result := lrError;
  end;
end;

function TNamedPipeLink.Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
begin
  Sent := 0;
  if (not FOpen) or (FBackend = nil) then Exit(lrClosed);
  if FBackend.WriteBytes(Buf, Len, Sent) then
    Result := lrOk
  else
  begin
    FOpen := False;
    Result := lrClosed;
  end;
end;

function TNamedPipeLink.Recv(var Buf; Len: Integer; out Got: Integer): TLinkResult;
begin
  Got := 0;
  if (not FOpen) or (FBackend = nil) then Exit(lrClosed);
  if FBackend.ReadBytes(Buf, Len, Got) then
  begin
    if Got > 0 then Result := lrOk
    else Result := lrWouldBlock;   // non-blocking: nothing available now
  end
  else
  begin
    FOpen := False;
    Result := lrClosed;
  end;
end;

procedure TNamedPipeLink.Close;
begin
  if FBackend <> nil then FBackend.CloseBackend;
  FOpen := False;
end;

function TNamedPipeLink.IsConnected: Boolean;
begin
  Result := FOpen and (FBackend <> nil) and FBackend.IsOpen;
end;

{ ---------------- TWinPipeBackend (real Windows) ---------------- }

{$IFDEF HAS_WINPIPE}
constructor TWinPipeBackend.Create;
begin
  inherited Create;
  FHandle := INVALID_HANDLE_VALUE;
end;

function TWinPipeBackend.Open(const APipeName: string): Boolean;
begin
  { Client side: open an existing pipe the driver created. For a server-side
    role, a real build would use CreateNamedPipe + ConnectNamedPipe instead. }
  FHandle := CreateFile(PChar(APipeName),
                        GENERIC_READ or GENERIC_WRITE,
                        0, nil, OPEN_EXISTING,
                        FILE_FLAG_OVERLAPPED, 0);
  Result := FHandle <> INVALID_HANDLE_VALUE;
  if Result then
  begin
    { set non-blocking-ish read mode }
    var mode: DWORD := PIPE_READMODE_BYTE or PIPE_NOWAIT;
    SetNamedPipeHandleState(FHandle, @mode, nil, nil);
  end;
end;

function TWinPipeBackend.WriteBytes(const Buf; Len: Integer; out Written: Integer): Boolean;
var w: DWORD;
begin
  Written := 0;
  if FHandle = INVALID_HANDLE_VALUE then Exit(False);
  if WriteFile(FHandle, Buf, DWORD(Len), w, nil) then
  begin
    Written := Integer(w);
    Result := True;
  end
  else
    Result := False;
end;

function TWinPipeBackend.ReadBytes(var Buf; Len: Integer; out ReadCount: Integer): Boolean;
var r: DWORD;
begin
  ReadCount := 0;
  if FHandle = INVALID_HANDLE_VALUE then Exit(False);
  { PIPE_NOWAIT: ReadFile returns immediately; 0 bytes + ERROR_NO_DATA = empty }
  if ReadFile(FHandle, Buf, DWORD(Len), r, nil) then
  begin
    ReadCount := Integer(r);
    Result := True;
  end
  else
  begin
    if GetLastError = ERROR_NO_DATA then
    begin
      ReadCount := 0;
      Result := True;      // pipe open, just nothing to read
    end
    else
      Result := False;     // real error / closed
  end;
end;

procedure TWinPipeBackend.CloseBackend;
begin
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FHandle);
    FHandle := INVALID_HANDLE_VALUE;
  end;
end;

function TWinPipeBackend.IsOpen: Boolean;
begin
  Result := FHandle <> INVALID_HANDLE_VALUE;
end;
{$ENDIF}

{ ---------------- factory ---------------- }

function CreatePipeLink(const APipeName: string): ISocketLink;
begin
  {$IFDEF HAS_WINPIPE}
  Result := TNamedPipeLink.Create(TWinPipeBackend.Create, APipeName);
  {$ELSE}
  Result := nil;   // no pipe backend compiled in
  {$ENDIF}
end;

end.
