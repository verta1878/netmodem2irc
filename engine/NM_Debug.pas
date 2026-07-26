{ ===========================================================================
  netmodem2irc - part of the NetModem/32 revival
  Copyright (C) 2025-2026 Antonio Rico (Reapern66 / verta1878)

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.

  Dedrick Allen's original NetModem/32 material preserved in driver/src/,
  history/ and cpl/original_forms/ remains under GPLv2 - see LICENSES.md.
  =========================================================================== }

unit NM_Debug;
{ ===========================================================================
  netmodem2irc - central debug logging with Play/Stop
  ---------------------------------------------------------------------------
  Inspired by Carl Gorringe's RIPtermJS debug log panel:
    https://github.com/cgorringe/RIPtermJS

  One unit, used by everything. Controlled by -dNM_DEBUG at compile time.
  Without the define, every call compiles to nothing — zero overhead in
  release builds.

  Three output channels, all active simultaneously:

    1. OutputDebugString (Win32 only)
       Goes to the kernel debug log. Readable with Sysinternals DebugView
       without attaching a debugger. Win98 supports it natively. ALWAYS
       runs — never paused, never filtered. This is the crash-recovery
       channel: if the program dies, DebugView has the last line.

    2. Log file
       Opened by DebugInitFile. Flush after every line because we may
       crash before the next one. ALWAYS runs — never paused.

    3. Line handler callback (the debug panel)
       A GUI TMemo, a TListBox, a console printer — whatever the host
       registers via DebugSetLineHandler. This is the channel that
       Play/Stop controls. When paused, lines still go to channels
       1 and 2 but the handler is not called, so the visual panel
       freezes and you can scroll back to read what happened.

  Play/Stop (from RIPtermJS):
    DebugPause    — freeze the visual panel. Recording continues.
    DebugResume   — unfreeze. New lines start appearing again.
    DebugIsPaused — query state.

  Subsystem tags (first argument to DebugLog):
    NMServer    server init and CM_* dispatch
    NMConfig    config GUI
    ISCmplr     DLL initialization
    FOSSIL      INT 14h dispatch
    UART        register reads/writes
    Transport   Telnet IAC, connect/disconnect
    Synapse     socket lifecycle, partial sends
    Seam        driver<->server protocol frames
    Bridge      CM_* -> engine wiring
    DEBUG       the debug system itself

  The handler receives the subsystem and message separately so the GUI
  can color-code by subsystem — green for NMServer, cyan for FOSSIL,
  yellow for Transport, etc. — without parsing the formatted line.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

type
  { The callback type for the visual debug panel. The host form registers
    one of these via DebugSetLineHandler. It receives the raw subsystem
    tag and message, plus the pre-formatted line with timestamp.
    HAZARD: this is called from whatever thread DebugLog runs on. If the
    handler touches GUI controls, it must use TThread.Synchronize or
    Application.QueueAsyncCall, or the LCL will crash. }
  TDebugLineEvent = procedure(const Subsystem, Msg, FormattedLine: string) of object;

{ --- core logging --- }
procedure DebugLog(const Subsystem, Msg: string);
procedure DebugLogFmt(const Subsystem, Fmt: string; const Args: array of const);

{ --- lifecycle --- }
procedure DebugInitFile(const Filename: string);
procedure DebugShutdown;

{ --- Play/Stop (controls the line handler only) --- }
procedure DebugPause;
procedure DebugResume;
function  DebugIsPaused: Boolean;
function  DebugIsActive: Boolean;

{ --- visual panel hook --- }
procedure DebugSetLineHandler(Handler: TDebugLineEvent);

implementation

{$IFDEF NM_DEBUG}

uses
  SysUtils
  {$IFDEF WINDOWS}, Windows{$ENDIF};

var
  GLogFile   : TextFile;
  GFileOpen  : Boolean = False;
  GInitDone  : Boolean = False;
  GPaused    : Boolean = False;
  GHandler   : TDebugLineEvent = nil;

function Timestamp: string;
begin
  Result := FormatDateTime('hh:nn:ss.zzz', Now);
end;

procedure DebugLog(const Subsystem, Msg: string);
var
  Line: string;
{$IFDEF WINDOWS}
  PLine: PChar;
{$ENDIF}
begin
  Line := Timestamp + ' [' + Subsystem + '] ' + Msg;

  { Channel 1: OutputDebugString — ALWAYS fires, even when paused.
    This is the crash-recovery channel. If the program dies between
    this line and the file write, DebugView still has the output. }
  {$IFDEF WINDOWS}
  PLine := PChar(Line);
  OutputDebugStringA(PLine);
  {$ENDIF}

  { Channel 2: log file — ALWAYS fires, even when paused.
    Flush every line because we may crash before the next one. }
  if GFileOpen then
  begin
    WriteLn(GLogFile, Line);
    Flush(GLogFile);
  end;

  {$IFNDEF WINDOWS}
  { DOS / Linux: stderr if no file was opened }
  if not GFileOpen then
    WriteLn(StdErr, Line);
  {$ENDIF}

  { Channel 3: line handler (the visual debug panel).
    ONLY fires when NOT paused. This is the Play/Stop control point.
    When paused, channels 1 and 2 keep recording but the panel
    freezes so you can scroll back and read what happened. }
  if (not GPaused) and Assigned(GHandler) then
    GHandler(Subsystem, Msg, Line);
end;

procedure DebugLogFmt(const Subsystem, Fmt: string; const Args: array of const);
begin
  DebugLog(Subsystem, Format(Fmt, Args));
end;

procedure DebugInitFile(const Filename: string);
begin
  if GFileOpen then
    DebugShutdown;
  AssignFile(GLogFile, Filename);
  {$I-}
  if FileExists(Filename) then
    Append(GLogFile)
  else
    Rewrite(GLogFile);
  {$I+}
  GFileOpen := (IOResult = 0);
  GInitDone := True;
  if GFileOpen then
    DebugLog('DEBUG', '=== log opened: ' + Filename + ' ===')
  else
    {$IFDEF WINDOWS}
    OutputDebugStringA(PChar('NM_Debug: failed to open ' + Filename));
    {$ELSE}
    WriteLn(StdErr, 'NM_Debug: failed to open ', Filename);
    {$ENDIF}
end;

procedure DebugShutdown;
begin
  if GFileOpen then
  begin
    DebugLog('DEBUG', '=== log closed ===');
    CloseFile(GLogFile);
    GFileOpen := False;
  end;
  GHandler := nil;
  GPaused := False;
  GInitDone := False;
end;

procedure DebugPause;
begin
  if not GPaused then
  begin
    GPaused := True;
    DebugLog('DEBUG', '=== panel PAUSED (recording continues) ===');
  end;
end;

procedure DebugResume;
begin
  if GPaused then
  begin
    GPaused := False;
    DebugLog('DEBUG', '=== panel RESUMED ===');
  end;
end;

function DebugIsPaused: Boolean;
begin
  Result := GPaused;
end;

function DebugIsActive: Boolean;
begin
  Result := GInitDone;
end;

procedure DebugSetLineHandler(Handler: TDebugLineEvent);
begin
  GHandler := Handler;
  if Assigned(Handler) then
    DebugLog('DEBUG', 'line handler registered — visual panel active');
end;

{$ELSE}

{ NM_DEBUG not defined — everything compiles to nothing }

procedure DebugLog(const Subsystem, Msg: string); begin end;
procedure DebugLogFmt(const Subsystem, Fmt: string; const Args: array of const); begin end;
procedure DebugInitFile(const Filename: string); begin end;
procedure DebugShutdown; begin end;
procedure DebugPause; begin end;
procedure DebugResume; begin end;
function  DebugIsPaused: Boolean; begin Result := False; end;
function  DebugIsActive: Boolean; begin Result := False; end;
procedure DebugSetLineHandler(Handler: TDebugLineEvent); begin end;

{$ENDIF}

end.
