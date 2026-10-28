# Test online local (GGPO quark:direct 127.0.0.1) con backend keys.
# A = player 0 (P1): cipher.lua, bot ON, output=keys vía tools\cipher_keys.py
# B = player 1 (P2): net_observer.lua pasivo. Char select con teclas reales alternando foco.
param([int]$FightSeconds = 25, [string]$ShotDir = "", [int]$Shots = 0)
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$Dir  = Split-Path $Exe
Remove-Item "$Root\logs\net_*.log" -ErrorAction SilentlyContinue

Add-Type @"
using System; using System.Runtime.InteropServices;
public static class K {
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  public static void Tap(byte scan){ keybd_event(0, scan, 0x8, UIntPtr.Zero); System.Threading.Thread.Sleep(90); keybd_event(0, scan, 0x8|0x2, UIntPtr.Zero); }
}
"@
$ws = New-Object -ComObject WScript.Shell

$helper = Start-Process python -ArgumentList "-I", "$Root\tools\cipher_keys.py", "serve" -PassThru -WindowStyle Minimized
Start-Sleep 1

$env:CIPHER_ROOT = $Root; $env:CIPHER_OBS_MASH = ""
$env:CIPHER_AUTOSTART = "1"; $env:CIPHER_SIDE = "1"; $env:CIPHER_OUTPUT = "keys"; $env:CIPHER_LOGNAME = "net_A"
$a = Start-Process $Exe -ArgumentList "quark:direct,sfiii3nr1,7000,127.0.0.1,7001,0,0,0", "$Root\cipher.lua" -WorkingDirectory $Dir -PassThru
$env:CIPHER_AUTOSTART = ""; $env:CIPHER_OUTPUT = ""; $env:CIPHER_LOGNAME = "net_B"
$b = Start-Process $Exe -ArgumentList "quark:direct,sfiii3nr1,7001,127.0.0.1,7000,1,0,0", "$Root\tools\net_observer.lua" -WorkingDirectory $Dir -PassThru
Start-Sleep 8

# char select / SA select: LP (scancode A=0x1E) en cada ventana hasta que A vea la pelea
$deadline = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $deadline) {
	foreach ($proc in @($a, $b)) { $null = $ws.AppActivate($proc.Id); Start-Sleep -Milliseconds 250; [K]::Tap(0x1E); Start-Sleep -Milliseconds 250 }
	if (Select-String -Path "$Root\logs\net_A.log" -Pattern "match=true" -Quiet -ErrorAction SilentlyContinue) { break }
}
$null = $ws.AppActivate($a.Id)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$shots = [Math]::Max(0, $Shots)
for ($i = 1; $i -le $FightSeconds; $i++) {
	Start-Sleep 1
	if ($ShotDir -and ($i % 3 -eq 0) -and $shots -gt 0) {
		$shots--
		$bd = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
		$bmp = New-Object System.Drawing.Bitmap $bd.Width, $bd.Height
		$g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($bd.Location, [System.Drawing.Point]::Empty, $bd.Size)
		$bmp.Save((Join-Path $ShotDir "net_$i.png")); $g.Dispose(); $bmp.Dispose()
	}
}
Stop-Process -Id $a.Id, $b.Id -Force -ErrorAction SilentlyContinue
Start-Sleep 1
Stop-Process -Id $helper.Id -Force -ErrorAction SilentlyContinue

# Comparar por frame
$re = '^\[(\d+)\].*?P1 c=(\d+) hp=(\d+) x=(-?\d+).*?P2 c=(\d+) hp=(\d+) x=(-?\d+)'
$A = @{}; Get-Content "$Root\logs\net_A.log" | ForEach-Object { if ($_ -match $re) { $A[[int]$Matches[1]] = "P1 hp=$($Matches[3]) x=$($Matches[4]) | P2 hp=$($Matches[6]) x=$($Matches[7])" } }
$B = @{}; Get-Content "$Root\logs\net_B.log" | ForEach-Object { if ($_ -match $re) { $B[[int]$Matches[1]] = "P1 hp=$($Matches[3]) x=$($Matches[4]) | P2 hp=$($Matches[6]) x=$($Matches[7])" } }
"backend/log A:"; Select-String -Path "$Root\logs\net_A.log" -Pattern "output:|bot (ON|OFF)" | ForEach-Object Line
$common = $A.Keys | Where-Object { $B.ContainsKey($_) } | Sort-Object
$same = 0; $diff = 0
foreach ($f in $common) { if ($A[$f] -eq $B[$f]) { $same++ } else { $diff++ } }
"frames comunes=$($common.Count) iguales=$same distintos=$diff"
$common | Select-Object -Last 12 | ForEach-Object { "{0,7}  A: {1}   ||  B: {2}" -f $_, $A[$_], $B[$_] }
