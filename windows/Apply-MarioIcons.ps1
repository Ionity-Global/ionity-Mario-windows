# =====================================================================
#  Ionity Mario Icon Pack — apply (per-user, no admin needed)
#  Folders -> gold mushrooms · Drives -> stars · Recycle bin -> pipes
#  (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd · ionity.today
# =====================================================================
param([string]$IconDir = '')
$ErrorActionPreference = 'SilentlyContinue'

if (-not $IconDir) {
    $base = (Get-ItemProperty 'HKCU:\Software\Ionity\MarioSoundTheme' -ErrorAction SilentlyContinue).InstallDir
    if ($base) { $IconDir = Join-Path $base 'icons' }
}
if (-not (Test-Path (Join-Path $IconDir 'mushroom_folder.ico'))) {
    Write-Host "Icon pack not found at '$IconDir'"; exit 1
}
Write-Host "Applying Mario icons from $IconDir"

# --- folders (Shell Icons 3 = closed, 4 = open) ------------------------
$si = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'
New-Item -Path $si -Force | Out-Null
Set-ItemProperty -Path $si -Name '3' -Value (Join-Path $IconDir 'mushroom_folder.ico')
Set-ItemProperty -Path $si -Name '4' -Value (Join-Path $IconDir 'mushroom_folder_open.ico')

# --- recycle bin (per-user CLSID override) ------------------------------
$rb = 'HKCU:\Software\Classes\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\DefaultIcon'
New-Item -Path $rb -Force | Out-Null
Set-Item         -Path $rb -Value (Join-Path $IconDir 'pipe_bin_empty.ico')
Set-ItemProperty -Path $rb -Name 'Empty' -Value (Join-Path $IconDir 'pipe_bin_empty.ico')
Set-ItemProperty -Path $rb -Name 'Full'  -Value (Join-Path $IconDir 'pipe_bin_full.ico')

# --- drives -> star ------------------------------------------------------
Get-CimInstance Win32_LogicalDisk | Where-Object DriveType -in 2,3 | ForEach-Object {
    $L = $_.DeviceID.TrimEnd(':')
    $k = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\DriveIcons\$L\DefaultIcon"
    New-Item -Path $k -Force | Out-Null
    Set-Item -Path $k -Value (Join-Path $IconDir 'star_drive.ico')
}

# --- install folder -> ? block (desktop.ini) ------------------------------
$base = Split-Path -Parent $IconDir
$ini = Join-Path $base 'desktop.ini'
@("[.ShellClassInfo]", "IconResource=$(Join-Path $IconDir 'qblock.ico'),0") | Set-Content $ini -Encoding Unicode
attrib +s +h "$ini"
attrib +r "$base"

# --- refresh icon cache (no explorer kill - SHChangeNotify) -----------------
Add-Type -Namespace Ion -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern void SHChangeNotify(int eventId, int flags, IntPtr i1, IntPtr i2);'
[Ion.Shell]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)  # SHCNE_ASSOCCHANGED
ie4uinit.exe -show
# ensure explorer is alive (rescue), full restart only when explicitly asked
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
Write-Host 'Mario icons applied. If some folders still look default, sign out/in once. Its-a beautiful!'
