@echo off
title Ionity Mario Sound Theme - Installer
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-IonityMarioTheme.ps1"
echo.
pause
