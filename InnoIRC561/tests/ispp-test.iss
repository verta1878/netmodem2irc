; InnoIRC561 ISPP test (byte, 2026-11-21) - every check stops the compile with #error if ISPP gets it wrong.
; Needs ISPP.dll + ISPPBuiltins.iss next to ISCC.exe (InnoIRC561/out). Run from this folder:
;   ISCC.exe ispp-test.iss            -> Mode "default", MinVersion 4.1,5.0
;   ISCC.exe /DMode=nt ispp-test.iss  -> Mode "nt",      MinVersion 5.0
; Both must end with "Successful compile". Output goes to tests\out (not kept).
#include "ispp-test-inc.iss"
#if IncValue != "from-include"
  #error #include failed
#endif
#ifndef Mode
  #define Mode "default"
#endif
#if Mode == "nt"
  #define MinV "5.0"
#else
  #define MinV "4.1,5.0"
#endif
#define Ver GetFileVersion(AddBackslash(SourcePath) + "..\out\Setup.e32")
#if Ver == ""
  #error GetFileVersion returned nothing for ..\out\Setup.e32
#endif
#define I
#define N 0
#sub CountIt
  #expr N = N + I
#endsub
#for {I = 1; I <= 3; I++} CountIt
#if N != 6
  #error #for/#sub loop: expected 6
#endif
[Setup]
AppName=ISPP test {#IncValue}
AppVersion={#Ver}
DefaultDirName={pf}\isppt
OutputDir=out
OutputBaseFilename=ispp-test-{#Mode}
MinVersion={#MinV}
[Files]
Source: "ispp-test-inc.iss"; DestDir: "{app}"
