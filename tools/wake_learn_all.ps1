# Aprende el frame de levantarse (wake_stats.lua) de todos los personajes: Ken (bot) tira al piso a cada rival quieto.
param([int]$Parallel = 5, [int]$Seconds = 70)
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$all = "alex","ryu","yun","dudley","necro","hugo","ibuki","elena","oro","yang","ken","sean","urien","gouki","chunli","makoto","q","twelve","remy"
$learned = @{}
if (Test-Path "$Root\data\learn\wake_stats.lua") {
	Select-String -Path "$Root\data\learn\wake_stats.lua" -Pattern '\["(\w+)"\]' | ForEach-Object { $learned[$_.Matches[0].Groups[1].Value] = 1 }
}
$todo = $all | Where-Object { -not $learned.ContainsKey($_) }
"faltan: $($todo -join ', ')"
for ($i = 0; $i -lt $todo.Count; $i += $Parallel) {
	$batch = $todo[$i..([Math]::Min($i + $Parallel, $todo.Count) - 1)]
	$procs = @()
	foreach ($c in $batch) {
		$env:CIPHER_ROOT = $Root; $env:CIPHER_AUTOSTART = "1"; $env:CIPHER_SIDE = "1"; $env:CIPHER_OUTPUT = "lua"
		$env:CIPHER_BRAIN = "fundamentals"; $env:CIPHER_SPAR = ""; $env:CIPHER_P1 = "ken"; $env:CIPHER_P2 = $c
		$env:CIPHER_LOGNAME = "wake_$c"; $env:CIPHER_FRESH = "1"; $env:CIPHER_TURBO = "1"; $env:CIPHER_ARCADE = ""
		$env:CIPHER_OKI_PLAN = "meaty"; $env:CIPHER_OKI_K = ""; $env:CIPHER_OKI_TRACE = ""
		$procs += Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\eval.lua" -WorkingDirectory (Split-Path $Exe) -PassThru
		Start-Sleep 2
	}
	Start-Sleep $Seconds
	$procs | ForEach-Object { Stop-Process -Id $_.Id -ErrorAction SilentlyContinue }
}
Get-Content "$Root\data\learn\wake_stats.lua"
