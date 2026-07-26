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
  netmodem2irc - central debug logging
  ---------------------------------------------------------------------------
  One unit, used by everything. Controlled by -dNM_DEBUG at compile time.
  Without the define, every call compiles to nothing — zero overhead in
  release builds.

  Win32:  OutputDebugString -> readable with Sysinternals DebugView,
          no debugger needed. Win98 supports it natively.
          Also writes to a log file if DebugInitFile was called.

  DOS:    WriteLn to a log file or stderr. No OS debug API.

  Usage:
    uses NM_Debug;
    ...
    DebugLog('NMServer', 'FormCreate: driver handle = ' + IntToStr(h));
    DebugLog('FOSSIL',   'Fn $04 INIT on port ' + IntToStr(port));

  The first argument is the subsystem tag — keeps the log readable when
  multiple units are tracing at once. Convention:

    NMServer    server init and CM_* dispatch
    NMConfig    config GUI
    ISCmplr     DLL initialization
    FOSSIL      INT 14h dispatch
    UART        register reads/writes
    Transport   Telnet IAC, connect/disconnect
    Synapse     socket lifecycle, partial sends
    Seam        driver<->server protocol frames
    Bridge      CM_* -> engine wiring
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

{ All procedures exist whether NM_DEBUG is defined or not.
  Without it, the implementations are empty and the compiler
  eliminates them. }

procedure DebugLog(const Subsystem, Msg: string);
procedure DebugLogFmt(const Subsystem, Fmt: string; const Args: array of const);
procedure DebugInitFile(const Filename: string);
procedure DebugShutdown;

implementation

{$IFDEF NM_DEBUG}

uses
  SysUtils
  {$IFDEF WINDOWS}, Windows{$ENDIF};

var
  GLogFile: TextFile;
  GFileOpen: Boolean = False;
  GInitDone: Boolean = False;

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

  {$IFDEF WINDOWS}
  { OutputDebugString — goes to the kernel debug log.
    Readable with DebugView (Sysinternals) without attaching a
    debugger. This is critical for init-time crashes where a
    debugger changes timing and can mask the fault.
    Win98 supports OutputDebugStringA natively. }
  PLine := PChar(Line);
  OutputDebugStringA(PLine);
  {$ENDIF}

  { Also write to file if one was opened }
  if GFileOpen then
  begin
    WriteLn(GLogFile, Line);
    Flush(GLogFile);   { flush every line — we may crash before the next one }
  end;

  {$IFNDEF WINDOWS}
  { DOS / Linux: stderr is all we have if no file was opened }
  if not GFileOpen then
    WriteLn(StdErr, Line);
  {$ENDIF}
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
  GInitDone := False;
end;

{$ELSE}

{ NM_DEBUG not defined — everything compiles to nothing }

procedure DebugLog(const Subsystem, Msg: string); begin end;
procedure DebugLogFmt(const Subsystem, Fmt: string; const Args: array of const); begin end;
procedure DebugInitFile(const Filename: string); begin end;
procedure DebugShutdown; begin end;

{$ENDIF}

end.
