@echo off
rem netmodem2irc: case1 - 3 file names to the case the code uses (for Linux builds) - byte, 2026-11-21
rem Location: C:\Users\owner\Desktop\OneDrive\claude\memory\netmodem2irc-deliv\case1-run.bat   (no zip)
rem Repo:     C:\Users\owner\Desktop\OneDrive\claude\netmodem2irc
rem git on this PC ignores case (core.ignorecase=true), so a rename alone is invisible to GitHub Desktop.
rem Two commits instead:
rem   PART 1  MOVES out of the repo into netmodem2irc-deliv\case1-hold\ (kept there, not deleted):
rem             PROJ\Version.inc  PROJ\Int64em.pas  PROJ\ISPP\ISPP.res
rem           -> you commit in GitHub Desktop: "3 files deleted"
rem   PART 2  COPIES them back, same bytes, new names:
rem             PROJ\VERSION.INC  PROJ\Int64Em.pas  PROJ\ISPP\ISPP.RES
rem           -> you commit in GitHub Desktop: "3 files added"; then push. Then run ispp1-run.bat.
rem   PROJ = InnoIRC561\src\issrc-is-5_6_1\Projects.  Deletes nothing. No git commands.
setlocal
set "HERE=%~dp0"
set "REPO=%HERE%..\..\netmodem2irc"
set "HOLD=%HERE%case1-hold"
set "LOG=%HERE%case1-run.log"
set "PROJ=InnoIRC561\src\issrc-is-5_6_1\Projects"
echo netmodem2irc case1 %DATE% %TIME% >> "%LOG%"
if not exist "%REPO%\%PROJ%\ISPP\ISPP.dpr" (echo netmodem2irc folder not found & echo ABORT repo not found >> "%LOG%" & pause & exit /b 1)
cd /d "%REPO%\%PROJ%"
if exist "%HOLD%\Version.inc" goto part2
echo [1/2] PART 1: checking and moving the 3 files to %HOLD%
call :md5 "Version.inc" 9f536c1769447a02e592a2020e37b4b1 Version.inc
if "%BADZIP%"=="1" goto bad
call :md5 "Int64em.pas" feb9a381549e23917da49f602540bba8 Int64em.pas
if "%BADZIP%"=="1" goto bad
call :md5 "ISPP\ISPP.res" 18edc4cf2ffd516d7bc585a931faf11f ISPP.res
if "%BADZIP%"=="1" goto bad
if not exist "%HOLD%" mkdir "%HOLD%"
move "Version.inc" "%HOLD%\Version.inc" >nul && echo MOVED %PROJ%\Version.inc to case1-hold >> "%LOG%"
move "Int64em.pas" "%HOLD%\Int64em.pas" >nul && echo MOVED %PROJ%\Int64em.pas to case1-hold >> "%LOG%"
move "ISPP\ISPP.res" "%HOLD%\ISPP.res" >nul && echo MOVED %PROJ%\ISPP\ISPP.res to case1-hold >> "%LOG%"
if exist "Version.inc" goto bad
if exist "Int64em.pas" goto bad
if exist "ISPP\ISPP.res" goto bad
echo PART 1 DONE >> "%LOG%"
echo.
echo PART 1 done. Now in GitHub Desktop commit the 3 deleted files
echo   (summary e.g. "InnoIRC561: rename 3 files for case, step 1 of 2").
echo Then run this bat again for PART 2.
pause
exit /b 0

:part2
echo [2/2] PART 2: copying the 3 files back with the new names
if exist "Version.inc" (echo Version.inc is still in the repo - did PART 1 run? & echo ABORT part2 old name present >> "%LOG%" & pause & exit /b 1)
copy /b "%HOLD%\Version.inc" "VERSION.INC" >nul && echo COPIED case1-hold\Version.inc to %PROJ%\VERSION.INC >> "%LOG%"
copy /b "%HOLD%\Int64em.pas" "Int64Em.pas" >nul && echo COPIED case1-hold\Int64em.pas to %PROJ%\Int64Em.pas >> "%LOG%"
copy /b "%HOLD%\ISPP.res" "ISPP\ISPP.RES" >nul && echo COPIED case1-hold\ISPP.res to %PROJ%\ISPP\ISPP.RES >> "%LOG%"
call :md5 "VERSION.INC" 9f536c1769447a02e592a2020e37b4b1 VERSION.INC
call :md5 "Int64Em.pas" feb9a381549e23917da49f602540bba8 Int64Em.pas
call :md5 "ISPP\ISPP.RES" 18edc4cf2ffd516d7bc585a931faf11f ISPP.RES
rem the names as Windows stores them (dir /b shows the real case)
for %%F in (VERSION.INC Int64Em.pas) do for /f "delims=" %%N in ('dir /b "%%F"') do echo NAME %%N >> "%LOG%"
for /f "delims=" %%N in ('dir /b "ISPP\ISPP.RES"') do echo NAME ISPP\%%N >> "%LOG%"
echo PART 2 DONE >> "%LOG%"
echo DONE >> "%LOG%"
echo.
echo PART 2 done. In GitHub Desktop commit the 3 added files
echo   (e.g. "InnoIRC561: rename 3 files for case, step 2 of 2"), push, then say "tail log".
echo case1-hold keeps the old copies - attic it when you like.
pause
endlocal
exit /b 0

:bad
echo Something did not match - nothing more done. Log: %LOG%
echo ABORT >> "%LOG%"
pause
exit /b 1

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
