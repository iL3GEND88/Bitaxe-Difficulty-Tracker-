@echo off
title Bitaxe Monitor - Server
echo.
echo  ==========================================
echo   Bitaxe Monitor - Starting...
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

:: Try to register URL for network access (allows iPhone access without Admin each time)
:: This only needs to work once - if it fails we fall back to localhost only
netsh http add urlacl url=http://+:19248/ user=Everyone >nul 2>&1

:: Open in default browser
start http://localhost:19248

:: Start server
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
exit
