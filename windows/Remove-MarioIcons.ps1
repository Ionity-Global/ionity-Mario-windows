# Ionity Mario Icon Pack — remove (restore Windows default icons)
$ErrorActionPreference = 'SilentlyContinue'
$si = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'
Remove-ItemProperty -Path $si -Name '3'
Remove-ItemProperty -Path $si -Name '4'
Remove-Item 'HKCU:\Software\Classes\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}' -Recurse -Force
Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\DriveIcons' -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force
$base = (Get-ItemProperty 'HKCU:\Software\Ionity\MarioSoundTheme' -ErrorAction SilentlyContinue).InstallDir
if ($base) {
    attrib -r "$base"
    Remove-Item (Join-Path $base 'desktop.ini') -Force
}
Add-Type -Namespace Ion -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern void SHChangeNotify(int eventId, int flags, IntPtr i1, IntPtr i2);'
[Ion.Shell]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)
ie4uinit.exe -show
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
Write-Host 'Windows default icons restored.'
