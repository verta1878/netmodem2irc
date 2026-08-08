{ ===========================================================================
  LCLDeferredInit — Deferred LCL initialization for DLLs
  GPLv3 — Copyright (C) 2026 wrench (netmodem2irc)

  Use this unit instead of 'Interfaces' in a DLL.
  Call InitLCL from an exported function AFTER DllMain returns.

  Usage:
    library MyDLL;
    uses LCLDeferredInit, Forms;

    procedure MyExportedFunction; stdcall;
    begin
      InitLCL;  // safe — we're outside DllMain
      Application.Initialize;
      // ... use LCL normally
    end;
  =========================================================================== }

{$MODE OBJFPC}{$H+}

unit LCLDeferredInit;

interface

procedure InitLCL;
function  LCLInitialized: Boolean;

implementation

uses
  InterfaceBase, LCLIntf;

var
  FInitialized: Boolean = False;

procedure InitLCL;
begin
  if FInitialized then Exit;
  if WidgetSet <> nil then begin FInitialized := True; Exit; end;

  { Create the widgetset — safe because we're outside DllMain }
  {$IFDEF LCLWin32}
  CreateWidgetset(TWin32WidgetSet);
  {$ENDIF}
  {$IFDEF LCLGtk2}
  CreateWidgetset(TGtk2WidgetSet);
  {$ENDIF}

  FInitialized := (WidgetSet <> nil);
end;

function LCLInitialized: Boolean;
begin
  Result := FInitialized;
end;

end.
