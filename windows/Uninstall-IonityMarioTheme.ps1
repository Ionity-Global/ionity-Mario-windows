# =====================================================================
#  Ionity Mario Sound Theme — Uninstaller (full restore)
#  (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd
# =====================================================================
param(
    [switch]$KeepFiles,   # restore Windows sounds but keep companion/files
    [switch]$Quiet
)
$ErrorActionPreference = 'SilentlyContinue'
$SchemeId = 'IonityMario'
$Dest = Join-Path $env:LOCALAPPDATA 'Ionity\MarioSoundTheme'
$BackupFile = Join-Path $Dest 'backup.json'

Write-Host ''
Write-Host '  Restoring your original Windows sounds...' -ForegroundColor Yellow

# ------------------------------------------------- restore event sounds
$bk = $null
if (Test-Path $BackupFile) { $bk = Get-Content $BackupFile -Raw | ConvertFrom-Json }
if ($bk) {
    foreach ($p in $bk.events.PSObject.Properties) {
        $app,$ev = $p.Name -split '\|'
        $cur = "HKCU:\AppEvents\Schemes\Apps\$app\$ev\.Current"
        if (Test-Path $cur) { Set-Item -Path $cur -Value ([string]$p.Value) }
    }
    $prev = if ($bk.scheme) { [string]$bk.scheme } else { '.Default' }
    Set-Item -Path 'HKCU:\AppEvents\Schemes' -Value $prev
    Write-Host '  Original scheme restored from backup.' -ForegroundColor Green
} else {
    # no backup -> fall back to each event's .Default value
    $apps = Get-ChildItem 'HKCU:\AppEvents\Schemes\Apps'
    foreach ($app in $apps) {
        foreach ($ev in Get-ChildItem $app.PSPath) {
            $schemeSub = Join-Path $ev.PSPath $SchemeId
            if (Test-Path $schemeSub) {
                $def = (Get-ItemProperty (Join-Path $ev.PSPath '.Default')).'(default)'
                Set-Item -Path (Join-Path $ev.PSPath '.Current') -Value ([string]$def)
            }
        }
    }
    Set-Item -Path 'HKCU:\AppEvents\Schemes' -Value '.Default'
    Write-Host '  No backup found - reset to Windows defaults.' -ForegroundColor Yellow
}

# --------------------------------------------- remove scheme registration
Remove-Item "HKCU:\AppEvents\Schemes\Names\$SchemeId" -Recurse -Force
Get-ChildItem 'HKCU:\AppEvents\Schemes\Apps' | ForEach-Object {
    Get-ChildItem $_.PSPath | ForEach-Object {
        Remove-Item (Join-Path $_.PSPath $SchemeId) -Recurse -Force
    }
}

if (-not $KeepFiles) {
    # ------------------------------------------- stop companion + startup
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'IonityMarioCompanion'
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.CommandLine -match 'IonityMarioCompanion' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Start-Sleep -Milliseconds 600
    # ------------------------------------------------------- remove files
    if ((Get-Location).Path -like "$Dest*") { Set-Location $env:TEMP }
    if ($PSCommandPath -like "$Dest*") {
        # self-delete after exit
        Start-Process cmd.exe -WindowStyle Hidden -ArgumentList "/c timeout /t 2 /nobreak >nul & rd /s /q `"$Dest`""
    } else {
        Remove-Item $Dest -Recurse -Force
    }
    Write-Host '  Companion removed, files cleaned up.' -ForegroundColor Green
}

Write-Host ''
Write-Host '  Thanks for playing! - ionity.today' -ForegroundColor Cyan
Write-Host ''
