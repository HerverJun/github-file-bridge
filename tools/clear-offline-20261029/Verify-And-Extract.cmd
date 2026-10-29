@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Verify-And-Extract.ps1" -ChooseDestination %*
set "CLEAR_EXTRACT_EXIT=%ERRORLEVEL%"
echo.
if not "%CLEAR_EXTRACT_EXIT%"=="0" echo Verification or extraction did not complete. Read the message above.
pause
exit /b %CLEAR_EXTRACT_EXIT%
