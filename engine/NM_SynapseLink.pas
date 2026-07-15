unit NM_SynapseLink;
{ ===========================================================================
  netmodem2irc — Synapse-backed socket link (NT-branch, real network)
  ---------------------------------------------------------------------------
  The REAL ISocketLink implementation, backed by Ararat Synapse's
  TTCPBlockSocket. NetTransport talks ONLY to the ISocketLink interface, so this
  unit is the ONE place that touches Synapse. Swap it for an lNet or raw-sockets
  link without changing any transport/AT/FOSSIL/UART logic.

  BUILD GUARD: this unit pulls in Synapse only when HAS_SYNAPSE is defined
  (-dHAS_SYNAPSE). Without it, the unit compiles to a stub that reports
  "not available", so the repo builds even where Synapse is absent.

  ---------------------------------------------------------------------------
  WHY THIS UNIT IS MORE THAN A PURE PASS-THROUGH (read before editing):

  A naive TCP link is a "thin delegation" — hand bytes to the OS, report the
  count. That is ALMOST right here, but TCP in NON-BLOCKING mode breaks the
  naive assumption in one specific, easy-to-miss way:

    * Connect() sets FSock.NonBlockMode := True (the transport pumps
      non-blocking so one slow node never stalls the others — the switch model).
    * In non-blocking mode, TTCPBlockSocket.SendBuffer can send FEWER bytes than
      asked when the kernel's socket send-buffer is full. This is a PARTIAL SEND
      — normal, expected TCP behaviour, not an error.

  The previous version did:  FSock.SendBuffer(@Buf, Len); Sent := Len;
  i.e. it ASSUMED every byte went out. Under load (a fast door dumping data into
  a congested socket) the kernel buffer fills, SendBuffer accepts only part, and
  the UNSENT TAIL WAS SILENTLY DROPPED. The caller was told "all Len sent", so it
  never retried — bytes vanished. This is the classic invisible network-boundary
  bug: nothing errors, throughput just quietly loses data.

  THE FIX (a small, bounded, per-socket TAIL BUFFER — NOT switch-like buffering):
    - Capture SendBuffer's ACTUAL byte count (it returns how many it took).
    - Any bytes it did NOT take are stashed in FSendTail.
    - Before the next Send (and on FlushTail), we push FSendTail out first,
      in order, so the byte stream stays intact and ordered.
    - This is "correctness buffering" for the TCP reality of partial sends. It is
      per-socket and bounded (a cap prevents unbounded growth if the peer stalls
      forever). It is NOT a routing/switch buffer — routing stays in the switch
      (TNodeManager). Two layers of buffering would re-create the old hub
      sluggishness; we deliberately keep switching OUT of the link.

  DEBUG INSTRUMENTATION (off by default):
    This unit is the NETWORK BOUNDARY — the least observable point in the system
    ("running is not seeing"): bytes disappear into a socket and you cannot watch
    them. So it carries optional counters/trace hooks (bytes in/out, connects,
    partial sends, errors) to make a live connection observable when diagnosing a
    slowdown or a lost byte. Guarded by NM_SOCKET_DEBUG so it is ZERO-COST when
    off — a debug facility that slowed the thing it debugs would be its own bug.
    A Lazarus window can later display these counters live; this is the
    instrumentation layer that feeds it (see the parked debug-milestone plan).

  VERIFICATION NOTE (honest): written against Synapse's long-stable
  TTCPBlockSocket API and compile-checked in stub form here. The Synapse-backed
  path (and specifically the partial-send tail buffer) MUST be runtime-tested on a
  real build with Synapse present + a live network under load — not possible in
  the dependency-free dev environment. The tail-buffer LOGIC is host-testable in
  isolation even without Synapse (QueueTail/FlushTail bounds + ordering).
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, NetTransport
  {$IFDEF HAS_SYNAPSE}, blcksock, synsock{$ENDIF};

const
  { Cap on the partial-send tail buffer. If a peer stalls so long that we would
    queue more than this many unsent bytes, we stop accepting new data (report
    back-pressure) rather than grow memory without bound. 64 KiB matches typical
    socket buffer sizes and the seam frame ceiling. }
  NM_SEND_TAIL_MAX = 65536;

type
  TSynapseLink = class(TInterfacedObject, ISocketLink)
  private
    {$IFDEF HAS_SYNAPSE}
    FSock: TTCPBlockSocket;   // real Synapse socket
    {$ENDIF}
    FConnected: Boolean;

    { PARTIAL-SEND TAIL BUFFER (see header). Holds bytes the kernel would not
      accept yet, so the next Send/FlushTail pushes them BEFORE new data. This
      preserves stream order and stops silent byte loss on a congested socket. }
    FSendTail: array of Byte;

    {$IFDEF NM_SOCKET_DEBUG}
    { Debug counters — compiled only when NM_SOCKET_DEBUG is defined, so they are
      truly zero-cost in a normal build. This is the instrumentation a debug
      window would display. }
    FDbgBytesIn  : Int64;    // total bytes successfully Recv'd
    FDbgBytesOut : Int64;    // total bytes actually put on the wire
    FDbgPartials : Int64;    // number of partial-send (tail-buffered) events
    FDbgConnects : Int64;    // successful Connect calls
    FDbgErrors   : Int64;    // hard errors that dropped the connection
    FDbgTailPeak : Integer;  // high-water mark of the tail buffer size
    {$ENDIF}

    { Push the buffered tail (if any) toward the socket. Returns True if the tail
      is now EMPTY (fully flushed), False if bytes remain (socket still congested
      or connection dropped). Preserves byte order; drops only what was accepted
      from the FRONT. }
    function FlushTail: Boolean;

    { Append bytes the socket did not accept to the tail buffer, honouring the
      cap. Returns how many bytes were actually queued (< Count if the cap was
      hit — the caller then knows to exert back-pressure). }
    function QueueTail(const Src; Count: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function Connect(const AHost: string; APort: Word): TLinkResult;
    function Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
    function Recv(var Buf; Len: Integer; out Got: Integer): TLinkResult;
    procedure Close;
    function IsConnected: Boolean;

    { Bytes currently waiting in the partial-send tail buffer. Exposed so the
      pump can tell whether a flush is still pending, and so tests can assert. }
    function PendingTail: Integer;

    {$IFDEF NM_SOCKET_TEST}
    { TEST-ONLY accessors (compiled with -dNM_SOCKET_TEST) to exercise the
      tail-buffer LOGIC without a live Synapse socket. TestTailQueue appends bytes
      (as a partial-send remainder would); TestTailDrainFront simulates the socket
      accepting N bytes on a later flush, dropping them from the front in order;
      TestTailByte reads a byte from the tail for order verification. }
    function TestTailQueue(const Src; Count: Integer): Integer;
    procedure TestTailDrainFront(N: Integer);
    function TestTailByte(Index: Integer): Byte;
    {$ENDIF}

    {$IFDEF NM_SOCKET_DEBUG}
    { One-line snapshot of the debug counters, for a log line or the future debug
      window. Present only in a NM_SOCKET_DEBUG build. }
    function DebugSnapshot: string;
    {$ENDIF}
  end;

{ Factory — returns a real Synapse link if built with -dHAS_SYNAPSE, else nil
  (so callers can detect "no socket backend available" cleanly). }
function CreateSocketLink: ISocketLink;

implementation

constructor TSynapseLink.Create;
begin
  inherited Create;
  FConnected := False;
  SetLength(FSendTail, 0);
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

function TSynapseLink.QueueTail(const Src; Count: Integer): Integer;
var
  room, base, i: Integer;
  p: PByte;
begin
  { Queue only up to the cap — beyond that we exert back-pressure instead of
    growing memory without bound. }
  room := NM_SEND_TAIL_MAX - Length(FSendTail);
  if room <= 0 then Exit(0);
  Result := Count;
  if Result > room then Result := room;
  base := Length(FSendTail);
  SetLength(FSendTail, base + Result);
  p := @Src;
  for i := 0 to Result - 1 do
    FSendTail[base + i] := p[i];
  {$IFDEF NM_SOCKET_DEBUG}
  if Length(FSendTail) > FDbgTailPeak then FDbgTailPeak := Length(FSendTail);
  {$ENDIF}
end;

function TSynapseLink.FlushTail: Boolean;
{$IFDEF HAS_SYNAPSE}
var
  n, keep, i: Integer;
{$ENDIF}
begin
  if Length(FSendTail) = 0 then Exit(True);   // nothing pending
  {$IFDEF HAS_SYNAPSE}
  if not FConnected then Exit(False);
  { Try to hand the whole tail to the socket. SendBuffer returns how many bytes
    it actually accepted (may be partial again on a still-congested socket). }
  n := FSock.SendBuffer(@FSendTail[0], Length(FSendTail));
  if FSock.LastError = WSAEWOULDBLOCK then
    n := 0                                     // took nothing this round
  else if FSock.LastError <> 0 then
  begin
    { hard error — the connection is gone; drop the tail with it }
    FConnected := False;
    SetLength(FSendTail, 0);
    Exit(False);
  end;
  if n <= 0 then Exit(False);                  // still congested, keep tail intact
  {$IFDEF NM_SOCKET_DEBUG}
  Inc(FDbgBytesOut, n);
  {$ENDIF}
  { Drop the n bytes we managed to send from the FRONT, keep the rest in order. }
  keep := Length(FSendTail) - n;
  if keep > 0 then
    for i := 0 to keep - 1 do
      FSendTail[i] := FSendTail[i + n];
  SetLength(FSendTail, keep);
  Result := (keep = 0);
  {$ELSE}
  Result := True;
  {$ENDIF}
end;

function TSynapseLink.Send(const Buf; Len: Integer; out Sent: Integer): TLinkResult;
{$IFDEF HAS_SYNAPSE}
var
  n, queued: Integer;
  p: PByte;
{$ENDIF}
begin
  Sent := 0;
  {$IFDEF HAS_SYNAPSE}
  if not FConnected then Exit(lrClosed);

  { STEP 1: flush any previously-buffered tail FIRST, so stream order is kept.
    If the tail can't fully flush, the socket is still congested — do NOT accept
    new bytes now; tell the caller to try later (back-pressure). }
  if not FlushTail then
    Exit(lrWouldBlock);

  if Len <= 0 then Exit(lrOk);

  { STEP 2: send the new data. SendBuffer RETURNS the actual count it accepted —
    which in non-blocking mode can be LESS than Len (a partial send). We must NOT
    assume all Len went out (that was the old bug that silently dropped bytes). }
  n := FSock.SendBuffer(@Buf, Len);

  if FSock.LastError = WSAEWOULDBLOCK then
  begin
    { socket full right now: queue the WHOLE request as tail and report it as
      accepted from the caller's view (we own it now and will flush it later). }
    queued := QueueTail(Buf, Len);
    Sent := queued;
    {$IFDEF NM_SOCKET_DEBUG}
    Inc(FDbgPartials);
    {$ENDIF}
    if queued < Len then Result := lrWouldBlock   // couldn't even fully queue
    else Result := lrOk;
    Exit;
  end
  else if FSock.LastError <> 0 then
  begin
    FConnected := False;
    {$IFDEF NM_SOCKET_DEBUG}
    Inc(FDbgErrors);
    {$ENDIF}
    Exit(lrClosed);
  end;

  { LastError = 0: n bytes went out. If n < Len, the remainder is a PARTIAL SEND
    — buffer the unsent tail so it is NOT lost. }
  {$IFDEF NM_SOCKET_DEBUG}
  Inc(FDbgBytesOut, n);
  {$ENDIF}
  if n < Len then
  begin
    p := @Buf;
    Inc(p, n);                                  // point past the bytes that left
    queued := QueueTail(p^, Len - n);
    Sent := n + queued;                         // caller sees sent + safely queued
    {$IFDEF NM_SOCKET_DEBUG}
    Inc(FDbgPartials);
    {$ENDIF}
    if queued < (Len - n) then Result := lrWouldBlock  // tail cap hit
    else Result := lrOk;
  end
  else
  begin
    Sent := n;                                  // all of it went out cleanly
    Result := lrOk;
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
      begin
        {$IFDEF NM_SOCKET_DEBUG}
        if Got > 0 then Inc(FDbgBytesIn, Got);
        {$ENDIF}
        Result := lrOk;
      end;
    WSAETIMEDOUT, WSAEWOULDBLOCK:
      begin
        Got := 0;
        Result := lrWouldBlock;
      end;
  else
    begin
      FConnected := False;
      {$IFDEF NM_SOCKET_DEBUG}
      Inc(FDbgErrors);
      {$ENDIF}
      Result := lrClosed;
    end;
  end;
  {$ELSE}
  Result := lrError;
  {$ENDIF}
end;

function TSynapseLink.Connect(const AHost: string; APort: Word): TLinkResult;
begin
  {$IFDEF HAS_SYNAPSE}
  FSock.Connect(AHost, IntToStr(APort));
  if FSock.LastError = 0 then
  begin
    FSock.NonBlockMode := True;      // transport pumps non-blocking (switch model)
    FConnected := True;
    SetLength(FSendTail, 0);         // fresh connection: no stale tail
    {$IFDEF NM_SOCKET_DEBUG}
    Inc(FDbgConnects);
    {$ENDIF}
    Result := lrOk;
  end
  else
  begin
    FConnected := False;
    {$IFDEF NM_SOCKET_DEBUG}
    Inc(FDbgErrors);
    {$ENDIF}
    Result := lrError;
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
  SetLength(FSendTail, 0);           // drop any pending tail on close
end;

function TSynapseLink.IsConnected: Boolean;
begin
  Result := FConnected;
end;

function TSynapseLink.PendingTail: Integer;
begin
  Result := Length(FSendTail);
end;

{$IFDEF NM_SOCKET_DEBUG}
function TSynapseLink.DebugSnapshot: string;
begin
  Result := Format(
    'sock in=%d out=%d partials=%d tailpeak=%d connects=%d errors=%d pending=%d',
    [FDbgBytesIn, FDbgBytesOut, FDbgPartials, FDbgTailPeak,
     FDbgConnects, FDbgErrors, Length(FSendTail)]);
end;
{$ENDIF}

{$IFDEF NM_SOCKET_TEST}
function TSynapseLink.TestTailQueue(const Src; Count: Integer): Integer;
begin
  Result := QueueTail(Src, Count);
end;

procedure TSynapseLink.TestTailDrainFront(N: Integer);
var keep, i: Integer;
begin
  if N <= 0 then Exit;
  if N > Length(FSendTail) then N := Length(FSendTail);
  keep := Length(FSendTail) - N;
  if keep > 0 then
    for i := 0 to keep - 1 do
      FSendTail[i] := FSendTail[i + N];
  SetLength(FSendTail, keep);
end;

function TSynapseLink.TestTailByte(Index: Integer): Byte;
begin
  if (Index >= 0) and (Index < Length(FSendTail)) then
    Result := FSendTail[Index]
  else
    Result := 0;
end;
{$ENDIF}

function CreateSocketLink: ISocketLink;
begin
  {$IFDEF HAS_SYNAPSE}
  Result := TSynapseLink.Create;
  {$ELSE}
  Result := nil;   // no backend compiled in
  {$ENDIF}
end;

end.
