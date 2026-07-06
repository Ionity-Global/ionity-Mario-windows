# =====================================================================
#  Ionity Mario Sound Theme — animated GUI Setup
#  Compile:  Invoke-PS2EXE Setup-GUI.ps1 IonityMarioSetup.exe -noConsole
#  (c) 2018-2026 Antwerp Designs | Ionity (Pty) Ltd · ionity.today
# =====================================================================
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---- locate payload (works as .ps1 and as ps2exe-compiled .exe) ------
$BaseDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BaseDir)) {
    $exe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($exe -notmatch 'powershell|pwsh') { $BaseDir = Split-Path -Parent $exe }
}
$RepoRoot = Split-Path -Parent $BaseDir
$SndSrc   = Join-Path $RepoRoot 'sounds'
$LogoPng  = Join-Path $RepoRoot 'assets\ionity_logo.png'

if (-not (Test-Path $SndSrc)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Sound files not found.`n`nPlease run the setup from inside the extracted 'ionity-Mario-windows' folder (next to the sounds/ directory).",
        'Ionity Mario Setup', 'OK', 'Warning') | Out-Null
    exit
}

# ---- colors -----------------------------------------------------------
$cBg     = [System.Drawing.Color]::FromArgb(13, 27, 42)      # #0d1b2a
$cPanel  = [System.Drawing.Color]::FromArgb(22, 33, 62)      # #16213e
$cCyan   = [System.Drawing.Color]::FromArgb(0, 198, 255)     # #00c6ff
$cText   = [System.Drawing.Color]::FromArgb(234, 246, 255)
$cMuted  = [System.Drawing.Color]::FromArgb(143, 184, 216)
$cRed    = [System.Drawing.Color]::FromArgb(233, 69, 96)

# ---- sound helper (drives the animation burst) ------------------------
$script:soundUntil = Get-Date
function Play-Snd([string]$name) {
    $p = Join-Path $SndSrc $name
    if (Test-Path $p) {
        (New-Object System.Media.SoundPlayer($p)).Play()
        $secs = [Math]::Max(0.6, (Get-Item $p).Length / 44100.0)   # 22 kHz 16-bit mono
        $script:soundUntil = (Get-Date).AddSeconds($secs)
    }
}

# ---- form -------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Ionity Mario Sound Theme — Setup'
$form.ClientSize = New-Object System.Drawing.Size(580, 480)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.BackColor = $cBg
try { $form.Icon = New-Object System.Drawing.Icon((Join-Path $RepoRoot 'assets\ionity_logo.ico')) } catch {}
# double-buffer the form so particles don't flicker
$form.GetType().GetProperty('DoubleBuffered',[System.Reflection.BindingFlags]'Instance,NonPublic').SetValue($form,$true,$null)

# ---- floating particles ------------------------------------------------
$script:parts = New-Object System.Collections.ArrayList
$rand = New-Object System.Random
function Spawn-Part([string]$kind) {
    [void]$script:parts.Add(@{
        x = $rand.Next(15, $form.ClientSize.Width - 30)
        y = $form.ClientSize.Height + 10
        vy = 1.4 + $rand.NextDouble() * 2.2
        ph = $rand.NextDouble() * 6.28
        sz = 14 + $rand.Next(0, 12)
        kind = $kind
        spin = $rand.NextDouble() * 0.25
    })
}

$form.Add_Paint({
    $g = $_.Graphics
    $g.SmoothingMode = 'AntiAlias'
    foreach ($p in @($script:parts)) {
        $x = [single]$p.x; $y = [single]$p.y; $s = [single]$p.sz
        switch ($p.kind) {
            'coin' {
                $sq = [Math]::Abs([Math]::Sin($p.ph * 2)) * 0.6 + 0.4   # spin effect
                $w = $s * $sq
                $g.FillEllipse([System.Drawing.Brushes]::Gold, $x - $w/2, $y, $w, $s)
                $g.FillEllipse([System.Drawing.Brushes]::Goldenrod, $x - $w*0.3, $y + $s*0.18, $w*0.6, $s*0.64)
            }
            'shroom' {
                $g.FillPie((New-Object System.Drawing.SolidBrush($cRed)), $x - $s/2, $y - $s*0.1, $s, $s, 180, 180)
                $g.FillEllipse([System.Drawing.Brushes]::White, $x - $s*0.15, $y + $s*0.02, $s*0.3, $s*0.3)
                $g.FillEllipse([System.Drawing.Brushes]::White, $x - $s*0.42, $y + $s*0.16, $s*0.22, $s*0.22)
                $g.FillEllipse([System.Drawing.Brushes]::White, $x + $s*0.2,  $y + $s*0.16, $s*0.22, $s*0.22)
                $g.FillRectangle([System.Drawing.Brushes]::AntiqueWhite, $x - $s*0.22, $y + $s*0.38, $s*0.44, $s*0.3)
            }
            'star' {
                $pts = @()
                for ($i = 0; $i -lt 10; $i++) {
                    $r = if ($i % 2 -eq 0) { $s * 0.55 } else { $s * 0.24 }
                    $a = $p.ph * 0.5 + $i * [Math]::PI / 5
                    $pts += New-Object System.Drawing.PointF(($x + $r * [Math]::Sin($a)), ($y + $r * -[Math]::Cos($a)))
                }
                $g.FillPolygon([System.Drawing.Brushes]::Khaki, $pts)
            }
        }
    }
})

$anim = New-Object System.Windows.Forms.Timer
$anim.Interval = 40
$script:ambient = 0
$anim.Add_Tick({
    $playing = (Get-Date) -lt $script:soundUntil
    # spawn: gentle ambient always, coin-burst while sound plays
    $script:ambient++
    if ($script:ambient % 22 -eq 0) { Spawn-Part (@('coin','shroom','star') | Get-Random) }
    if ($playing -and ($script:ambient % 3 -eq 0)) { Spawn-Part 'coin' }
    foreach ($p in @($script:parts)) {
        $p.y -= $p.vy * $(if ($playing) { 1.9 } else { 1.0 })
        $p.ph += 0.11
        $p.x += [Math]::Sin($p.ph) * 1.15
        if ($p.y -lt -30) { $script:parts.Remove($p) }
    }
    if ($script:parts.Count -gt 90) { $script:parts.RemoveRange(0, $script:parts.Count - 90) }
    $form.Invalidate()
})
$anim.Start()

# ---- header ------------------------------------------------------------
$logo = New-Object System.Windows.Forms.PictureBox
$logo.Image = [System.Drawing.Image]::FromFile($LogoPng)
$logo.SizeMode = 'Zoom'
$logo.BackColor = [System.Drawing.Color]::Transparent
$logo.SetBounds(165, 18, 250, 68)
$form.Controls.Add($logo)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'SUPER MARIO SOUND THEME'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = $cCyan
$title.TextAlign = 'MiddleCenter'
$title.BackColor = [System.Drawing.Color]::Transparent
$title.SetBounds(40, 92, 500, 30)
$form.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = "Coin = notifications · Pipe = minimize · Game Over = shutdown`nBuilding Tomorrow, Today.  ·  ionity.today"
$sub.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$sub.ForeColor = $cMuted
$sub.TextAlign = 'MiddleCenter'
$sub.BackColor = [System.Drawing.Color]::Transparent
$sub.SetBounds(40, 124, 500, 34)
$form.Controls.Add($sub)

# ---- install dir picker --------------------------------------------------
$lblDir = New-Object System.Windows.Forms.Label
$lblDir.Text = 'Install to:'
$lblDir.ForeColor = $cText
$lblDir.BackColor = [System.Drawing.Color]::Transparent
$lblDir.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$lblDir.SetBounds(48, 172, 90, 22)
$form.Controls.Add($lblDir)

$txtDir = New-Object System.Windows.Forms.TextBox
$defaultDir = if (Test-Path 'G:\.ai\.claude') { 'G:\.ai\.claude\.Windows Mario' }
              else { Join-Path $env:LOCALAPPDATA 'Ionity\MarioSoundTheme' }
$txtDir.Text = $defaultDir
$txtDir.BackColor = $cPanel
$txtDir.ForeColor = $cText
$txtDir.BorderStyle = 'FixedSingle'
$txtDir.Font = New-Object System.Drawing.Font('Consolas', 9.5)
$txtDir.SetBounds(48, 196, 400, 26)
$form.Controls.Add($txtDir)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = 'Browse…'
$btnBrowse.FlatStyle = 'Flat'
$btnBrowse.ForeColor = $cText
$btnBrowse.BackColor = $cPanel
$btnBrowse.SetBounds(456, 194, 78, 28)
$btnBrowse.Add_Click({
    $fb = New-Object System.Windows.Forms.FolderBrowserDialog
    $fb.Description = 'Choose the Ionity Mario install folder'
    if ($fb.ShowDialog() -eq 'OK') { $txtDir.Text = Join-Path $fb.SelectedPath '.Windows Mario' }
})
$form.Controls.Add($btnBrowse)

$chkComp = New-Object System.Windows.Forms.CheckBox
$chkComp.Text = 'Ionity watermark (bottom-right, toggleable) + tray companion + 1-UP Pomodoro'
$chkComp.Checked = $true
$chkComp.ForeColor = $cText
$chkComp.BackColor = [System.Drawing.Color]::Transparent
$chkComp.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$chkComp.SetBounds(48, 230, 500, 24)
$form.Controls.Add($chkComp)

# ---- sound preview row ----------------------------------------------------
$lblTry = New-Object System.Windows.Forms.Label
$lblTry.Text = 'Try it:'
$lblTry.ForeColor = $cMuted
$lblTry.BackColor = [System.Drawing.Color]::Transparent
$lblTry.SetBounds(48, 268, 50, 24)
$form.Controls.Add($lblTry)
$px = 100
foreach ($pv in @(@('Coin','smb_coin.wav'), @('1-UP','smb_1-up.wav'), @('Power-up','smb_powerup.wav'), @('Pipe','smb_pipe.wav'), @('Stage clear','smb_stage_clear.wav'))) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $pv[0]
    $b.Tag  = $pv[1]
    $b.FlatStyle = 'Flat'
    $b.ForeColor = $cCyan
    $b.BackColor = $cPanel
    $b.FlatAppearance.BorderColor = $cCyan
    $b.SetBounds($px, 264, 86, 30)
    $b.Add_Click({ Play-Snd $this.Tag })
    $form.Controls.Add($b)
    $px += 92
}

# ---- progress + status ------------------------------------------------------
$bar = New-Object System.Windows.Forms.ProgressBar
$bar.SetBounds(48, 318, 486, 14)
$bar.Style = 'Continuous'
$bar.Visible = $false
$form.Controls.Add($bar)

$status = New-Object System.Windows.Forms.Label
$status.Text = ''
$status.ForeColor = $cMuted
$status.BackColor = [System.Drawing.Color]::Transparent
$status.TextAlign = 'MiddleCenter'
$status.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$status.SetBounds(40, 336, 500, 22)
$form.Controls.Add($status)

# ---- install / finish button -------------------------------------------------
$btnGo = New-Object System.Windows.Forms.Button
$btnGo.Text = 'INSTALL'
$btnGo.Font = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
$btnGo.ForeColor = $cBg
$btnGo.BackColor = $cCyan
$btnGo.FlatStyle = 'Flat'
$btnGo.FlatAppearance.BorderSize = 0
$btnGo.SetBounds(190, 368, 200, 46)
$form.Controls.Add($btnGo)

$btnUn = New-Object System.Windows.Forms.Button
$btnUn.Text = 'Uninstall / restore Windows sounds'
$btnUn.FlatStyle = 'Flat'
$btnUn.FlatAppearance.BorderSize = 0
$btnUn.ForeColor = $cMuted
$btnUn.BackColor = [System.Drawing.Color]::Transparent
$btnUn.Font = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Underline)
$btnUn.SetBounds(165, 428, 250, 24)
$form.Controls.Add($btnUn)

$foot = New-Object System.Windows.Forms.Label
$foot.Text = ([char]0xA9) + ' 2018-2026 Antwerp Designs | Ionity (Pty) Ltd - Sounds ' + ([char]0xA9) + ' Nintendo (fan project)'
$foot.ForeColor = [System.Drawing.Color]::FromArgb(93, 128, 160)
$foot.BackColor = [System.Drawing.Color]::Transparent
$foot.Font = New-Object System.Drawing.Font('Segoe UI', 7.5)
$foot.TextAlign = 'MiddleCenter'
$foot.SetBounds(40, 456, 500, 18)
$form.Controls.Add($foot)

$script:done = $false
$btnGo.Add_Click({
    if ($script:done) { $form.Close(); return }
    $dir = $txtDir.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($dir)) { return }
    $btnGo.Enabled = $false; $btnBrowse.Enabled = $false; $txtDir.Enabled = $false
    $bar.Visible = $true; $bar.Style = 'Marquee'
    $status.Text = 'Installing - warping down the pipe...'
    Play-Snd 'smb_pipe.wav'
    $form.Refresh()

    $ps1 = Join-Path $BaseDir 'Install-IonityMarioTheme.ps1'
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$ps1`" -InstallDir `"$dir`" -Quiet"
    if (-not $chkComp.Checked) { $args += ' -NoCompanion' }
    $p = Start-Process powershell -ArgumentList $args -WindowStyle Hidden -Wait -PassThru

    $bar.Style = 'Continuous'; $bar.Value = 100
    if ($p.ExitCode -eq 0) {
        $status.ForeColor = $cCyan
        $status.Text = "Stage clear! Installed to $dir"
        Play-Snd 'smb_stage_clear.wav'
        for ($i = 0; $i -lt 26; $i++) { Spawn-Part (@('coin','coin','star','shroom') | Get-Random) }
        $btnGo.Text = 'FINISH'
        $btnGo.BackColor = [System.Drawing.Color]::FromArgb(72, 199, 116)
        $script:done = $true
        $btnGo.Enabled = $true
    } else {
        $status.ForeColor = $cRed
        $status.Text = 'Bowser blocked the install (exit ' + $p.ExitCode + ') - try again.'
        Play-Snd 'smb_bump.wav'
        $btnGo.Enabled = $true; $btnBrowse.Enabled = $true; $txtDir.Enabled = $true
    }
})

$btnUn.Add_Click({
    $ps1 = Join-Path $BaseDir 'Uninstall-IonityMarioTheme.ps1'
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$ps1`" -Quiet" -WindowStyle Hidden -Wait
    Play-Snd 'smb_pipe.wav'
    $status.ForeColor = $cMuted
    $status.Text = 'Original Windows sounds restored.'
})

Play-Snd 'smb_coin.wav'   # hello!
[void]$form.ShowDialog()
$anim.Stop()
