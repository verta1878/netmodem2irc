{ ===========================================================================
  LCL Bug #7182 Fix — Patch for interfaces.pp (win32)
  
  Apply to: lazarus/lcl/interfaces/win32/interfaces.pp
  
  BEFORE:
    initialization
      CreateWidgetset(TWin32WidgetSet);
    finalization
      FreeWidgetset;
    end.

  AFTER:
    initialization
      if not IsLibrary then
        CreateWidgetset(TWin32WidgetSet);
    finalization
      if WidgetSet <> nil then
        FreeWidgetset;
    end.

  This prevents the widgetset from creating windows during
  DLL_PROCESS_ATTACH (inside the loader lock). Programs
  (IsLibrary = False) init normally. DLLs defer until
  Application.Initialize is called explicitly.

  For DLL developers who need the widgetset:
    procedure InitLCLIfNeeded;
    begin
      if WidgetSet = nil then
        CreateWidgetset(TWin32WidgetSet);
    end;
  Call this from an exported function, NOT from DllMain.
  =========================================================================== }
