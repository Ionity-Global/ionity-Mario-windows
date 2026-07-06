# =====================================================================
#  Ionity Mario Companion v2 — tray app
#   · Watermark: per-pixel alpha (no color fringe), Ionity logo +
#     live SAST (UTC+2) clock + "AED 986" + OS user, bottom-right
#   · Mario soundboard · Mario desktop icons toggle
#   · 1-UP Pomodoro focus timer
#  (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd · ionity.today
# =====================================================================
$ErrorActionPreference = 'SilentlyContinue'

$mutex = New-Object System.Threading.Mutex($false, 'Global\IonityMarioCompanion')
if (-not $mutex.WaitOne(0, $false)) { exit }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
public static class IonWin32 {
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int max);
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_LAYERED     = 0x80000;
    public const int WS_EX_TRANSPARENT = 0x20;
    public const int WS_EX_TOOLWINDOW  = 0x80;
    public const int WS_EX_NOACTIVATE  = 0x8000000;
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public const uint SWP_NOMOVE = 0x2, SWP_NOSIZE = 0x1, SWP_NOACTIVATE = 0x10;

    [StructLayout(LayoutKind.Sequential)] struct PT { public int x, y; public PT(int a, int b){x=a;y=b;} }
    [StructLayout(LayoutKind.Sequential)] struct SZ { public int cx, cy; public SZ(int a, int b){cx=a;cy=b;} }
    [StructLayout(LayoutKind.Sequential)] struct BF { public byte op, flags, alpha, fmt; }
    [DllImport("user32.dll")] static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr dst, ref PT pDst, ref SZ size, IntPtr src, ref PT pSrc, int key, ref BF blend, int flags);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll")]  static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")]  static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")]  static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
    [DllImport("gdi32.dll")]  static extern bool DeleteObject(IntPtr o);

    public static void Paint(IntPtr hwnd, Bitmap bmp, int x, int y, byte opacity) {
        IntPtr scr = GetDC(IntPtr.Zero);
        IntPtr mem = CreateCompatibleDC(scr);
        IntPtr hbm = bmp.GetHbitmap(Color.FromArgb(0));
        IntPtr old = SelectObject(mem, hbm);
        PT dst = new PT(x, y); SZ sz = new SZ(bmp.Width, bmp.Height); PT src = new PT(0, 0);
        BF bf = new BF(); bf.op = 0; bf.flags = 0; bf.alpha = opacity; bf.fmt = 1;  // AC_SRC_ALPHA
        UpdateLayeredWindow(hwnd, scr, ref dst, ref sz, mem, ref src, 0, ref bf, 2); // ULW_ALPHA
        SelectObject(mem, old); DeleteObject(hbm); DeleteDC(mem); ReleaseDC(IntPtr.Zero, scr);
    }
}
"@

$Base    = Split-Path -Parent $MyInvocation.MyCommand.Path
$SndDir  = Join-Path $Base 'sounds'
$LogoIco = Join-Path $Base 'ionity_logo.ico'
$WmPng   = Join-Path $Base 'ionity_watermark.png'
if (-not (Test-Path $WmPng)) { $WmPng = Join-Path $Base 'ionity_logo.png' }
$SettingsFile = Join-Path $Base 'settings.json'

# ---- settings ---------------------------------------------------------
$defaults = @{ watermark = $true; opacity = 78; width = 200; margin = 16; icons = $true; quiet = $true }
$settings = @{}
try { (Get-Content $SettingsFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $settings[$_.Name] = $_.Value } } catch {}
foreach ($k in $defaults.Keys) { if (-not $settings.ContainsKey($k)) { $settings[$k] = $defaults[$k] } }
function Save-Settings { $settings | ConvertTo-Json | Set-Content $SettingsFile -Encoding UTF8 }

function Play-Snd([string]$name) {
    if ($script:quietNow) { return }   # smart quiet: fullscreen app in front
    $p = Join-Path $SndDir $name
    if (Test-Path $p) { (New-Object System.Media.SoundPlayer($p)).Play() }
}

# ---- watermark (per-pixel alpha layered window) ------------------------
$logoImg = [System.Drawing.Image]::FromStream([System.IO.MemoryStream][System.IO.File]::ReadAllBytes($WmPng))  # no file lock
$W  = [int]$settings.width
$LH = [int]($W * $logoImg.Height / $logoImg.Width)
$H  = $LH + 64   # clock + AED line + focus counter line
$UserName = $env:USERNAME

# ---- smart quiet mode: fullscreen app detection -------------------------
function Test-Fullscreen {
    $h = [IonWin32]::GetForegroundWindow()
    if ($h -eq [IntPtr]::Zero -or $h -eq $wm.Handle) { return $false }
    $sb = New-Object System.Text.StringBuilder(64)
    [IonWin32]::GetClassName($h, $sb, 64) | Out-Null
    if ($sb.ToString() -in @('Progman','WorkerW','Shell_TrayWnd')) { return $false }  # desktop/taskbar
    $r = New-Object IonWin32+RECT
    [IonWin32]::GetWindowRect($h, [ref]$r) | Out-Null
    $s = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    return ($r.L -le $s.Left -and $r.T -le $s.Top -and $r.R -ge $s.Right -and $r.B -ge $s.Bottom)
}
$script:quietNow = $false

$wm = New-Object System.Windows.Forms.Form
$wm.FormBorderStyle = 'None'
$wm.ShowInTaskbar   = $false
$wm.StartPosition   = 'Manual'
$wm.TopMost         = $true
$wm.Size            = New-Object System.Drawing.Size($W, $H)

$fntClock = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)
$fntSmall = New-Object System.Drawing.Font('Segoe UI', 7.2)
$fntPomo  = New-Object System.Drawing.Font('Segoe UI', 11.5, [System.Drawing.FontStyle]::Bold)
$brGold   = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,193,7))
$brCyan   = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0,198,255))
$brWhite  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 234, 246, 255))
$brShadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(160, 0, 0, 0))
$sfMid = New-Object System.Drawing.StringFormat
$sfMid.Alignment = 'Center'

function Get-WmPos {
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $m  = [int]$settings.margin
    @(($wa.Right - $W - $m), ($wa.Bottom - $H - $m))
}

function Render-Wm {
    $bmp = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.DrawImage($logoImg, 0, 0, $W, $LH)
    $sast = (Get-Date).ToUniversalTime().AddHours(2)
    $t1 = $sast.ToString('HH:mm:ss') + ' SAST (UTC+2)'
    $t2 = 'AED 986  '+[char]0xB7+'  ' + $sast.ToString('yyyy-MM-dd') + '  '+[char]0xB7+'  ' + $UserName
    $cx = $W / 2
    $g.DrawString($t1, $fntClock, $brShadow, $cx + 1, $LH + 1, $sfMid)
    $g.DrawString($t1, $fntClock, $brCyan,   $cx,     $LH,     $sfMid)
    $g.DrawString($t2, $fntSmall, $brShadow, $cx + 1, $LH + 21, $sfMid)
    $g.DrawString($t2, $fntSmall, $brWhite,  $cx,     $LH + 20, $sfMid)
    # visible 1-UP Pomodoro counter
    if ($script:pomoEnd) {
        $left = $script:pomoEnd - (Get-Date)
        if ($left.TotalSeconds -gt 0) {
            $lbl = if ($script:pomoMode -eq 'focus') { [char]0x2605 + ' FOCUS ' } else { [char]0x2615 + ' BREAK ' }
            $t3 = $lbl + $left.ToString('mm\:ss')
            $g.DrawString($t3, $fntPomo, $brShadow, $cx + 1, $LH + 37, $sfMid)
            $g.DrawString($t3, $fntPomo, $brGold,   $cx,     $LH + 36, $sfMid)
        }
    }
    $g.Dispose()
    $bmp
}

function Update-Wm {
    if (-not $wm.Visible) { return }
    $pos = Get-WmPos
    $bmp = Render-Wm
    [IonWin32]::Paint($wm.Handle, $bmp, $pos[0], $pos[1], [byte]([int]$settings.opacity * 255 / 100))
    $bmp.Dispose()
}

function Show-Wm {
    $pos = Get-WmPos
    $wm.Location = New-Object System.Drawing.Point($pos[0], $pos[1])
    $wm.Show()
    $ex = [IonWin32]::GetWindowLong($wm.Handle, [IonWin32]::GWL_EXSTYLE)
    [IonWin32]::SetWindowLong($wm.Handle, [IonWin32]::GWL_EXSTYLE,
        ($ex -bor [IonWin32]::WS_EX_LAYERED -bor [IonWin32]::WS_EX_TRANSPARENT -bor
         [IonWin32]::WS_EX_TOOLWINDOW -bor [IonWin32]::WS_EX_NOACTIVATE)) | Out-Null
    Update-Wm
}

# ---- tray icon + menu ----------------------------------------------------
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = New-Object System.Drawing.Icon($LogoIco)
$tray.Text = 'Ionity Mario Companion'
$tray.Visible = $true
$menu = New-Object System.Windows.Forms.ContextMenuStrip

$miWm = New-Object System.Windows.Forms.ToolStripMenuItem 'Ionity watermark + clock'
$miWm.CheckOnClick = $true
$miWm.Checked = [bool]$settings.watermark
$miWm.Add_Click({
    $settings.watermark = $miWm.Checked
    Save-Settings
    if ($miWm.Checked) { Show-Wm } else { $wm.Hide() }
    Play-Snd 'smb_coin.wav'
})
$menu.Items.Add($miWm) | Out-Null

$miIco = New-Object System.Windows.Forms.ToolStripMenuItem 'Mario desktop icons'
$miIco.CheckOnClick = $true
$miIco.Checked = [bool]$settings.icons
$miIco.Add_Click({
    $settings.icons = $miIco.Checked
    Save-Settings
    $scr = if ($miIco.Checked) { 'Apply-MarioIcons.ps1' } else { 'Remove-MarioIcons.ps1' }
    Start-Process powershell -WindowStyle Hidden -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -File `"$Base\$scr`""
    Play-Snd 'smb_powerup.wav'
})
$menu.Items.Add($miIco) | Out-Null

$miQuiet = New-Object System.Windows.Forms.ToolStripMenuItem 'Smart quiet mode (fullscreen apps)'
$miQuiet.CheckOnClick = $true
$miQuiet.Checked = [bool]$settings.quiet
$miQuiet.Add_Click({
    $settings.quiet = $miQuiet.Checked
    Save-Settings
})
$menu.Items.Add($miQuiet) | Out-Null

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

# ---- 1-UP Pomodoro --------------------------------------------------------
$script:pomoEnd   = $null
$script:pomoMode  = ''
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

$miRestore = New-Object System.Windows.Forms.ToolStripMenuItem 'Restore Windows sounds'
$miRestore.Add_Click({
    Start-Process powershell -WindowStyle Hidden -ArgumentList `
        "-NoProfile -ExecutionPolicy Bypass -File `"$Base\Uninstall-IonityMarioTheme.ps1`" -KeepFiles -Quiet"
    $tray.ShowBalloonTip(3000, 'Ionity Mario', 'Original Windows sounds restored. Re-apply from installer.', 'Info')
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

# ---- timers -----------------------------------------------------------------
$tick = New-Object System.Windows.Forms.Timer
$tick.Interval = 1000
$tick.Add_Tick({
    # smart quiet: auto-hide watermark + mute companion sounds in fullscreen
    if ([bool]$settings.quiet) {
        $fs = Test-Fullscreen
        if ($fs -ne $script:quietNow) {
            $script:quietNow = $fs
            if ($fs) { if ($wm.Visible) { $wm.Hide() } }
            elseif ([bool]$settings.watermark -and -not $wm.Visible) { Show-Wm }
        }
    } elseif ($script:quietNow) {
        $script:quietNow = $false
        if ([bool]$settings.watermark -and -not $wm.Visible) { Show-Wm }
    }
    Update-Wm   # live SAST clock + focus counter
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
                $tray.ShowBalloonTip(4000, '1-UP Pomodoro', 'Break over - climb back in!', 'Info')
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
        [IonWin32]::SetWindowPos($wm.Handle, [IonWin32]::HWND_TOPMOST, 0,0,0,0,
            ([IonWin32]::SWP_NOMOVE -bor [IonWin32]::SWP_NOSIZE -bor [IonWin32]::SWP_NOACTIVATE)) | Out-Null
    }
})
$keepTop.Start()

# ---- run ----------------------------------------------------------------------
if ([bool]$settings.watermark) { Show-Wm }
$ctx = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($ctx)
$mutex.ReleaseMutex()
