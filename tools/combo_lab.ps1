# Corre el laboratorio de combos en N instancias paralelas y une los resultados.
param([string]$Char = "ken", [int]$Dist = 60, [string]$Dummy = "ryu", [int]$SA = 3, [int]$Shards = 6, [int]$TimeoutMin = 30)
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$env:CIPHER_ROOT = $Root; $env:CIPHER_LAB_CHAR = $Char; $env:CIPHER_LAB_DIST = "$Dist"; $env:CIPHER_LAB_DUMMY = $Dummy; $env:CIPHER_LAB_SA = "$SA"
Get-ChildItem "$Root\logs" -Filter "combo_lab_${Char}_d${Dist}_s*.log" -ErrorAction SilentlyContinue | Remove-Item
$procs = @()
for ($i = 0; $i -lt $Shards; $i++) {
	$env:CIPHER_LAB_SHARD = "$i/$Shards"
	$procs += Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\combo_lab.lua" -WorkingDirectory (Split-Path $Exe) -PassThru -WindowStyle Minimized
	Start-Sleep -Milliseconds 400
}
$t0 = Get-Date
while (((Get-Date) - $t0).TotalMinutes -lt $TimeoutMin) {
	Start-Sleep 5
	$done = 0
	for ($i = 0; $i -lt $Shards; $i++) {
		$f = "$Root\logs\combo_lab_${Char}_d${Dist}_s$i.log"
		if ((Test-Path $f) -and (Select-String -Path $f -Pattern "DONE" -Quiet)) { $done++ }
	}
	if ($done -eq $Shards) { break }
}
$procs | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
"tiempo total: {0:N0}s" -f ((Get-Date) - $t0).TotalSeconds
python -I "$Root\tools\merge_combos.py" "$Root\data\sfiii3\combos\parts" $Char $Dist "$Root\data\sfiii3\combos\${Char}_d${Dist}.lua"
Get-ChildItem "$Root\logs" -Filter "combo_lab_${Char}_d${Dist}_s*.log" | ForEach-Object { Select-String -Path $_.FullName -Pattern "DONE" | ForEach-Object Line }
