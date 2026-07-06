# =====================================================================
#  Ionity Mario Companion — tray app
#   · On-screen Ionity watermark (bottom-right, click-through, toggleable)
#   · Mario soundboard
#   · 1-UP Pomodoro focus timer  (bonus feature)
#  (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd · ionity.today
# =====================================================================
$ErrorActionPreference = 'SilentlyContinue'

# ---- single instance -------------------------------------------------
$mutex = New-Object System.Threading.Mutex($false, 'Global\IonityMarioCompanion')
if (-not $mutex.WaitOne(0, $false)) { exit }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class IonWin32 {
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TRANSPARENT = 0x20;
    public const int WS_EX_TOOLWINDOW  = 0x80;
    public const int WS_EX_NOACTIVATE  = 0x8000000;
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public const uint SWP_NOMOVE = 0x2, SWP_NOSIZE = 0x1, SWP_NOACTIVATE = 0x10;
}
"@

$Base    = Split-Path -Parent $MyInvocation.MyCommand.Path
$SndDir  = Join-Path $Base 'sounds'
$LogoPng = Join-Path $Base 'ionity_logo.png'
$LogoIco = Join-Path $Base 'ionity_logo.ico'
$SettingsFile = Join-Path $Base 'settings.json'

# ---- settings ---------------------------------------------------------
$defaults = @{ watermark = $true; opacity = 55; width = 150; margin = 16 }
$settings = @{}
try { (Get-Content $SettingsFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $settings[$_.Name] = $_.Value } } catch {}
foreach ($k in $defaults.Keys) { if (-not $settings.ContainsKey($k)) { $settings[$k] = $defaults[$k] } }
function Save-Settings { $settings | ConvertTo-Json | Set-Content $SettingsFile -Encoding UTF8 }

function Play-Snd([string]$name) {
    $p = Join-Path $SndDir $name
    if (Test-Path $p) { (New-Object System.Media.SoundPlayer($p)).Play() }
}

# ---- watermark window -------------------------------------------------
$img = [System.Drawing.Image]::FromFile($LogoPng)
$w = [int]$settings.width
$h = [int]($w * $img.Height / $img.Width)

$wm = New-Object System.Windows.Forms.Form
$wm.FormBorderStyle = 'None'
$wm.ShowInTaskbar   = $false
$wm.StartPosition   = 'Manual'
$wm.TopMost         = $true
$wm.BackColor       = [System.Drawing.Color]::Magenta
$wm.TransparencyKey = [System.Drawing.Color]::Magenta
$wm.Opacity         = [double]$settings.opacity / 100
$wm.Size            = New-Object System.Drawing.Size($w, $h)

$pb = New-Object System.Windows.Forms.PictureBox
$pb.Image    = $img
$pb.SizeMode = 'Zoom'
$pb.Dock     = 'Fill'
$pb.BackColor = [System.Drawing.Color]::Magenta
$wm.Controls.Add($pb)

function Set-WmPosition {
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $m  = [int]$settings.margin
    $wm.Location = New-Object System.Drawing.Point(($wa.Right - $wm.Width - $m), ($wa.Bottom - $wm.Height - $m))
}
function Show-Wm {
    Set-WmPosition
    $wm.Show()
    # click-through + no-activate + hide from alt-tab
    $ex = [IonWin32]::GetWindowLong($wm.Handle, [IonWin32]::GWL_EXSTYLE)
    [IonWin32]::SetWindowLong($wm.Handle, [IonWin32]::GWL_EXSTYLE,
        ($ex -bor [IonWin32]::WS_EX_TRANSPARENT -bor [IonWin32]::WS_EX_TOOLWINDOW -bor [IonWin32]::WS_EX_NOACTIVATE)) | Out-Null
}

# ---- tray icon + menu ---------------------------------------------------
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = New-Object System.Drawing.Icon($LogoIco)
$tray.Text = 'Ionity Mario Companion'
$tray.Visible = $true
$menu = New-Object System.Windows.Forms.ContextMenuStrip

$miWm = New-Object System.Windows.Forms.ToolStripMenuItem 'Ionity watermark'
$miWm.CheckOnClick = $true
$miWm.Checked = [bool]$settings.watermark
$miWm.Add_Click({
    $settings.watermark = $miWm.Checked
    Save-Settings
    if ($miWm.Checked) { Show-Wm } else { $wm.Hide() }
    Play-Snd 'smb_coin.wav'
})
$menu.Items.Add($miWm) | Out-Null

# soundboard
$miSb = New-Object System.Windows.Forms.ToolStripMenuItem 'Soundboard'
Get-ChildItem $SndDir -Filter '*.wav' | Sort-Object Name | ForEach-Object {
    $nice = ((($_.BaseName -replace '^smb_','') -replace '[-_]',' ')).Trim()
    $nice = (Get-Culture).TextInfo.ToTitleCase($nice)
    $item = New-Object System.Windows.Forms.ToolStripMenuItem $nice
    $item.Tag = $_.Name
    $item.Add_Click({ Play-Snd $this.Tag })
    $miSb.DropDownItems.Add($item) | Out-Null
}
$menu.Items.Add($miSb) | Out-Null

# ---- 1-UP Pomodoro ------------------------------------------------------
$script:pomoEnd   = $null
$script:pomoMode  = ''      # 'focus' | 'break'
$script:pomoCount = 0

$miPomo   = New-Object System.Windows.Forms.ToolStripMenuItem '1-UP Pomodoro'
$miStatus = New-Object System.Windows.Forms.ToolStripMenuItem 'Idle - ready to play'
$miStatus.Enabled = $false
$mi25 = New-Object System.Windows.Forms.ToolStripMenuItem 'Start focus (25 min)'
$mi50 = New-Object System.Windows.Forms.ToolStripMenuItem 'Start focus (50 min)'
$miStop = New-Object System.Windows.Forms.ToolStripMenuItem 'Stop timer'
function Start-Focus([int]$mins) {
    $script:pomoMode = 'focus'
    $script:pomoEnd  = (Get-Date).AddMinutes($mins)
    Play-Snd 'smb_powerup.wav'
    $tray.ShowBalloonTip(3000, 'Focus level start!', "Here we go! $mins minutes - collect that coin.", 'Info')
}
$mi25.Add_Click({ Start-Focus 25 })
$mi50.Add_Click({ Start-Focus 50 })
$miStop.Add_Click({
    $script:pomoEnd = $null; $script:pomoMode = ''
    $miStatus.Text = 'Idle - ready to play'
    Play-Snd 'smb_pause.wav'
})
$miPomo.DropDownItems.AddRange(@($miStatus,
    (New-Object System.Windows.Forms.ToolStripSeparator), $mi25, $mi50, $miStop))
$menu.Items.Add($miPomo) | Out-Null

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

# restore / about / exit
$miRestore = New-Object System.Windows.Forms.ToolStripMenuItem 'Restore Windows sounds'
$miRestore.Add_Click({
    Start-Process powershell -WindowStyle Hidden -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -File `"$Base\Uninstall-IonityMarioTheme.ps1`" -KeepFiles -Quiet"
    $tray.ShowBalloonTip(3000, 'Ionity Mario', 'Original Windows sounds restored. Run INSTALL.bat to re-apply.', 'Info')
})
$menu.Items.Add($miRestore) | Out-Null

$miAbout = New-Object System.Windows.Forms.ToolStripMenuItem 'About Ionity - ionity.today'
$miAbout.Add_Click({ Start-Process 'https://www.ionity.today' })
$menu.Items.Add($miAbout) | Out-Null

$miExit = New-Object System.Windows.Forms.ToolStripMenuItem 'Exit companion'
$miExit.Add_Click({
    $tray.Visible = $false
    $wm.Close()
    [System.Windows.Forms.Application]::Exit()
})
$menu.Items.Add($miExit) | Out-Null
$tray.ContextMenuStrip = $menu
$tray.Add_DoubleClick({ $miWm.PerformClick() })

# ---- timers -------------------------------------------------------------
$tick = New-Object System.Windows.Forms.Timer
$tick.Interval = 1000
$tick.Add_Tick({
    if ($script:pomoEnd) {
        $left = $script:pomoEnd - (Get-Date)
        if ($left.TotalSeconds -le 0) {
            if ($script:pomoMode -eq 'focus') {
                $script:pomoCount++
                Play-Snd 'smb_stage_clear.wav'
                $msg = "Stage clear! Focus round $($script:pomoCount) done."
                if ($script:pomoCount % 4 -eq 0) {
                    $msg += ' 1-UP! Take a long break.'
                    Start-Sleep -Milliseconds 1800
                    Play-Snd 'smb_1-up.wav'
                }
                $tray.ShowBalloonTip(5000, '1-UP Pomodoro', "$msg Break: 5 min.", 'Info')
                $script:pomoMode = 'break'
                $script:pomoEnd  = (Get-Date).AddMinutes(5)
            } else {
                Play-Snd 'smb_vine.wav'
                $tray.ShowBalloonTip(4000, '1-UP Pomodoro', 'Break over - climb back in! Start next focus round from the tray.', 'Info')
                $script:pomoMode = ''; $script:pomoEnd = $null
                $miStatus.Text = 'Idle - ready to play'
            }
        } else {
            $miStatus.Text = ('{0} {1:mm\:ss} left' -f $script:pomoMode, $left)
        }
    }
})
$tick.Start()

$keepTop = New-Object System.Windows.Forms.Timer
$keepTop.Interval = 15000
$keepTop.Add_Tick({
    if ($wm.Visible) {
        Set-WmPosition
        [IonWin32]::SetWindowPos($wm.Handle, [IonWin32]::HWND_TOPMOST, 0,0,0,0,
            ([IonWin32]::SWP_NOMOVE -bor [IonWin32]::SWP_NOSIZE -bor [IonWin32]::SWP_NOACTIVATE)) | Out-Null
    }
})
$keepTop.Start()

# ---- run ------------------------------------------------------------------
if ([bool]$settings.watermark) { Show-Wm }
$ctx = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($ctx)
$mutex.ReleaseMutex()
