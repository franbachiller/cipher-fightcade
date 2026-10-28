# Laboratorio de combos para todos los personajes elegibles (6 instancias en paralelo por personaje).
param([int]$Dist = 60, [int]$Shards = 6, [string[]]$Chars = @())
$SA = @{ alex = 2; ryu = 1; yun = 3; dudley = 2; necro = 3; hugo = 1; ibuki = 1; elena = 2; oro = 2; yang = 3; ken = 3;
         sean = 2; urien = 3; gouki = 1; chunli = 2; makoto = 1; q = 3; twelve = 2; remy = 2 }
if ($Chars.Count -eq 0) { $Chars = $SA.Keys | Sort-Object }
$Root = Split-Path $PSScriptRoot -Parent
foreach ($c in $Chars) {
	$dummy = $(if ($c -eq "ryu") { "ken" } else { "ryu" })
	"=== $c (SA$($SA[$c]), dummy $dummy)"
	& "$Root\tools\combo_lab.ps1" -Char $c -Dist $Dist -Dummy $dummy -SA $SA[$c] -Shards $Shards -TimeoutMin 10 | Select-Object -First 4
}
