@echo off
title Bitaxe Difficulty Tracker - Server
echo.
echo  ==========================================
echo   Bitaxe Difficulty Tracker - Starting...
echo   Keep this window open while using the app
echo  ==========================================
echo.

:: Check PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host ' PowerShell OK' -ForegroundColor Green"
if errorlevel 1 (
    echo  ERROR: Cannot run PowerShell.
    echo  Right-click this .bat and choose Run as Administrator
    pause
    exit /b 1
)

:: Register URL for network access
netsh http add urlacl url=http://+:19248/ user=Everyone >nul 2>&1

:: Add firewall rule so iPhone/Android can connect on local network
netsh advfirewall firewall delete rule name="Bitaxe Difficulty Tracker" >nul 2>&1
netsh advfirewall firewall add rule name="Bitaxe Difficulty Tracker" dir=in action=allow protocol=TCP localport=19248 >nul 2>&1

:: Open in default browser
start http://localhost:19248

:: Start server
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
exit
