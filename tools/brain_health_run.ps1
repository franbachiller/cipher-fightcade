# Health check en emulador: cada personaje pelea contra la CPU-sparring con el brain real; la mitad con las ramas
# del modo online (CIPHER_FORCE_EXT). Junta errores del brain, rounds, combos y diagnósticos por personaje.
param([string[]]$Chars = @("alex","chunli","dudley","elena","gouki","hugo","ibuki","ken","makoto","necro","oro","q","remy",
	"ryu","sean","twelve","urien","yang","yun"), [int]$Seconds = 75, [int]$Parallel = 8)
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$SA = Get-Content "$Root\data\sfiii3\sa_pick.lua" -Raw
$foes = @("ryu","ken","chunli","yun","hugo","makoto","urien")
$i = 0; $running = @()
foreach ($c in $Chars) {
	while (@($running | Where-Object { -not $_.p.HasExited }).Count -ge $Parallel) {
		Start-Sleep 2
		Get-Process fcadefbneo -ErrorAction SilentlyContinue | ForEach-Object { try { $_.PriorityClass = 'BelowNormal' } catch {} }
		foreach ($r in $running) { if (-not $r.p.HasExited -and ((Get-Date) - $r.t).TotalSeconds -gt $Seconds) { Stop-Process -Id $r.p.Id -ErrorAction SilentlyContinue } }
	}
	$sa = 1; if ($SA -match "\[`"$c`"\] = (\d)") { $sa = [int]$Matches[1] }
	$env:CIPHER_ROOT = $Root; $env:CIPHER_AUTOSTART = "1"; $env:CIPHER_SIDE = "1"; $env:CIPHER_OUTPUT = "lua"
	$env:CIPHER_BRAIN = "fundamentals"; $env:CIPHER_FRESH = "1"; $env:CIPHER_TURBO = "1"; $env:CIPHER_ARCADE = ""
	$env:CIPHER_SPAR = "sparring"; $env:CIPHER_P1 = $c; $env:CIPHER_P2 = $foes[$i % $foes.Count]
	$env:CIPHER_SA1 = "$sa"; $env:CIPHER_SA2 = "1"; $env:CIPHER_LOGNAME = "health_$c"
	$env:CIPHER_FORCE_EXT = $(if ($i % 2 -eq 0) { "1" } else { "0" })
	$p = Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\eval.lua" -WorkingDirectory (Split-Path $Exe) -PassThru -WindowStyle Hidden
	$running += [pscustomobject]@{ p = $p; t = Get-Date; c = $c; ext = $env:CIPHER_FORCE_EXT }
	$i++
	Start-Sleep 2
	Get-Process fcadefbneo -ErrorAction SilentlyContinue | ForEach-Object { try { $_.PriorityClass = 'BelowNormal' } catch {} }
}
while (@($running | Where-Object { -not $_.p.HasExited }).Count -gt 0) {
	Start-Sleep 2
	Get-Process fcadefbneo -ErrorAction SilentlyContinue | ForEach-Object { try { $_.PriorityClass = 'BelowNormal' } catch {} }
	foreach ($r in $running) { if (-not $r.p.HasExited -and ((Get-Date) - $r.t).TotalSeconds -gt $Seconds) { Stop-Process -Id $r.p.Id -ErrorAction SilentlyContinue } }
}
$env:CIPHER_FORCE_EXT = ""
python -I "$Root\tools\brain_health_report.py" @($running | ForEach-Object { "$($_.c):$($_.ext)" })
