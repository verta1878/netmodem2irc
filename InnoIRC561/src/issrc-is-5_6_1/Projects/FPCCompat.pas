unit FPCCompat;
{ VCL -> LCL compatibility shim for Inno Setup FPC port }
{$MODE DELPHI}
interface

uses Windows, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls, LCLType;

const
  MB_TYPEMASK = $0000000F;
  ES_OEMCONVERT = $0400;
  SHCNF_PATH = $0001;

{ Missing VCL functions }
function DisableTaskWindows(ActiveWindow: HWND): Pointer;
procedure EnableTaskWindows(WindowList: Pointer);
function GetAppHandle: HWND;

{ TWMCopyData - VCL message record not in LCL }
type
  TWMCopyData = record
    Msg: Cardinal;
    From: WPARAM;
    CopyDataStruct: ^COPYDATASTRUCT;
    Result: LRESULT;
  end;

{ Ctl3D / ParentCtl3D / OEMConvert - VCL properties not in LCL }
procedure SetCtl3D(Control: TWinControl; Value: Boolean);
procedure SetParentCtl3D(Control: TWinControl; Value: Boolean);
procedure SetOEMConvert(Edit: TCustomEdit; Value: Boolean);

{ Application.HandleException wrapper }
procedure AppHandleException(Sender: TObject);

{ IAssemblyCache COM interface (LibFusion.pas) }
type
  IAssemblyCache = interface(IUnknown)
    ['{E707DCDE-D1CD-11D2-BAB9-00C04F8ECEAE}']
    function UninstallAssembly(dwFlags: DWORD; pszAssemblyName: LPCWSTR;
      pRefData: Pointer; pulDisposition: PDWORD): HRESULT; stdcall;
    function QueryAssemblyInfo(dwFlags: DWORD; pszAssemblyName: LPCWSTR;
      pAsmInfo: Pointer): HRESULT; stdcall;
    function CreateAssemblyCacheItem(dwFlags: DWORD; pvReserved: Pointer;
      out ppAsmItem: IUnknown; pszAssemblyName: LPCWSTR): HRESULT; stdcall;
    function CreateAssemblyScavenger(out ppAsmScavenger: IUnknown): HRESULT; stdcall;
    function InstallAssembly(dwFlags: DWORD; pszManifestFilePath: LPCWSTR;
      pRefData: Pointer): HRESULT; stdcall;
  end;

implementation

function DisableTaskWindows(ActiveWindow: HWND): Pointer;
begin Result := nil; end;

procedure EnableTaskWindows(WindowList: Pointer);
begin end;

function GetAppHandle: HWND;
begin
  if Assigned(Application) and Assigned(Application.MainForm) then
    Result := Application.MainForm.Handle
  else Result := 0;
end;

procedure SetCtl3D(Control: TWinControl; Value: Boolean);
begin
  { LCL handles 3D borders via BorderStyle - no separate Ctl3D property }
end;

procedure SetParentCtl3D(Control: TWinControl; Value: Boolean);
begin
  { no-op in LCL }
end;

procedure SetOEMConvert(Edit: TCustomEdit; Value: Boolean);
begin
  if Value and Edit.HandleAllocated then
    SetWindowLong(Edit.Handle, GWL_STYLE,
      GetWindowLong(Edit.Handle, GWL_STYLE) or ES_OEMCONVERT);
end;

procedure AppHandleException(Sender: TObject);
begin
  if Assigned(Application) then
    Application.HandleException(Sender);
end;

end.
