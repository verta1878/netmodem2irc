# Inno Setup 5.6.1 → FPC 2.6.4irc — Complete Patch List

Every change from the original Delphi source, organized by file.
Apply in order. All paths relative to `issrc-is-5_6_1/Projects/`
unless noted as `Components/`.

---

## New Files (create from scratch)

### VERSION.INC
```
{$DEFINE IS_D3}
{$DEFINE IS_D5}
{$DEFINE IS_D7}
{$DEFINE Delphi3orHigher}
{ NOT defining UNICODE — FPC 2.6.4 is ANSI-based }

{$DEFINE IS_D4}
```

### FPCCompat.pas
```pascal
unit FPCCompat;
{$MODE DELPHI}
interface
uses Windows, SysUtils, Classes, Forms, Messages;

type
  TWMCopyData = packed record
    Msg: Cardinal;
    From: HWND;
    CopyDataStruct: Pointer;
    Result: LongInt;
  end;

function GetAppHandle: HWND;
procedure AppHandleException(Sender: TObject);
procedure DisableTaskWindows(ActiveWindow: HWND);
procedure EnableTaskWindows(Wnd: HWND);

const
  SHCNF_PATH = $0005;

implementation
uses LCLType;

function GetAppHandle: HWND;
begin
  if Assigned(Application) and Assigned(Application.MainForm) then
    Result := Application.MainForm.Handle
  else
    Result := 0;
end;

procedure AppHandleException(Sender: TObject);
begin
  Application.HandleException(Sender);
end;

procedure DisableTaskWindows(ActiveWindow: HWND); begin end;
procedure EnableTaskWindows(Wnd: HWND); begin end;

end.
```

### Consts.pas
```pascal
unit Consts;
{$MODE DELPHI}
interface
resourcestring
  SMsgDlgWarning = 'Warning';
  SMsgDlgError = 'Error';
  SMsgDlgInformation = 'Information';
  SMsgDlgConfirm = 'Confirm';
  SInvalidInteger = '''%s'' is not a valid integer value';
implementation
end.
```

### SetupCompat.pas
```pascal
unit SetupCompat;
{$MODE DELPHI}
interface
uses Windows, SysUtils, Classes;
function ListContains(const List, Item: String): Boolean;
function ExpandSetupMessage(const Msg: String): String;
type
  TAlphaFormat = (afIgnored, afDefined, afPremultiplied);
  TAlphaBitmap = class
  public
    AlphaFormat: TAlphaFormat;
  end;
implementation
function ListContains(const List, Item: String): Boolean;
begin Result := Pos(Item, List) > 0; end;
function ExpandSetupMessage(const Msg: String): String;
begin Result := Msg; end;
end.
```

---

## Global: Add {$MODE DELPHI}

Every `.pas` file in both `Projects/` and `Components/` needs
`{$MODE DELPHI}` added after the `unit` line:

```
unit SomeUnit;
{$MODE DELPHI}    ← add this line
```

Files that already have `{$I VERSION.INC}` or `{$I PascalScript.inc}`
at the top get `{$MODE DELPHI}` set by the include file.

---

## Projects/ — File-by-File Patches

### ISCC.dpr
```diff
-{$R *.res}
-{$R ISCC.manifest.res}
+{ $R *.res}  { disabled for FPC }
+{ $R ISCC.manifest.res}  { disabled for FPC }
```

### Setup.dpr
```diff
-{$R *.RES}
+{$R Setup.res}
 {$IFDEF UNICODE}
-{$R SetupVersionUnicode.res}
+{$R SetupVersionUnicode.res}
 {$ELSE}
-{$R SetupVersion.res}
+{$R SetupVersion.res}
 {$ENDIF}
-{$R IMAGES.RES}
+{$R Images.res}
```

### SetupLdr.dpr
```diff
-{$R *.RES}
-{$R SetupLdrVersion.res}
-{$R SetupLdrOffsetTable.res}
+{$R SetupLdr.res}
+{$R SetupLdrVersion.res}
+{$R SetupLdrOffsetTable.res}
```

### Compil32.dpr
```diff
 uses
+  Interfaces,
   SafeDLLPath in 'SafeDLLPath.pas',
```
(Resources `{$R *.res}`, `{$R Compil32.manifest.res}`,
`{$R CompDocIcon.res}` stay enabled — they work.)

### CmnFunc.pas
```diff
 implementation uses
-  Windows, SysUtils, ...
+  Windows, SysUtils, FPCCompat, StdCtrls, ...

 { All occurrences: }
-  Application.Handle
+  GetAppHandle

-{$R *.DFM}
+{ $R *.DFM}
```

### CmnFunc2.pas
```diff
 interface uses
-  Windows, SysUtils, Classes;
+  Windows, SysUtils, Classes, ActiveX;

-  Res := GetEnvironmentVariable(PChar(EnvVar), ...
+  Res := Windows.GetEnvironmentVariable(PChar(EnvVar), ...
```

### BrowseFunc.pas
```diff
 implementation uses
+  FPCCompat, ...

-  Application.Handle
+  GetAppHandle
```

### SetupForm.pas
```diff
 uses
-  Windows, Messages, ...
+  Windows, Messages, LCLType, ...
```

### UIStateForm.pas
```diff
 uses
-  Forms, Controls;
+  Forms, Controls, LMessages;
```

### InstFnc2.pas
```diff
 implementation uses
+  ActiveX, ...
```

### Install.pas
```diff
 implementation uses
+  FPCCompat, ...

-  Application.Handle
+  GetAppHandle

-  CompareFileTime(a, b)
+  CompareFileTime(@a, @b)
```

### LibFusion.pas
```diff
-  Ole2
+  ActiveX

-  .Release
+  ._Release
```

### Undo.pas
```diff
+const
+  SHCNF_PATH = $0005;
```

### SpawnServer.pas
```diff
 implementation uses
+  FPCCompat, ...

-  ShellExecuteEx(
+  ShellExecuteExA(

-  Application.Handle
+  GetAppHandle
```

### Main.pas
```diff
 implementation uses
+  FPCCompat, LCLType, LMessages, LResources, ...

-  Application.Handle
+  GetAppHandle

-{$R *.DFM}
+{ $R *.DFM}

 initialization
+  {$I Main.lrs}
```

### Wizard.pas
```diff
 implementation uses
+  FPCCompat, LCLType, LResources, ...

-  Application.Handle
+  GetAppHandle

-{$R *.DFM}
+{ DFM replaced by LFM via lazres }

-  ParentBackground := False;
+  { ParentBackground := False; }

 initialization
+  {$I Wizard.lrs}
```

### NewDisk.pas
```diff
 implementation uses
+  LResources, ...

-{$R *.DFM}
+{ $R *.DFM}

+initialization
+  {$I NewDisk.lrs}
```

### SelFolderForm.pas
```diff
 implementation uses
+  LResources, ...

+initialization
+  {$I SelFolderForm.lrs}
```

### SelLangForm.pas
```diff
 implementation uses
+  LResources, ...

+initialization
+  {$I SelLangForm.lrs}
```

### UninstProgressForm.pas
```diff
 implementation uses
+  LResources, ...

+initialization
+  {$I UninstProgressForm.lrs}
```

### UninstSharedFileForm.pas
```diff
 implementation uses
+  LResources, ...

+initialization
+  {$I UninstSharedFileForm.lrs}
```

### D2009Win2kFix.pas
Replace entire file:
```pascal
unit D2009Win2kFix;
{$MODE DELPHI}
interface
implementation
end.
```

### Compile.pas
```diff
 implementation uses
-  ScriptCompiler, SimpleExpression, SetupTypes;
+  ScriptCompiler, SimpleExpression, SetupTypes, LCLStrConsts;
```

### CompForm.pas
```diff
 interface uses
+  FPCCompat, LCLType, ...

 implementation uses
+  LCLProc, LCLStrConsts, ...

-  Application.Handle
+  GetAppHandle

-{$R *.DFM}
+{ $R *.DFM}

-{$IFDEF IS_D5}
-    function IsShortCut(var Message: TWMKey): Boolean; override;
-{$ENDIF}
+{$IF DEFINED(IS_D5) AND NOT DEFINED(FPC)}
+    function IsShortCut(var Message: TWMKey): Boolean; override;
+{$IFEND}

 { Same guard on the implementation: }
-{$IFDEF IS_D5}
-function TCompileForm.IsShortCut ...
-{$ENDIF}
+{$IF DEFINED(IS_D5) AND NOT DEFINED(FPC)}
+function TCompileForm.IsShortCut ...
+{$IFEND}

-  ImageList_LoadBitmap(HInstance, 'BUILDIMAGES', 17, 0, clSilver);
+  ImageList_LoadImageA(GetModuleHandle(nil), 'BUILDIMAGES', 17, 0, clSilver, IMAGE_BITMAP, 0);

-  GetAppHandleMessage;
+  Application.HandleMessage;

-  ShellExecuteEx(@Info)
+  ShellExecuteExA(@Info)

-  CompareFileTime(FFileLastWriteTime, NewTime)
+  CompareFileTime(@FFileLastWriteTime, @NewTime)
```

### CompWizard.pas
```diff
-{$IFDEF IS_D7}
-  TNotebookAccess(Notebook1).ParentBackground := False;
-  PnlMain.ParentBackground := False;
-{$ENDIF}
+{$IF DEFINED(IS_D7) AND NOT DEFINED(FPC)}
+  TNotebookAccess(Notebook1).ParentBackground := False;
+  PnlMain.ParentBackground := False;
+{$IFEND}
```

### LZMADecomp.pas
```diff
-{$L Lzma2\Decoder\ISLzmaDec.obj}
-{$L Lzma2\Decoder\ISLzma2Dec.obj}
+{$L ISLzmaDec.o}
+{$L ISLzma2Dec.o}

 { All 6 external function declarations: add cdecl }
-function IS_LzmaDec_Init(...): TLZMASRes;
+function IS_LzmaDec_Init(...): TLZMASRes; cdecl; external;
 { (same for LzmaDec_DecodeToBuf, LzmaDec_Free,
    IS_Lzma2Dec_Init, Lzma2Dec_DecodeToBuf, IS_Lzma2Dec_Free) }

 { Additional symbols referenced by .o: add cdecl external }
+procedure LzmaDec_Allocate; cdecl; external;
+procedure LzmaDec_AllocateProbs; cdecl; external;
+procedure LzmaDec_DecodeToDic; cdecl; external;
+procedure LzmaDec_FreeProbs; cdecl; external;
+procedure LzmaDec_Init; cdecl; external;
+procedure LzmaDec_InitDicAndState; cdecl; external;
+procedure LzmaProps_Decode; cdecl; external;

 { memcpy alias for C runtime: }
-function _memcpy(dest, src: Pointer; n: Cardinal): Pointer; cdecl;
+function memcpy(dest, src: Pointer; n: Cardinal): Pointer;
+  cdecl; [public, alias: '_memcpy'];
```

### LZMADecompSmall.pas
```diff
-{$L LzmaDecode\LzmaDecodeInno.obj}
+{$L LzmaDecodeInno.o}

 { All 3 external function declarations: add cdecl }
-function LzmaMyDecodeProperties(...): Integer;
+function LzmaMyDecodeProperties(...): Integer; cdecl; external;
 { (same for LzmaMyDecoderInit, LzmaDecode) }
```

---

## Projects/ — PascalScript (Phase 7)

### Copy from fpc264irc

Copy all `.pas` and `.inc` files from
`fpc264irc/src/lazarus/components/PascalScript/Source/`
into `Projects/`:

```
uPSCompiler.pas (15,739 lines)
uPSRuntime.pas (12,669 lines)
uPSDebugger.pas (654 lines)
uPSUtils.pas (1,728 lines)
uPSC_*.pas (9 files)
uPSR_*.pas (9 files)
PascalScript.inc
PascalScriptFPC.inc
eDefines.inc
x86.inc
arm.inc
```

### uPSR_comobj.pas
```diff
 {$IFDEF DELPHI3UP}
-  ComObj;
+  ComObj, SysUtils;
```

### uPSR_dll.pas
Add to interface:
```pascal
function ProcessDllImportEx2(Caller: TPSExec; P: TPSExternalProcRec;
  ForceDelayLoad: Boolean; var DelayLoad: Boolean;
  var ErrorCode: Integer): Boolean;
```
Add implementation before `end.`:
```pascal
function ProcessDllImportEx2(Caller: TPSExec; P: TPSExternalProcRec;
  ForceDelayLoad: Boolean; var DelayLoad: Boolean;
  var ErrorCode: Integer): Boolean;
begin
  DelayLoad := ForceDelayLoad;
  ErrorCode := 0;
  Result := ProcessDllImportEx(Caller, P, ForceDelayLoad);
end;
```

### ScriptRunner.pas (restore original + fix)
Restore from original source. Add `{$MODE DELPHI}`. Fix:
```diff
-  RegisterDLLRuntimeEx(FPSExec, False);
+  RegisterDLLRuntimeEx(FPSExec, False, False);
```

### ScriptClasses_R.pas (restore original + fix)
Restore from original source. Add `{$MODE DELPHI}`. Fix:
```diff
-{$IFDEF IS_D7} T := TWinControlAccess(Self).ParentBackground {$ELSE} T := False {$ENDIF}
+{$IF DEFINED(IS_D7) AND NOT DEFINED(FPC)} T := TWinControlAccess(Self).ParentBackground {$ELSE} T := False {$IFEND}

-{$IFDEF IS_D7} TWinControlAccess(Self).ParentBackground := T; {$ENDIF}
+{$IF DEFINED(IS_D7) AND NOT DEFINED(FPC)} TWinControlAccess(Self).ParentBackground := T; {$IFEND}

-    RIRegisterTScrollingWinControl(Cl);
+    {$IFNDEF FPC}RIRegisterTScrollingWinControl(Cl);{$ENDIF}
```

### ScriptCompiler.pas, ScriptClasses_C.pas, ScriptDlg.pas, ScriptFunc.pas, ScriptFunc_C.pas, ScriptFunc_R.pas
Restore from original source. Add `{$MODE DELPHI}` to each.

---

## Components/ — File-by-File Patches

### ScintEdit.pas
```diff
 implementation uses
-{$IFDEF UNICODE}
-  RTLConsts;
-{$ELSE}
-  Consts;
-{$ENDIF}
+  RTLConsts;

-  Result := TScintIndicatorNumbers(Indic);
+  Move(Indic, Result, 1);

-  IndByte := Byte(Indicators) shl 5;
+  begin Move(Indicators, IndByte, 1); IndByte := IndByte shl 5; end;

-  DragQueryPoint(Message.Drop, P)
+  DragQueryPoint(Message.Drop, @P)
```

### DropListBox.pas
```diff
-    property ImeMode;
+    { property ImeMode; }
-    property ImeName;
+    { property ImeName; }
-    property TabWidth;
+    { property TabWidth; }
```

### All Components .pas
Add `{$MODE DELPHI}` after `unit` line.

---

## DFM → LFM Conversion (Phase 6)

For each installer form, convert the `.dfm.txt` to `.lfm`:
```bash
sed 's/\r//g' FormName.dfm.txt | \
  grep -v 'AutoScroll\|ParentBackground\|ExplicitWidth\|ExplicitHeight' \
  > FormName.lfm
```

Then generate `.lrs` with lazres:
```bash
lazres FormName.lrs FormName.lfm
```

Forms: Main, Wizard, NewDisk, SelFolderForm, SelLangForm,
UninstProgressForm, UninstSharedFileForm.

Each form's `.pas` needs `LResources` in uses and
`{$I FormName.lrs}` in the initialization section.

---

## Pre-compiled Object Files (Phase 4)

Copy these to `Projects/`:
```
ISLzmaDec.o      — from MinGW: i686-w64-mingw32-gcc -c -O2 -I../C ISLzmaDec.c
ISLzma2Dec.o     — from MinGW: i686-w64-mingw32-gcc -c -O2 -I../C ISLzma2Dec.c
LzmaDecodeInno.o — from MinGW: i686-w64-mingw32-gcc -c -O2 -D_LZMA_OUT_READ -D_LZMA_IN_CB LzmaDecodeInno.c
```
Pre-compiled copies in `installer/lzma/` in the repo.

---

## .res File LangID Patches

Borland-compiled `.res` files from Martijn Laan's Dutch system
have LangID `0x0413`. FPC's fpcres needs `0x0409` (or the BUG-032
LangID fallback fix). Affected files:

```
SetupLdr.res      — 4 occurrences of 0x0413
Compil32.res      — 9 occurrences
CompDocIcon.res   — 16 occurrences
```

Fix: rebuild fpcres with BUG-032 (LangID fallback in
`groupiconresource.pp`), OR binary-patch `\x13\x04` → `\x09\x04`.

`Setup.res` has `0x0409` (English) — no patch needed.

---

## Summary Count

| Category | Files | Changes |
|----------|-------|---------|
| New files created | 4 | FPCCompat, Consts, SetupCompat, VERSION.INC |
| {$MODE DELPHI} added | ~60 | All .pas in Projects/ and Components/ |
| {$R} resource directives | 5 | Setup, SetupLdr, ISCC, Compil32 .dpr files |
| Application.Handle → GetAppHandle | 8 | CmnFunc, BrowseFunc, Install, Main, Wizard, SpawnServer, CompForm + others |
| VCL→LCL uses clause changes | 15 | Adding FPCCompat, LCLType, LMessages, LResources, ActiveX, etc. |
| API binding fixes | 6 | ShellExecuteExA, CompareFileTime @, GetEnvironmentVariable, ImageList_LoadImageA, DragQueryPoint @P |
| ParentBackground guards | 3 | ScriptClasses_R, Wizard, CompWizard |
| IsShortCut guard | 1 | CompForm |
| PascalScript files copied | 22 | From fpc264irc PascalScript/Source/ |
| PascalScript fixes | 4 | uPSR_comobj, uPSR_dll, ScriptRunner, ScriptClasses_R |
| Script files restored | 8 | ScriptRunner, ScriptCompiler, ScriptClasses_C/R, ScriptDlg, ScriptFunc, ScriptFunc_C/R |
| LZMA .obj → .o | 2 | LZMADecomp, LZMADecompSmall |
| LZMA cdecl externals | 2 | LZMADecomp, LZMADecompSmall |
| DFM → LFM conversions | 7 | Main, Wizard, NewDisk, SelFolder, SelLang, UninstProgress, UninstShared |
| Component fixes | 2 | ScintEdit (4 fixes), DropListBox (3 properties) |
| Gutted files | 1 | D2009Win2kFix |
| LangID patches | 3 | SetupLdr.res, Compil32.res, CompDocIcon.res |
| **Total** | **~90 changes** | |
