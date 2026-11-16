@echo off
rem netmodem2irc InnoIRC561: [Code] sections + OLE automation (bug 8), GetExceptionMessage (bug 9) - byte, 2026-11-15
rem Location: C:\Users\owner\Desktop\Claude\share\bbses\innofix2-run.bat
rem Zip:      C:\Users\owner\Desktop\Claude\share\bbses\innofix2\netmodem2irc-innofix2-2026-11-15.zip
rem 1 check the zip (MD5)   2 unzip into netmodem2irc, overwriting (8 replaced, nothing new):
rem   REPLACED InnoIRC561\src\issrc-is-5_6_1\Projects: PascalScriptFPC.inc uPSC_comobj.pas uPSRuntime.pas ScriptFunc_R.pas
rem            InnoIRC561\CHANGELOG.md INNOIRC561-FINDINGS.md, MD5SUMS.txt SHA256SUMS.txt (lines of the changed files only)
rem 3 check   4 remove marker.  Deletes nothing else. No git commands.
setlocal
set "HERE=%~dp0"
set "REPO=%HERE%netmodem2irc"
set "Z1=%HERE%innofix2\netmodem2irc-innofix2-2026-11-15.zip"
set "LOG=%HERE%innofix2-run.log"
echo netmodem2irc innofix2 %DATE% %TIME% > "%LOG%"
if not exist "%REPO%\InnoIRC561\src\issrc-is-5_6_1\Projects\uPSRuntime.pas" (echo netmodem2irc folder not found & echo ABORT repo not found >> "%LOG%" & pause & exit /b 1)
if not exist "%Z1%" (echo Zip not found: %Z1% & echo ABORT zip not found >> "%LOG%" & pause & exit /b 1)
cd /d "%REPO%"
echo [1/4] checking the zip
call :md5 "%Z1%" 21362710d91e895269db8ea0f6d7cf2f zip
if "%BADZIP%"=="1" (echo The zip is damaged - copy it again & pause & exit /b 1)
echo [2/4] unzipping into netmodem2irc
call :unzip "%Z1%"
if "%BADZIP%"=="1" (echo Unzip failed & pause & exit /b 1)
if not exist "InnoIRC561\innofix2.ok" (echo The zip did not land & echo ABORT marker missing >> "%LOG%" & pause & exit /b 1)
echo REPLACED Projects PascalScriptFPC.inc uPSC_comobj.pas uPSRuntime.pas ScriptFunc_R.pas, CHANGELOG.md INNOIRC561-FINDINGS.md, MD5SUMS.txt SHA256SUMS.txt >> "%LOG%"
echo [3/4] checking
call :md5 "InnoIRC561\src\issrc-is-5_6_1\Projects\uPSRuntime.pas" 217608da73b4e78bd151610b386c190d uPSRuntime.pas
call :md5 "InnoIRC561\INNOIRC561-FINDINGS.md" 4c9616ac281fe9e21a1dce7240c61f50 FINDINGS.md
call :md5 "MD5SUMS.txt" 306aff50f8c1d4652c54bf52c1ad941c MD5SUMS.txt
echo [4/4] removing marker
if exist "InnoIRC561\innofix2.ok" del /f /q "InnoIRC561\innofix2.ok"
if not exist "InnoIRC561\innofix2.ok" echo DELETED InnoIRC561\innofix2.ok marker >> "%LOG%"
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
