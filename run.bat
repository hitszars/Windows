@echo off
SETLOCAL EnableExtensions
set "SCRIPT=%~dp0Reduce-FanNoise-AllInOne.ps1"

if not exist "%SCRIPT%" (
  echo ERROR: PowerShell script not found: %SCRIPT%
  pause
  exit /b 1
)

rem Prefer pwsh (PowerShell 7+) if available, else fallback to Windows PowerShell
for %%P in ("pwsh.exe","powershell.exe") do if not defined PS_EXE (
  where /q %%~P && set "PS_EXE=%%~P"
)

if not defined PS_EXE (
  echo ERROR: No PowerShell executable found in PATH.
  pause
  exit /b 1
)

echo Found PowerShell: %PS_EXE%
echo Running Reduce-FanNoise-AllInOne.ps1 as Administrator...

rem Build argument list safely
set "ARGS=-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT%\""

rem Start elevated PowerShell and wait for it to finish
powershell -NoProfile -Command ^
  "Start-Process -FilePath '%PS_EXE%' -ArgumentList '%ARGS%' -Verb RunAs -Wait"

if %ERRORLEVEL% EQU 0 (
  echo Script finished successfully.
) else (
  echo WARNING: Elevated process exited with code %ERRORLEVEL%.
)
echo Log files (if any) will be in "%TEMP%"
REM echo Log files (if any) will be in %%TEMP%%
pause
ENDLOCAL
