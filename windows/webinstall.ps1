# =====================================================================
#  Ionity Mario Sound Theme — one-liner web installer (no browser, no
#  SmartScreen). Run in PowerShell:
#
#    irm https://raw.githubusercontent.com/Ionity-Global/ionity-Mario-windows/main/windows/webinstall.ps1 | iex
#
#  (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd · ionity.today
# =====================================================================
$ErrorActionPreference = 'Stop'
Write-Host ''
Write-Host '  IONITY x SUPER MARIO SOUND THEME - web install' -ForegroundColor Cyan
$t = Join-Path $env:TEMP 'IonityMarioGet'
Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $t -Force | Out-Null
$zip = Join-Path $t 'theme.zip'
Write-Host '  downloading latest theme...' -ForegroundColor Yellow
Invoke-WebRequest 'https://github.com/Ionity-Global/ionity-Mario-windows/archive/refs/heads/main.zip' -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $t -Force
$root = Get-ChildItem $t -Directory | Where-Object Name -match 'ionity-Mario-windows' | Select-Object -First 1
& (Join-Path $root.FullName 'windows\Install-IonityMarioTheme.ps1')
