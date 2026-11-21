@echo off
rem netmodem2irc: ispp1 - InnoIRC561 gets ISPP (the preprocessor); installer Win98 fixes; checksums - byte, 2026-11-21
rem Location: C:\Users\owner\Desktop\OneDrive\claude\memory\netmodem2irc-deliv\ispp1-run.bat
rem Zip:      C:\Users\owner\Desktop\OneDrive\claude\memory\netmodem2irc-deliv\ispp1\netmodem2irc-ispp1-2026-11-21.zip  (0.4 MB)
rem Repo:     C:\Users\owner\Desktop\OneDrive\claude\netmodem2irc
rem Run AFTER case1-run.bat (both parts committed): this bat checks that VERSION.INC has its new name.
rem 1 check the zip (MD5)   2 unzip into netmodem2irc, overwriting (19 files + 1 marker):
rem   NEW (4)   InnoIRC561\out\ISPP.dll ISPPBuiltins.iss; InnoIRC561\tests\ispp-test.iss ispp-test-inc.iss
rem   REPLACED (15) PROJ\ISPP: ISPP.dpr IsppFuncs.pas IsppIdentMan.pas IsppSessions.pas IsppTranslate.pas;
rem             installer\netmodem32.iss netfosdl.iss; InnoIRC561\README.md CHANGELOG.md INNOIRC561-FINDINGS.md
rem             INNO_FPC_PORT.md; CHANGELOG.md NETMODEM2IRC-INNO-AUDIT.md; MD5SUMS.txt SHA256SUMS.txt
rem   (netmodem32.iss at the repo root: you already moved it to attic\ - nothing to do here)
rem 3 check   4 remove marker InnoIRC561\ispp1.ok.  Deletes nothing else. No git commands.
setlocal
set "HERE=%~dp0"
set "REPO=%HERE%..\..\netmodem2irc"
set "Z1=%HERE%ispp1\netmodem2irc-ispp1-2026-11-21.zip"
set "LOG=%HERE%ispp1-run.log"
set "PROJ=InnoIRC561\src\issrc-is-5_6_1\Projects"
echo netmodem2irc ispp1 %DATE% %TIME% > "%LOG%"
if not exist "%REPO%\%PROJ%\ISPP\ISPP.dpr" (echo netmodem2irc folder not found & echo ABORT repo not found >> "%LOG%" & pause & exit /b 1)
if not exist "%Z1%" (echo Zip not found: %Z1% & echo ABORT zip not found >> "%LOG%" & pause & exit /b 1)
cd /d "%REPO%"
set "CASEOK=0"
for /f "delims=" %%N in ('dir /b "%PROJ%\VERSION.INC" 2^>nul') do if "%%N"=="VERSION.INC" set "CASEOK=1"
if not "%CASEOK%"=="1" (echo Run case1-run.bat first - VERSION.INC does not have its new name yet & echo ABORT case1 not done >> "%LOG%" & pause & exit /b 1)
echo CASE VERSION.INC ok (case1 done) >> "%LOG%"
echo [1/4] checking the zip
call :md5 "%Z1%" 6f4d9cd0ad5f2dcc21a5c8b93b53fd53 zip
if "%BADZIP%"=="1" (echo The zip is damaged - copy it again & pause & exit /b 1)
echo [2/4] unzipping into netmodem2irc
call :unzip "%Z1%"
if "%BADZIP%"=="1" (echo Unzip failed & pause & exit /b 1)
if not exist "InnoIRC561\ispp1.ok" (echo The zip did not land & echo ABORT marker missing >> "%LOG%" & pause & exit /b 1)
echo NEW 4 (out ISPP.dll ISPPBuiltins.iss, tests ispp-test.iss ispp-test-inc.iss); REPLACED 15 (ISPP source 5, installer 2, InnoIRC561 docs 4, CHANGELOG AUDIT, MD5SUMS SHA256SUMS) >> "%LOG%"
echo [3/4] checking
call :md5 "InnoIRC561\out\ISPP.dll" 2705fdd5f409ff6e7e2ced4d16362ea8 ISPP.dll
call :md5 "%PROJ%\ISPP\IsppTranslate.pas" 5a55e8dd398570db29d112ec0619d2ff IsppTranslate.pas
call :md5 "installer\netmodem32.iss" b2532f1716c04b1bea68ba2987e2f551 netmodem32.iss
call :md5 "MD5SUMS.txt" f02f6c98aeec25de4c0dfd885e52fc2d MD5SUMS.txt
echo [4/4] removing marker
if exist "InnoIRC561\ispp1.ok" del /f /q "InnoIRC561\ispp1.ok"
if not exist "InnoIRC561\ispp1.ok" echo DELETED InnoIRC561\ispp1.ok marker >> "%LOG%"
echo DONE >> "%LOG%"
echo.
echo Done. Log: %LOG%
echo Say "tail log".
pause
endlocal
exit /b 0

:md5
set "BADZIP=0"
set "GOT="
for /f "skip=1 delims=" %%H in ('certutil -hashfile "%~1" MD5 2^>nul') do if not defined GOT set "GOT=%%H"
if not defined GOT for /f "delims=" %%H in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm MD5 -LiteralPath '%~1').Hash" 2^>nul') do set "GOT=%%H"
if not defined GOT (echo CHECK %3 MD5 not checked - no certutil or powershell >> "%LOG%" & exit /b 0)
set "GOT=%GOT: =%"
if /i "%GOT%"=="%2" (echo CHECK %3 MD5 OK %2 >> "%LOG%") else (echo CHECK %3 MD5 BAD got %GOT% want %2 >> "%LOG%" & set "BADZIP=1")
exit /b 0

:unzip
where tar >nul 2>&1
if errorlevel 1 (powershell -NoProfile -Command "Expand-Archive -Force -LiteralPath '%~1' -DestinationPath '%REPO%'") else (tar -xf "%~1" -C "%REPO%")
if errorlevel 1 (echo ABORT unzip failed %~nx1 >> "%LOG%" & set "BADZIP=1" & exit /b 0)
echo UNZIPPED %~nx1 >> "%LOG%"
exit /b 0
