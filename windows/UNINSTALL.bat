@echo off
title Ionity Mario Sound Theme - Uninstaller
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\Ionity\MarioSoundTheme\Uninstall-IonityMarioTheme.ps1"
if errorlevel 1 powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-IonityMarioTheme.ps1"
echo.
pause
