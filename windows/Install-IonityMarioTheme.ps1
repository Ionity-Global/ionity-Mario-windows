# =====================================================================
#  Ionity Mario Sound Theme — Windows Installer
#  (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - All rights reserved
#  https://www.ionity.today  ·  Policy AED 986 · License AED 900
#  Sounds (c) Nintendo - non-commercial fan sound-theme, personal use.
# =====================================================================
param(
    [switch]$NoCompanion,   # skip tray app / watermark
    [switch]$Quiet          # no pauses, no fanfare sound
)
$ErrorActionPreference = 'Stop'
$SchemeId   = 'IonityMario'
$SchemeName = 'Ionity Mario'
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptDir
$Dest       = Join-Path $env:LOCALAPPDATA 'Ionity\MarioSoundTheme'
$SndDir     = Join-Path $Dest 'sounds'

Write-Host ''
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host '   IONITY  x  SUPER MARIO  SOUND THEME  v1.0' -ForegroundColor Cyan
Write-Host '   Building Tomorrow, Today.  - ionity.today' -ForegroundColor DarkCyan
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host ''

# ---------------------------------------------------------------- files
Write-Host '  [1/5] Copying files...' -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $SndDir | Out-Null
if (Test-Path (Join-Path $RepoRoot 'sounds')) {   # skipped when re-run from install dir
    Copy-Item (Join-Path $RepoRoot 'sounds\*.wav') $SndDir -Force
    foreach ($f in 'ionity_logo.png','ionity_logo.ico') {
        Copy-Item (Join-Path $RepoRoot "assets\$f") $Dest -Force
    }
    foreach ($f in 'IonityMarioCompanion.ps1','StartCompanion.vbs','Uninstall-IonityMarioTheme.ps1','Install-IonityMarioTheme.ps1') {
        Copy-Item (Join-Path $ScriptDir $f) $Dest -Force
    }
}
# default settings (never overwrite user's)
$SettingsFile = Join-Path $Dest 'settings.json'
if (-not (Test-Path $SettingsFile)) {
    @{ watermark = $true; opacity = 55; width = 150; margin = 16 } |
        ConvertTo-Json | Set-Content $SettingsFile -Encoding UTF8
}

# ------------------------------------------------------------- mappings
#  "App|Event" -> wav file            (short sounds for frequent events)
$Map = [ordered]@{
    '.Default|.Default'             = 'smb_bump.wav'            # Default Beep
    '.Default|SystemAsterisk'       = 'smb_coin.wav'            # Info
    '.Default|SystemExclamation'    = 'smb_powerup_appears.wav' # Warning
    '.Default|SystemHand'           = 'smb_bowserfire.wav'      # Critical error
    '.Default|SystemNotification'   = 'smb_coin.wav'
    '.Default|Notification.Default' = 'smb_coin.wav'            # Toasts
    '.Default|Notification.Mail'    = 'smb_1-up.wav'
    '.Default|MailBeep'             = 'smb_1-up.wav'
    '.Default|Notification.SMS'     = 'smb_stomp.wav'
    '.Default|Notification.IM'      = 'smb_stomp.wav'
    '.Default|Notification.Reminder'= 'smb_vine.wav'
    '.Default|WindowsLogon'         = 'smb_powerup.wav'
    '.Default|WindowsLogoff'        = 'smb_pipe.wav'
    '.Default|WindowsUnlock'        = 'smb_coin.wav'
    '.Default|SystemExit'           = 'smb_gameover.wav'        # Shutdown :)
    '.Default|LowBatteryAlarm'      = 'smb_warning.wav'         # Hurry-up jingle
    '.Default|CriticalBatteryAlarm' = 'smb_mariodie.wav'
    '.Default|DeviceConnect'        = 'smb_powerup.wav'
    '.Default|DeviceDisconnect'     = 'smb_pipe.wav'
    '.Default|DeviceFail'           = 'smb_bump.wav'
    '.Default|Open'                 = 'smb_powerup_appears.wav'
    '.Default|Close'                = 'smb_kick.wav'
    '.Default|Minimize'             = 'smb_pipe.wav'            # Down the pipe
    '.Default|Maximize'             = 'smb_jump-super.wav'
    '.Default|RestoreUp'            = 'smb_jump-small.wav'
    '.Default|RestoreDown'          = 'smb_jump-small.wav'
    '.Default|AppGPFault'           = 'smb_bowserfalls.wav'     # App crash
    '.Default|PrintComplete'        = 'smb_flagpole.wav'
    'Explorer|Navigating'           = 'smb_kick.wav'
    'Explorer|EmptyRecycleBin'      = 'smb_breakblock.wav'
}

# ---------------------------------------------------------------- backup
Write-Host '  [2/5] Backing up current sound scheme...' -ForegroundColor Yellow
$BackupFile = Join-Path $Dest 'backup.json'
if (-not (Test-Path $BackupFile)) {
    $bk = @{ scheme = (Get-ItemProperty 'HKCU:\AppEvents\Schemes' -ErrorAction SilentlyContinue).'(default)'; events = @{} }
    foreach ($key in $Map.Keys) {
        $app,$ev = $key -split '\|'
        $cur = "HKCU:\AppEvents\Schemes\Apps\$app\$ev\.Current"
        $val = ''
        if (Test-Path $cur) { $val = (Get-ItemProperty $cur -ErrorAction SilentlyContinue).'(default)' }
        $bk.events[$key] = [string]$val
    }
    $bk | ConvertTo-Json -Depth 4 | Set-Content $BackupFile -Encoding UTF8
    Write-Host "        Backup saved -> $BackupFile" -ForegroundColor DarkGray
} else {
    Write-Host '        Existing backup kept (re-install).' -ForegroundColor DarkGray
}

# ------------------------------------------------------ register scheme
Write-Host '  [3/5] Registering "Ionity Mario" sound scheme...' -ForegroundColor Yellow
$namesKey = "HKCU:\AppEvents\Schemes\Names\$SchemeId"
New-Item -Path $namesKey -Force | Out-Null
Set-Item  -Path $namesKey -Value $SchemeName

foreach ($key in $Map.Keys) {
    $app,$ev = $key -split '\|'
    $wav = Join-Path $SndDir $Map[$key]
    $evKey = "HKCU:\AppEvents\Schemes\Apps\$app\$ev"
    foreach ($sub in @($SchemeId, '.Current')) {
        $k = "$evKey\$sub"
        New-Item -Path $k -Force | Out-Null
        Set-Item -Path $k -Value $wav
    }
}
Set-Item -Path 'HKCU:\AppEvents\Schemes' -Value $SchemeId
Write-Host "        $($Map.Count) system events now speak Mario." -ForegroundColor DarkGray

# --------------------------------------------------- companion + startup
if (-not $NoCompanion) {
    Write-Host '  [4/5] Installing Ionity Companion (watermark + tray)...' -ForegroundColor Yellow
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    Set-ItemProperty -Path $runKey -Name 'IonityMarioCompanion' `
        -Value "wscript.exe `"$Dest\StartCompanion.vbs`""
    Get-Process | Where-Object { $_.ProcessName -eq 'powershell' -and $_.MainWindowTitle -eq 'IonityMarioCompanion' } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Process wscript.exe -ArgumentList "`"$Dest\StartCompanion.vbs`""
    Write-Host '        Tray app started - Ionity watermark bottom-right (toggle in tray).' -ForegroundColor DarkGray
} else {
    Write-Host '  [4/5] Companion skipped (-NoCompanion).' -ForegroundColor DarkGray
}

# ----------------------------------------------------------------- done
Write-Host '  [5/5] Done!' -ForegroundColor Green
Write-Host ''
Write-Host '   Its-a me, your PC!  Coin = notification, Pipe = minimize,' -ForegroundColor Cyan
Write-Host '   Game Over = shutdown. Uninstall: UNINSTALL.bat (full restore).' -ForegroundColor Cyan
Write-Host ''
if (-not $Quiet) {
    try { (New-Object System.Media.SoundPlayer(Join-Path $SndDir 'smb_powerup.wav')).PlaySync() } catch {}
}
