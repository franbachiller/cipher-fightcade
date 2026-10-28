# Verifica en el emulador los combos de la wiki (data\sfiii3\wiki_combos.lua) de varios personajes en paralelo.
# Una corrida por (personaje, SA usado en sus combos); la primera de cada personaje también prueba los combos sin super.
param([string[]]$Chars = @(), [int]$Parallel = 6, [int]$TimeoutSec = 900, [string]$Dummy = "ryu")
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$txt = (Get-Content "$Root\data\sfiii3\wiki_combos.lua" -Raw) + "`n" + (Get-Content "$Root\data\sfiii3\super_combos.lua" -Raw) + "`n" + (Get-Content "$Root\data\sfiii3\wiki_combos_auto.lua" -Raw)
$bodies = [ordered]@{}
foreach ($m in [regex]::Matches($txt, '(?ms)^\t(\w+) = \{(.*?)^\t\},')) { $bodies[$m.Groups[1].Value] += $m.Groups[2].Value }
$jobs = @()
foreach ($c in $bodies.Keys) {
	if ($Chars.Count -gt 0 -and $Chars -notcontains $c) { continue }
	$sas = @([regex]::Matches($bodies[$c], 'sa = (\d)') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique)
	if ($sas.Count -eq 0) { $sas = @(1) }
	$first = $true
	foreach ($sa in $sas) { $jobs += [pscustomobject]@{ char = $c; sa = $sa; base = $first }; $first = $false }
}
"corridas: $($jobs.Count)"
$running = @()
foreach ($j in $jobs) {
	while (@($running | Where-Object { -not $_.p.HasExited }).Count -ge $Parallel) {
		Start-Sleep 3
		Get-Process fcadefbneo -ErrorAction SilentlyContinue | ForEach-Object { try { $_.PriorityClass = 'BelowNormal' } catch {} }
		foreach ($r in $running) { if (-not $r.p.HasExited -and ((Get-Date) - $r.t).TotalSeconds -gt $TimeoutSec) { Stop-Process -Id $r.p.Id -ErrorAction SilentlyContinue; "TIMEOUT $($r.j.char) sa$($r.j.sa)" } }
	}
	$env:CIPHER_WCL_CHAR = $j.char; $env:CIPHER_WCL_SA = "$($j.sa)"; $env:CIPHER_WCL_DUMMY = $Dummy
	$env:CIPHER_WCL_BASE = $(if ($j.base) { "1" } else { "0" })
	# savestate numerado = archivo compartido entre emuladores: cada corrida en vuelo con su slot
	$busy = @($running | Where-Object { -not $_.p.HasExited } | ForEach-Object { $_.slot })
	$slot = @(1..9 | Where-Object { $busy -notcontains $_ })[0]
	$env:CIPHER_WCL_SLOT = "$slot"
	$p = Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\wiki_combo_lab.lua" -WorkingDirectory (Split-Path $Exe) -PassThru -WindowStyle Hidden
	$running += [pscustomobject]@{ p = $p; t = Get-Date; j = $j; slot = $slot }
	Start-Sleep 2
}
while (@($running | Where-Object { -not $_.p.HasExited }).Count -gt 0) {
	Start-Sleep 3
	Get-Process fcadefbneo -ErrorAction SilentlyContinue | ForEach-Object { try { $_.PriorityClass = 'BelowNormal' } catch {} }
	foreach ($r in $running) { if (-not $r.p.HasExited -and ((Get-Date) - $r.t).TotalSeconds -gt $TimeoutSec) { Stop-Process -Id $r.p.Id -ErrorAction SilentlyContinue; "TIMEOUT $($r.j.char) sa$($r.j.sa)" } }
}
foreach ($j in $jobs) { "===== $($j.char) sa$($j.sa)"; Get-Content "$Root\logs\wiki_combo_lab_$($j.char)_sa$($j.sa)_$Dummy.log" -ErrorAction SilentlyContinue }
