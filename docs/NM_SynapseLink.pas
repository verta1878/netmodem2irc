unit NM_SynapseLink;
{ ===========================================================================
  netmodem2irc — Synapse-backed socket link (NT-branch, real network)
  ---------------------------------------------------------------------------
  The REAL ISocketLink implementation, backed by Ararat Synapse's
  TTCPBlockSocket. This is what the docs specify (docs/BUILD.md,
  GUI_BLUEPRINT.md: "NetTransport.pas using Synapse TTCPBlockSocket").

  NetTransport talks only to the ISocketLink interface, so this unit is the
  ONE place that touches Synapse. Swap it for an lNet or raw-sockets link
  without changing any transport/AT/FOSSIL/UART logic.

  ---------------------------------------------------------------------------
  DEPENDENCY: Ararat Synapse (https://synapse.ararat.cz/). Permissively
  licensed (modified BSD) — compatible with this GPLv2 repo, so it MAY be
  bundled. See notes at end of file for the bundle-vs-reference decision.

  BUILD GUARD: this unit only pulls in Synapse when the symbol HAS_SYNAPSE is
  defined (-dHAS_SYNAPSE). Without it, the unit compiles to a stub that
  reports "not available", so the repo builds even where Synapse is absent.
  Define HAS_SYNAPSE (and add Synapse to the unit path) for a real build.

  VERIFICATION NOTE (honest): written against Synapse's long-stable
  TTCPBlockSocket API and compile-checked in stub form here. The Synapse-backed
  path must be runtime-tested on a real build with Synapse present + a live
  network — that step is not possible in the dependency-free dev environment.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, NetTransport
  {$IFDEF HAS_SYNAPSE}, blcksock, synsock{$ENDIF};

type
  TSynapseLink = class(TInterfacedObject, ISocketLink)
  private
    {$IFDEF HAS_SYNAPSE}
    FSock: TTCPBlockSocket;   // real Synapse socket
    {$ENDIF}
    FConnected: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Connect(const AHost: string; APort: Word): TLinkResult;
    function Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
    function Recv(var Buf; Len: Integer; out Got: Integer): TLinkResult;
    procedure Close;
    function IsConnected: Boolean;
  end;

{ Factory — returns a real Synapse link if built with -dHAS_SYNAPSE, else nil
  (so callers can detect "no socket backend available" cleanly). }
function CreateSocketLink: ISocketLink;

implementation

constructor TSynapseLink.Create;
begin
  inherited Create;
  FConnected := False;
  {$IFDEF HAS_SYNAPSE}
  FSock := TTCPBlockSocket.Create;
  FSock.RaiseExcept := False;        // report errors via LastError, don't raise
  {$ENDIF}
end;

destructor TSynapseLink.Destroy;
begin
  {$IFDEF HAS_SYNAPSE}
  if Assigned(FSock) then
  begin
    FSock.CloseSocket;
    FSock.Free;
  end;
  {$ENDIF}
  inherited Destroy;
end;

function TSynapseLink.Connect(const AHost: string; APort: Word): TLinkResult;
begin
  {$IFDEF HAS_SYNAPSE}
  FSock.Connect(AHost, IntToStr(APort));
  if FSock.LastError = 0 then
  begin
    FSock.NonBlockMode := True;      // transport pumps non-blocking
    FConnected := True;
    Result := lrOk;
  end
  else
  begin
    FConnected := False;
    Result := lrError;
  end;
  {$ELSE}
  { no Synapse in this build }
  Result := lrError;
  {$ENDIF}
end;

function TSynapseLink.Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
begin
  Sent := 0;
  {$IFDEF HAS_SYNAPSE}
  if not FConnected then Exit(lrClosed);
  FSock.SendBuffer(@Buf, Len);
  if FSock.LastError = 0 then
  begin
    Sent := Len;                     // Synapse SendBuffer sends all or errors
    Result := lrOk;
  end
  else if FSock.LastError = WSAEWOULDBLOCK then
    Result := lrWouldBlock
  else
  begin
    FConnected := False;
    Result := lrClosed;
  end;
  {$ELSE}
  Result := lrError;
  {$ENDIF}
end;

function TSynapseLink.Recv(var Buf; Len: Integer; out Got: Integer): TLinkResult;
begin
  Got := 0;
  {$IFDEF HAS_SYNAPSE}
  if not FConnected then Exit(lrClosed);
  { non-blocking read: wait 0ms, pull whatever is available }
  Got := FSock.RecvBufferEx(@Buf, Len, 0);
  case FSock.LastError of
    0:
      Result := lrOk;
    WSAETIMEDOUT, WSAEWOULDBLOCK:
      begin
        Got := 0;
        Result := lrWouldBlock;
      end;
  else
    begin
      FConnected := False;
      Result := lrClosed;
    end;
  end;
  {$ELSE}
  Result := lrError;
  {$ENDIF}
end;

procedure TSynapseLink.Close;
begin
  {$IFDEF HAS_SYNAPSE}
  if Assigned(FSock) then FSock.CloseSocket;
  {$ENDIF}
  FConnected := False;
end;

function TSynapseLink.IsConnected: Boolean;
begin
  Result := FConnected;
end;

function CreateSocketLink: ISocketLink;
begin
  {$IFDEF HAS_SYNAPSE}
  Result := TSynapseLink.Create;
  {$ELSE}
  Result := nil;   // no backend compiled in
  {$ENDIF}
end;

{ ===========================================================================
  BUNDLE-vs-REFERENCE decision for Synapse (for the repo maintainer)
  ---------------------------------------------------------------------------
  Synapse is permissively licensed (modified BSD) => compatible with GPLv2,
  so bundling is allowed (unlike Watt-32 in fpc264irc). Options:
    1. Reference: document "install Synapse, add to unit path, build with
       -dHAS_SYNAPSE". Cleanest; user fetches Synapse.
    2. Bundle: commit Synapse into e.g. server/synapse/ (or libs/synapse/).
       Self-contained (git clone + build works), license-OK, but a stale-copy
       maintenance burden.
    3. Git submodule: Synapse appears in-tree but points at upstream — stays
       current, one clone, no stale copy. Good middle path.
  Recommendation: submodule (3) or bundle (2) fits the project's
  "self-contained for the person who can't chase dependencies" value, now that
  license is not a blocker. Decide and document in BUILD.md.
  =========================================================================== }

end.
