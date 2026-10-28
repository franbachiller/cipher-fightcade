# Pool de workers para el laboratorio de combos: $Workers emuladores en paralelo repartidos entre personajes.
# Cada worker reclama starters de su personaje (claims atómicos) y se cierra solo al no quedar trabajo.
param([string[]]$Chars, [int]$Dist = 60, [int]$Level = 1, [int]$Workers = 12, [int]$PerChar = 6, [int]$TimeoutMin = 60, [switch]$KeepParts, [string]$OnlyFile = "", [string]$Mode = "", [switch]$NoLinks)
$SA = @{ alex = 2; ryu = 1; yun = 3; dudley = 2; necro = 3; hugo = 1; ibuki = 1; elena = 2; oro = 2; yang = 2; ken = 3;
         sean = 2; urien = 3; gouki = 1; chunli = 2; makoto = 1; q = 3; twelve = 2; remy = 2 }
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$env:CIPHER_ROOT = $Root; $env:CIPHER_LAB_DIST = "$Dist"; $env:CIPHER_LAB_LEVEL = "$Level"
$LV = $(if ($Level -gt 1) { "_L$Level" } else { "" })
$env:CIPHER_LAB_MODE = $Mode
$env:CIPHER_LAB_NOLINKS = $(if ($NoLinks) { "1" } else { "" })
if ($Mode -eq "chain") { $LV = "${LV}_chain" }
$Suffix = $(if ($Mode -eq "chain") { "_chain" } else { "" })
$t0 = Get-Date

# estado por personaje
$st = @{}
foreach ($c in $Chars) {
	Remove-Item "$Root\data\sfiii3\combos\claims\${c}_d$Dist$LV" -Recurse -Force -ErrorAction SilentlyContinue
	if (-not $KeepParts) { Get-ChildItem "$Root\data\sfiii3\combos\parts" -Filter "${c}_d${Dist}${LV}_s*.lua" -ErrorAction SilentlyContinue | Remove-Item }
	Get-ChildItem "$Root\logs" -Filter "combo_lab_${c}_d${Dist}${LV}_s*.log" -ErrorAction SilentlyContinue | Remove-Item
	$st[$c] = @{ started = 0; running = @(); merged = $false; t0 = $null }
}
# re-ensayo dirigido: líneas "char:starter1,starter2"
$only = @{}
if ($OnlyFile -and (Test-Path $OnlyFile)) { foreach ($ln in Get-Content $OnlyFile) { $kv = $ln.Split(":"); if ($kv.Count -eq 2) { $only[$kv[0]] = $kv[1] } } }
# más trabajo primero: nivel 1 por cantidad de especiales; nivel N por cantidad de links del nivel anterior
$weight = @{}
foreach ($c in $Chars) {
	if ($Level -le 1) { $weight[$c] = (Get-Item "$Root\data\sfiii3\moves\$c.lua").Length }
	else {
		$prev = "$Root\data\sfiii3\combos\${c}_d$Dist" + $(if ($Level -gt 2) { "_L$($Level - 1)" } else { "" }) + ".lua"
		$w = 0
		foreach ($pf in @($prev, ($prev -replace '\.lua$', '_chain.lua'))) { if (Test-Path $pf) { $w += @(Select-String -Path $pf -Pattern 'kind = "(link|chain)"').Count } }
		$weight[$c] = $w
	}
}
$Chars = @($Chars | Sort-Object { -$weight[$_] })
"orden: " + (($Chars | ForEach-Object { "$_($($weight[$_]))" }) -join " ")

function Exhausted($c) {
	# todos los starters reclamados: algún log de ese personaje ya terminó (DONE solo ocurre sin claims libres)
	foreach ($f in (Get-ChildItem "$Root\logs" -Filter "combo_lab_${c}_d${Dist}${LV}_s*.log" -ErrorAction SilentlyContinue)) {
		if (Select-String -Path $f.FullName -Pattern "DONE" -Quiet) { return $true }
	}
	return $false
}

$wid = $(if ($KeepParts) { 500 } else { 0 })   # ids nuevos para no pisar partes existentes
while (((Get-Date) - $t0).TotalMinutes -lt $TimeoutMin) {
	# limpiar workers terminados
	$alive = 0
	foreach ($c in $Chars) {
		$st[$c].running = @($st[$c].running | Where-Object { -not $_.HasExited })
		$alive += $st[$c].running.Count
	}
	# lanzar workers en slots libres: personaje en orden, hasta $PerChar por personaje y mientras no esté agotado
	foreach ($c in $Chars) {
	  # llenar este personaje hasta $PerChar antes de pasar al siguiente (el más pesado recibe todos sus workers)
	  while ($alive -lt $Workers) {
		$s = $st[$c]
		if ($s.merged) { break }
		if ($s.started -ge $PerChar -or ($s.started -gt 0 -and (Exhausted $c))) { break }
		$wid++
		$env:CIPHER_LAB_CHAR = $c; $env:CIPHER_LAB_SA = "$($SA[$c])"; $env:CIPHER_LAB_WORKER = "$wid"
		$env:CIPHER_LAB_DUMMY = $(if ($c -eq "ryu") { "ken" } else { "ryu" })
		$env:CIPHER_LAB_ONLY = $(if ($only.ContainsKey($c)) { $only[$c] } else { "" })
		if (-not $s.t0) { $s.t0 = Get-Date }
		# carpeta propia por worker: el savestate numerado es un ARCHIVO en el directorio del script (tools\9);
		# compartido entre workers de distintos personajes se pisaba (ventanas congeladas, cargas inválidas)
		$wd = "$Root\tools\work\w$wid"
		New-Item -ItemType Directory -Force $wd | Out-Null
		Set-Content -Path "$wd\lab.lua" -Encoding ascii -Value "dofile([[$Root\tools\combo_lab.lua]])"
		$s.running += Start-Process $Exe -ArgumentList "sfiii3nr1", "$wd\lab.lua" -WorkingDirectory (Split-Path $Exe) -PassThru -WindowStyle Minimized
		$s.started++
		$alive++
		Start-Sleep -Milliseconds 300
	  }
	}
	# unir personajes terminados
	foreach ($c in $Chars) {
		$s = $st[$c]
		if (-not $s.merged -and $s.started -gt 0 -and $s.running.Count -eq 0 -and (Exhausted $c)) {
			$s.merged = $true
			$out = python -I "$Root\tools\merge_combos.py" "$Root\data\sfiii3\combos\parts" $c $Dist "$Root\data\sfiii3\combos\${c}_d${Dist}${LV}.lua" $Level $Suffix | Select-Object -First 1
			"{0,-8} {1} | {2:N0}s (workers={3})" -f $c, $out, ((Get-Date) - $s.t0).TotalSeconds, $s.started
		}
	}
	if (@($Chars | Where-Object { -not $st[$_].merged }).Count -eq 0) { break }
	Start-Sleep -Milliseconds 1500
}
Remove-Item "$Root\tools\work" -Recurse -Force -ErrorAction SilentlyContinue
"TOTAL {0:N0}s" -f ((Get-Date) - $t0).TotalSeconds
