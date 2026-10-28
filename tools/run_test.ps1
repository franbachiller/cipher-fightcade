param([int]$Side = 2, [int]$Seconds = 25, [string]$Shot = "")
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$env:CIPHER_AUTOSTART = "1"; $env:CIPHER_SIDE = "$Side"; $env:CIPHER_LUA = "$Root\cipher.lua"
Remove-Item "$Root\logs\cipher.log" -ErrorAction SilentlyContinue
$p = Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\test_f0.lua" -WorkingDirectory (Split-Path $Exe) -PassThru
Start-Sleep $Seconds
if ($Shot) {
	Add-Type -AssemblyName System.Windows.Forms, System.Drawing
	$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
	$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
	$g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
	$bmp.Save($Shot); $g.Dispose(); $bmp.Dispose()
}
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
Start-Sleep 1
Get-Content "$Root\logs\cipher.log"
