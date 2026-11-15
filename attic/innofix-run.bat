@echo off
rem netmodem2irc InnoIRC561: Setup crash, silent exit, Win98 - byte, 2026-11-15 - ONE batch does it all
rem Location: C:\Users\owner\Desktop\Claude\share\bbses\innofix-run.bat
rem Zip:      C:\Users\owner\Desktop\Claude\share\bbses\innofix\netmodem2irc-innofix-2026-11-15.zip
rem 1 check the zip (MD5)   2 unzip into netmodem2irc, overwriting:
rem   REPLACED InnoIRC561\src\issrc-is-5_6_1\Projects: LZMADecomp.pas (bug 1), Main.pas (bugs 6 + 3), Compile.pas (bug 3)
rem            InnoIRC561\CHANGELOG.md README.md INNO_FPC_PORT.md, ROADMAP.md, docs\ROADMAP.md,
rem            MD5SUMS.txt SHA256SUMS.txt  (10 replaced)
rem   NEW      InnoIRC561\INNOIRC561-FINDINGS.md  (1 new)
rem 3 check   4 remove marker.  Deletes nothing else.
setlocal
set "HERE=%~dp0"
set "REPO=%HERE%netmodem2irc"
set "Z1=%HERE%innofix\netmodem2irc-innofix-2026-11-15.zip"
set "LOG=%HERE%innofix-run.log"
echo netmodem2irc innofix %DATE% %TIME% > "%LOG%"
if not exist "%REPO%\InnoIRC561\src\issrc-is-5_6_1\Projects\Main.pas" (echo netmodem2irc folder not found & echo ABORT repo not found >> "%LOG%" & pause & exit /b 1)
if not exist "%Z1%" (echo Zip not found: %Z1% & echo ABORT zip not found >> "%LOG%" & pause & exit /b 1)
cd /d "%REPO%"
echo [1/4] checking the zip
call :md5 "%Z1%" edb6b4332bb41ee26cde6f1add7a9b9c zip
if "%BADZIP%"=="1" (echo The zip is damaged - copy it again & pause & exit /b 1)
echo [2/4] unzipping into netmodem2irc
call :unzip "%Z1%"
if "%BADZIP%"=="1" (echo Unzip failed & pause & exit /b 1)
if not exist "InnoIRC561\innofix.ok" (echo The zip did not land & echo ABORT marker missing >> "%LOG%" & pause & exit /b 1)
echo REPLACED InnoIRC561 Projects LZMADecomp.pas Main.pas Compile.pas, InnoIRC561 CHANGELOG.md README.md INNO_FPC_PORT.md, ROADMAP.md docs\ROADMAP.md, MD5SUMS.txt SHA256SUMS.txt >> "%LOG%"
echo NEW InnoIRC561\INNOIRC561-FINDINGS.md >> "%LOG%"
echo [3/4] checking
call :md5 "InnoIRC561\src\issrc-is-5_6_1\Projects\Main.pas" bfacbee970679d283de9af2b0038d115 Main.pas
call :md5 "InnoIRC561\INNOIRC561-FINDINGS.md" 13d6674dd547324687fb857804a1d635 FINDINGS.md
call :md5 "MD5SUMS.txt" d7e9b2d53a20edcf4c59983e3c36c606 MD5SUMS.txt
echo [4/4] removing marker
if exist "InnoIRC561\innofix.ok" del /f /q "InnoIRC561\innofix.ok"
if not exist "InnoIRC561\innofix.ok" echo DELETED InnoIRC561\innofix.ok marker >> "%LOG%"
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
