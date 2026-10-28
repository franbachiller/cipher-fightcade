# Bot (P2) vs sparring (P1) offline. Imprime métricas y eventos del bot.
param([int]$Seconds = 60, [string]$Brain = "fundamentals", [string]$Spar = "sparring",
      [string]$P1 = "ryu", [string]$P2 = "ken", [switch]$Turbo, [switch]$Arcade, [string]$Log = "eval")
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$env:CIPHER_ROOT = $Root; $env:CIPHER_AUTOSTART = "1"; $env:CIPHER_SIDE = "2"; $env:CIPHER_OUTPUT = "lua"
$env:CIPHER_BRAIN = $Brain; $env:CIPHER_SPAR = $Spar; $env:CIPHER_P1 = $P1; $env:CIPHER_P2 = $P2
$env:CIPHER_TURBO = $(if ($Turbo) { "1" } else { "" }); $env:CIPHER_LOGNAME = $Log; $env:CIPHER_FRESH = "1"
if ($Arcade) { $env:CIPHER_ARCADE = "1"; $env:CIPHER_SIDE = "1"; $env:CIPHER_SPAR = ""; $env:CIPHER_P1 = $P2; $env:CIPHER_SA1 = "3" } else { $env:CIPHER_ARCADE = "" }
Remove-Item "$Root\logs\$Log.log" -ErrorAction SilentlyContinue
function Won([int]$mine, [int]$theirs) {
	$md = ($mine -eq 0 -or $mine -eq 255); $td = ($theirs -eq 0 -or $theirs -eq 255)
	return ((-not $md) -and ($td -or $mine -gt $theirs))
}
$p = Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\eval.lua" -WorkingDirectory (Split-Path $Exe) -PassThru
# Corte por evento: termina apenas se decide la partida. $Seconds queda como tope de seguridad.
$t0 = Get-Date; $lastCount = 0; $lastChange = Get-Date; $reason = "tope de $Seconds s"
$rx = 'ROUND \d+ end P1=(\w+)\(hp (-?\d+)\) P2=(\w+)\(hp (-?\d+)\)'
while (((Get-Date) - $t0).TotalSeconds -lt $Seconds -and -not $p.HasExited) {
	Start-Sleep 2
	if (-not (Test-Path "$Root\logs\$Log.log")) { continue }
	$lines = @(Select-String -Path "$Root\logs\$Log.log" -Pattern $rx)
	if ($lines.Count -ne $lastCount) { $lastCount = $lines.Count; $lastChange = Get-Date }
	if ($lines.Count -eq 0) { continue }
	$bot = $(if ($Arcade) { $P2 } else { $P2 })
	$botSide = $(if ($Arcade) { 1 } else { 2 })
	$m = $lines[-1].Matches[0].Groups
	$botChar = $m[$(if ($botSide -eq 1) { 1 } else { 3 })].Value
	$oppChar = $m[$(if ($botSide -eq 1) { 3 } else { 1 })].Value
	if ($botChar -ne $bot) { $reason = "game over (el bot ya no está en la pelea)"; break }
	if (-not $Arcade -and $oppChar -ne $P1) { $reason = "el sparring perdió la partida"; break }
	if ($Arcade -and $oppChar -eq "gill") {
		$gw = 0; $gl = 0
		foreach ($x in $lines) { $g = $x.Matches[0].Groups; if ($g[3].Value -eq "gill") { if (Won ([int]$g[2].Value) ([int]$g[4].Value)) { $gw++ } else { $gl++ } } }
		if ($gw -ge 2) { $reason = "Gill vencido: juego terminado"; break }
		if ($gl -ge 2) { $reason = "perdió contra Gill"; break }
	}
	if (((Get-Date) - $lastChange).TotalSeconds -gt 75) { $reason = "sin rounds nuevos en 75 s (continue/attract)"; break }
}
"fin: $reason ({0:N0}s)" -f ((Get-Date) - $t0).TotalSeconds
Start-Sleep 1
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
Start-Sleep 1
$l = Get-Content "$Root\logs\$Log.log"
"--- errores"; $l | Select-String "error" | Select-Object -First 5 | ForEach-Object Line
"--- rounds/métricas"; $l | Select-String "ROUND" | ForEach-Object { ($_.Line -split ' \| ')[0] }; $l | Select-String "METRICS" | Select-Object -Last 1 | ForEach-Object Line
if ($Arcade) {
	# rondas hasta el game over (el bot deja de ser P1=$P2) -> rivales vencidos
	$rounds = @(); foreach ($x in ($l | Select-String "ROUND \d+ end P1=(\w+)\(hp (-?\d+)\) P2=(\w+)\(hp (-?\d+)\)")) {
		$m = $x.Matches[0].Groups; if ($m[1].Value -ne $P2) { break }
		$rounds += [pscustomobject]@{ opp = $m[3].Value; win = (Won ([int]$m[2].Value) ([int]$m[4].Value)) } }
	$stages = @(); foreach ($r in $rounds) { if (-not $stages -or $stages[-1].opp -ne $r.opp) { $stages += [pscustomobject]@{ opp = $r.opp; w = 0; l = 0 } }; if ($r.win) { $stages[-1].w++ } else { $stages[-1].l++ } }
	"--- arcade"; $stages | ForEach-Object { "{0,-8} {1}-{2}" -f $_.opp, $_.w, $_.l }
	"vencidos: " + ($stages | Where-Object { $_.w -ge 2 }).Count
	"--- post-parry"; $l | Select-String "pp-diag" | ForEach-Object { if ($_.Line -match 'pp-diag (.+) dmg=(\d+)') { [pscustomobject]@{ n = $Matches[1]; d = [int]$Matches[2] } } } | Group-Object n | ForEach-Object { "{0,4}x {1,-18} dmg prom={2:N1} conectó={3}" -f $_.Count, $_.Name, ($_.Group | Measure-Object d -Average).Average, ($_.Group | Where-Object { $_.d -gt 0 }).Count }
}
"--- acciones del bot (conteo)"
$l | Select-String "bot: " | ForEach-Object { ($_.Line -replace '^.*bot: ', '') -replace ' \(rec \d+\)', '' -replace ' vs .*$', '' } | Group-Object | Sort-Object Count -Descending | Select-Object -First 18 | ForEach-Object { "{0,5}  {1}" -f $_.Count, $_.Name }
