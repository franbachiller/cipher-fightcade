# Lab de castigos: el personaje (P1, brain real) contra el muñeco punish_dummy (P2), que hace golpes inseguros
# conocidos en ciclo. Instancias repartidas mitad offline / mitad con las ramas online (CIPHER_FORCE_EXT).
# Reporte agregado por modo: punish_report.py
param([string]$Char = "ryu", [string]$Dummy = "ryu", [int]$Seconds = 300, [int]$Instances = 8, [int]$PerScenario = 6)
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$SA = Get-Content "$Root\data\sfiii3\sa_pick.lua" -Raw
$sa = 1; if ($SA -match "\[`"$Char`"\] = (\d)") { $sa = [int]$Matches[1] }
Remove-Item "$Root\logs\punishlab_${Char}_*.log" -ErrorAction SilentlyContinue
$procs = @()
for ($i = 0; $i -lt $Instances; $i++) {
	$ext = "$($i % 2)"
	$env:CIPHER_ROOT = $Root; $env:CIPHER_AUTOSTART = "1"; $env:CIPHER_SIDE = "1"; $env:CIPHER_OUTPUT = "lua"
	$env:CIPHER_BRAIN = "fundamentals"; $env:CIPHER_FRESH = "1"; $env:CIPHER_TURBO = "1"; $env:CIPHER_ARCADE = ""
	$env:CIPHER_SPAR = "punish_dummy"; $env:CIPHER_P1 = $Char; $env:CIPHER_P2 = $Dummy
	$env:CIPHER_SA1 = "$sa"; $env:CIPHER_SA2 = "1"; $env:CIPHER_LOGNAME = "punishlab_${Char}_ext${ext}_$i"
	$env:CIPHER_FORCE_EXT = $ext; $env:CIPHER_PL_N = "$PerScenario"
	$procs += Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\eval.lua" -WorkingDirectory (Split-Path $Exe) -PassThru -WindowStyle Hidden
	Start-Sleep 1
}
$t0 = Get-Date
while (@($procs | Where-Object { -not $_.HasExited }).Count -gt 0) {
	Start-Sleep 2
	Get-Process fcadefbneo -ErrorAction SilentlyContinue | ForEach-Object { try { $_.PriorityClass = 'BelowNormal' } catch {} }
	if (((Get-Date) - $t0).TotalSeconds -gt $Seconds) { $procs | ForEach-Object { Stop-Process -Id $_.Id -ErrorAction SilentlyContinue } }
}
$env:CIPHER_FORCE_EXT = ""; $env:CIPHER_SPAR = ""
python -I "$Root\tools\punish_report.py" "offline=$Root\logs\punishlab_${Char}_ext0_*.log" "online=$Root\logs\punishlab_${Char}_ext1_*.log"
