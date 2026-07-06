# temp verification script (not part of release)
Write-Host ('Scheme:            ' + (Get-ItemProperty 'HKCU:\AppEvents\Schemes').'(default)')
Write-Host ('Scheme name:       ' + (Get-ItemProperty 'HKCU:\AppEvents\Schemes\Names\IonityMario').'(default)')
Write-Host ('Asterisk .Current: ' + (Get-ItemProperty 'HKCU:\AppEvents\Schemes\Apps\.Default\SystemAsterisk\.Current').'(default)')
Write-Host ('Hand .Current:     ' + (Get-ItemProperty 'HKCU:\AppEvents\Schemes\Apps\.Default\SystemHand\.Current').'(default)')
Write-Host ('Minimize .Current: ' + (Get-ItemProperty 'HKCU:\AppEvents\Schemes\Apps\.Default\Minimize\.Current').'(default)')
$c = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'IonityMarioCompanion' }
Write-Host ('Companion running: ' + [bool]$c + '  (PID ' + ($c.ProcessId -join ',') + ')')
$run = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name IonityMarioCompanion -ErrorAction SilentlyContinue).IonityMarioCompanion
Write-Host ('Autostart Run key: ' + $run)
$bk = Test-Path "$env:LOCALAPPDATA\Ionity\MarioSoundTheme\backup.json"
Write-Host ('Backup exists:     ' + $bk)
Write-Host ''
Write-Host 'Firing live system sounds now...'
[System.Media.SystemSounds]::Asterisk.Play(); Start-Sleep -Seconds 2
Write-Host '  Asterisk fired -> should sound like COIN'
[System.Media.SystemSounds]::Hand.Play(); Start-Sleep -Seconds 2
Write-Host '  Hand fired     -> should sound like BOWSER FIRE'
