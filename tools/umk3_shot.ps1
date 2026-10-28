# Lanza UMK3 con la sonda y saca capturas de la ventana del emulador cada N segundos (para ver los menús).
# NO usar con una sesión online abierta: chequea antes que no haya otro fcadefbneo corriendo.
param([int]$Shots = 6, [int]$Every = 8, [string]$Seq = "", [string]$Out = "")
$exe = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
if (Get-Process fcadefbneo -ErrorAction SilentlyContinue) { "HAY UN EMULADOR ABIERTO: no lanzo"; exit 1 }
if ($Seq) { $env:CIPHER_UMK3_SEQ = $Seq }
if (-not $Out) { $Out = "$env:TEMP\cipher-shots" }
$p = Start-Process $exe -ArgumentList "umk3", "C:\Users\bachi\Desktop\CIPHER-Fightcade\tools\umk3_probe.lua" -WorkingDirectory (Split-Path $exe) -PassThru
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W { [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  public struct RECT { public int L, T, R, B; } }
"@
for ($i = 1; $i -le $Shots; $i++) {
	Start-Sleep $Every
	$p.Refresh()
	$h = $p.MainWindowHandle
	if ($h -eq [IntPtr]::Zero) { continue }
	[W]::SetForegroundWindow($h) | Out-Null
	$r = New-Object W+RECT; [W]::GetWindowRect($h, [ref]$r) | Out-Null
	$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
	$bmp.Save("$Out\umk3_$i.png")
}
Stop-Process -Id $p.Id -ErrorAction SilentlyContinue
$env:CIPHER_UMK3_SEQ = ""
Get-Content "C:\Users\bachi\Desktop\CIPHER-Fightcade\logs\umk3_probe.log" | Select-Object -Last 8
