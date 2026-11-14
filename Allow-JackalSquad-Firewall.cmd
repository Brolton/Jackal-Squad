@echo off
setlocal
fltmc >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

if not exist "%~dp0JackalSquad.exe" (
  echo JackalSquad.exe was not found next to this helper.
  echo Put both files in the same folder and run this helper again.
  pause
  exit /b 1
)

netsh advfirewall firewall delete rule name="Jackal Squad LAN" >nul 2>&1
netsh advfirewall firewall add rule name="Jackal Squad LAN" dir=in action=allow program="%~dp0JackalSquad.exe" enable=yes profile=any protocol=UDP localport=24567,24568

if errorlevel 1 (
  echo Could not create the Windows Firewall rule.
  pause
  exit /b 1
)

echo Jackal Squad LAN access is enabled for UDP ports 24567 and 24568.
echo You can close this window and host the game again.
pause
