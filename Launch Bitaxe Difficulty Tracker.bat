@echo off
title Bitaxe Difficulty Tracker - Server

:: If called with --setup, we're running elevated for one-time setup
if "%1"=="--setup" goto :dosetup

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
    pause
    exit /b 1
)

:: Check if URL reservation already exists - only elevate if needed
netsh http show urlacl url=http://+:19248/ 2>nul | findstr "19248" >nul
if %errorlevel% neq 0 (
    echo  First run - requesting admin for one-time network setup...
    powershell -Command "Start-Process '%~f0' -ArgumentList '--setup' -Verb RunAs -Wait"
    echo  Setup complete.
) else (
    echo  Network setup already done - no admin needed.
)

:: Kill any existing process on port 19248
echo  Checking for existing server on port 19248...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :19248 ^| findstr LISTENING 2^>nul') do (
    echo  Killing existing process PID %%a...
    taskkill /PID %%a /F /T >nul 2>&1
)
timeout /t 2 /nobreak >nul

set OPENED=0
set FLAGS=--app=http://localhost:19248 --disable-background-timer-throttling --disable-backgrounding-occluded-windows --disable-renderer-backgrounding

:: Microsoft Edge
if %OPENED%==0 (
    if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
        start "" "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" %FLAGS%
        set OPENED=1
    ) else if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
        start "" "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" %FLAGS%
        set OPENED=1
    )
)

:: Google Chrome
if %OPENED%==0 (
    if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
        start "" "%ProgramFiles%\Google\Chrome\Application\chrome.exe" %FLAGS%
        set OPENED=1
    ) else if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
        start "" "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" %FLAGS%
        set OPENED=1
    )
)

:: Brave Browser
if %OPENED%==0 (
    if exist "%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe" (
        start "" "%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe" %FLAGS%
        set OPENED=1
    ) else if exist "%ProgramFiles(x86)%\BraveSoftware\Brave-Browser\Application\brave.exe" (
        start "" "%ProgramFiles(x86)%\BraveSoftware\Brave-Browser\Application\brave.exe" %FLAGS%
        set OPENED=1
    ) else if exist "%LocalAppData%\BraveSoftware\Brave-Browser\Application\brave.exe" (
        start "" "%LocalAppData%\BraveSoftware\Brave-Browser\Application\brave.exe" %FLAGS%
        set OPENED=1
    )
)

:: Opera
if %OPENED%==0 (
    if exist "%LocalAppData%\Programs\Opera\launcher.exe" (
        start "" "%LocalAppData%\Programs\Opera\launcher.exe" %FLAGS%
        set OPENED=1
    ) else if exist "%ProgramFiles%\Opera\launcher.exe" (
        start "" "%ProgramFiles%\Opera\launcher.exe" %FLAGS%
        set OPENED=1
    )
)

:: Opera GX
if %OPENED%==0 (
    if exist "%LocalAppData%\Programs\Opera GX\launcher.exe" (
        start "" "%LocalAppData%\Programs\Opera GX\launcher.exe" %FLAGS%
        set OPENED=1
    )
)

:: Fall back to default browser
if %OPENED%==0 (
    echo  Note: No Chromium browser found - opening in default browser
    echo  For best experience use Edge, Chrome, Brave, or Opera
    start http://localhost:19248
)

:: Start server
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
exit

:dosetup
:: Running elevated - do one-time network setup
netsh http add urlacl url=http://+:19248/ user=Everyone >nul 2>&1
netsh advfirewall firewall delete rule name="Bitaxe Difficulty Tracker" >nul 2>&1
netsh advfirewall firewall add rule name="Bitaxe Difficulty Tracker" dir=in action=allow protocol=TCP localport=19248 >nul 2>&1
exit /b 0
