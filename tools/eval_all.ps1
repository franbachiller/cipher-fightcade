# Arcade en paralelo para varios personajes y semillas (bot en P1 contra la CPU). Corta cada partida apenas se decide.
# Resultado por personaje: rivales vencidos en cada semilla y promedio.
param([string[]]$Chars = @("alex","chunli","dudley","elena","gouki","hugo","ibuki","ken","makoto","necro","oro","q","remy","ryu","sean","twelve","urien","yang","yun"),
      [int]$Parallel = 12, [int]$MaxSeconds = 900, [int]$Seeds = 1)
$SA = @{ alex = 2; ryu = 1; yun = 3; dudley = 2; necro = 3; hugo = 1; ibuki = 1; elena = 2; oro = 2; yang = 2; ken = 3;
         sean = 2; urien = 3; gouki = 1; chunli = 2; makoto = 1; q = 3; twelve = 2; remy = 2 }
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$rx = 'ROUND \d+ end P1=(\w+)\(hp (-?\d+)\) P2=(\w+)\(hp (-?\d+)\)'
function Won([int]$a, [int]$b) { $ad = ($a -eq 0 -or $a -eq 255); $bd = ($b -eq 0 -or $b -eq 255); return ((-not $ad) -and ($bd -or $a -gt $b)) }

function Status($tag, $c) {
	$f = Join-Path $Root "logs\arc_$tag.log"
	if (-not (Test-Path $f)) { return $null }
	$st = @(); $over = $false
	foreach ($x in (Select-String -Path $f -Pattern $rx)) {
		$g = $x.Matches[0].Groups
		if ($g[1].Value -ne $c) { $over = $true; break }
		$opp = $g[3].Value
		if (-not $st -or $st[-1].opp -ne $opp) { $st += [pscustomobject]@{ opp = $opp; w = 0; l = 0 } }
		if (Won ([int]$g[2].Value) ([int]$g[4].Value)) { $st[-1].w++ } else { $st[-1].l++ }
	}
	$last = $(if ($st) { $st[-1] } else { $null })
	if ($last -and $last.l -ge 2) { $over = $true }
	if ($last -and $last.opp -eq "gill" -and $last.w -ge 2) { $over = $true }
	return [pscustomobject]@{ stages = $st; over = $over; mtime = (Get-Item $f).LastWriteTime }
}

$env:CIPHER_ROOT = $Root; $env:CIPHER_AUTOSTART = "1"; $env:CIPHER_SIDE = "1"; $env:CIPHER_OUTPUT = "lua"
$env:CIPHER_BRAIN = "fundamentals"; $env:CIPHER_SPAR = ""; $env:CIPHER_TURBO = "1"; $env:CIPHER_FRESH = "1"; $env:CIPHER_ARCADE = "1"
$queue = [System.Collections.Queue]::new()
foreach ($sd in 1..$Seeds) { foreach ($c in $Chars) { $queue.Enqueue([pscustomobject]@{ c = $c; sd = $sd }) } }
$running = @{}; $beatenBy = @{}; $t0 = Get-Date
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
	while ($running.Count -lt $Parallel -and $queue.Count -gt 0) {
		$job = $queue.Dequeue(); $c = $job.c; $tag = "$($job.c)_s$($job.sd)"
		$lf = Join-Path $Root "logs\arc_$tag.log"
		if (Test-Path $lf) { Clear-Content $lf }
		$env:CIPHER_P1 = $c; $env:CIPHER_P2 = $c; $env:CIPHER_SA1 = "$($SA[$c])"; $env:CIPHER_LOGNAME = "arc_$tag"
		$env:CIPHER_SEED = "$($job.sd * 7919)"
		$running[$tag] = @{ c = $c; p = (Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\eval.lua" -WorkingDirectory (Split-Path $Exe) -PassThru -WindowStyle Minimized); t = Get-Date }
		Start-Sleep -Milliseconds 400
	}
	Start-Sleep 3
	foreach ($tag in @($running.Keys)) {
		$r = $running[$tag]; $s = Status $tag $r.c
		$stale = $s -and $s.stages -and ((Get-Date) - $s.mtime).TotalSeconds -gt 90
		$noStart = (-not ($s -and $s.stages)) -and ((Get-Date) - $r.t).TotalSeconds -gt 240
		$timeout = ((Get-Date) - $r.t).TotalSeconds -gt $MaxSeconds
		if ($r.p.HasExited -or ($s -and $s.over) -or $stale -or $noStart -or $timeout) {
			Stop-Process -Id $r.p.Id -Force -ErrorAction SilentlyContinue
			$running.Remove($tag)
			$beaten = $(if ($s) { @($s.stages | Where-Object { $_.w -ge 2 }).Count } else { 0 })
			if (-not $beatenBy.ContainsKey($r.c)) { $beatenBy[$r.c] = @() }
			$beatenBy[$r.c] += $beaten
			$path = $(if ($s -and $s.stages) { ($s.stages | ForEach-Object { "$($_.opp) $($_.w)-$($_.l)" }) -join ", " } else { "sin rounds" })
			# el largo del arcade varía por recorrido (10 u 11 rivales): pasar el juego = vencer a Gill
			$cleared = $s -and $s.stages -and ($s.stages[-1].opp -eq "gill") -and ($s.stages[-1].w -ge 2)
			if ($cleared) { $beaten = 99 }
			"{0,-12} {1} | {2}" -f $tag, $(if ($cleared) { "PASÓ EL JUEGO" } else { "vencidos=$beaten" }), $path
		}
	}
}
"--- resultado por personaje (99 = pasó el juego; si no, rivales vencidos)"
$beatenBy.GetEnumerator() | Sort-Object { -(@($_.Value | Where-Object { $_ -eq 99 }).Count), -(($_.Value | Measure-Object -Average).Average) } | ForEach-Object {
	"{0,-7} pasó {1}/{2}  [{3}]" -f $_.Key, @($_.Value | Where-Object { $_ -eq 99 }).Count, $_.Value.Count, ($_.Value -join ",") }
"TOTAL {0:N0}s" -f ((Get-Date) - $t0).TotalSeconds
