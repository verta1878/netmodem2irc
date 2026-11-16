{ compiletime ComObj support }
unit uPSC_comobj;

{$I PascalScript.inc}
interface
uses
  uPSCompiler, uPSUtils;

{
 
Will register:
 
function CreateOleObject(const ClassName: String): IDispatch;
function GetActiveOleObject(const ClassName: String): IDispatch;

}

procedure SIRegister_ComObj(cl: TPSPascalCompiler);

implementation

procedure SIRegister_ComObj(cl: TPSPascalCompiler);
begin
  cl.AddTypeS('HResult', 'LongInt');
  cl.AddTypeS('TGUID', 'record D1: LongWord; D2: Word; D3: Word; D4: array[0..7] of Byte; end;');
  cl.AddTypeS('TCLSID', 'TGUID');
  cl.AddTypeS('TIID', 'TGUID');
  cl.AddDelphiFunction('procedure OleCheck(Result: HResult);');
{$IFNDEF PS_NOINTERFACES}
{$IFDEF DELPHI3UP}
  cl.AddDelphiFunction('function StringToGUID(const S: string): TGUID;');
  cl.AddDelphiFunction('function CreateComObject(const ClassID: TGUID): IUnknown;');
{$ENDIF}
{$ENDIF}
{$IFNDEF PS_NOIDISPATCH}
  { InnoIRC BUG 8 (FPC): PascalScriptFPC.inc defines PS_NOIDISPATCH, so the compiler has no IDispatch type and
    these two registrations failed - every [Code] section stopped with an empty "Column 1:" error. Without
    IDispatch they are left out: scripts that call CreateOleObject / GetActiveOleObject do not compile. }
  cl.AddDelphiFunction('function CreateOleObject(const ClassName: String): IDispatch;');
  cl.AddDelphiFunction('function GetActiveOleObject(const ClassName: String): IDispatch;');
{$ENDIF}
end;

end.
