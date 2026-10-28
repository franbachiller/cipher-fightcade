# Corre el lab de inputs (tools\test_inputs.lua) para varios personajes en paralelo y muestra cada log.
param([string[]]$Chars = @("ken", "chunli", "sean", "dudley", "oro", "alex"), [int]$Seconds = 150)
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$SA = @{ alex = 2; ryu = 1; yun = 3; dudley = 2; necro = 3; hugo = 1; ibuki = 1; elena = 2; oro = 2; yang = 2; ken = 3;
         sean = 2; urien = 3; gouki = 1; chunli = 2; makoto = 1; q = 3; twelve = 2; remy = 2 }
$procs = @()
foreach ($c in $Chars) {
	$env:CIPHER_P1 = $c; $env:CIPHER_P2 = "ryu"; $env:CIPHER_METER = "1"; $env:CIPHER_SA = "$($SA[$c])"
	$procs += Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\test_inputs.lua" -WorkingDirectory (Split-Path $Exe) -PassThru
	Start-Sleep 2
}
Start-Sleep $Seconds
$procs | ForEach-Object { Stop-Process -Id $_.Id -ErrorAction SilentlyContinue }
foreach ($c in $Chars) { "===== $c"; Get-Content "$Root\logs\test_inputs_$c.log" -ErrorAction SilentlyContinue }
