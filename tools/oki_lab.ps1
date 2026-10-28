# Laboratorio de okizeme: bot (P1) contra un rival quieto (P2), plan forzado y varios offsets K en paralelo.
# Resume HIT/WHIFF/BLOCK por K desde las líneas "oki-diag" del log.
param([string]$Char = "ken", [string]$Dummy = "ryu", [string]$Plan = "meaty", [int[]]$K = @(-1, 0, 1), [int]$Seconds = 90)
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$procs = @()
foreach ($k in $K) {
	$env:CIPHER_ROOT = $Root; $env:CIPHER_AUTOSTART = "1"; $env:CIPHER_SIDE = "1"; $env:CIPHER_OUTPUT = "lua"
	$env:CIPHER_BRAIN = "fundamentals"; $env:CIPHER_SPAR = ""; $env:CIPHER_P1 = $Char; $env:CIPHER_P2 = $Dummy
	$env:CIPHER_LOGNAME = "oki_${Char}_${Dummy}_k$k"; $env:CIPHER_FRESH = "1"; $env:CIPHER_TURBO = "1"; $env:CIPHER_ARCADE = ""
	$env:CIPHER_OKI_PLAN = $Plan; $env:CIPHER_OKI_K = "$k"; $env:CIPHER_OKI_TRACE = ""
	Remove-Item "$Root\logs\oki_${Char}_${Dummy}_k$k.log" -ErrorAction SilentlyContinue
	$procs += Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\eval.lua" -WorkingDirectory (Split-Path $Exe) -PassThru
	Start-Sleep 2
}
Start-Sleep $Seconds
$procs | ForEach-Object { Stop-Process -Id $_.Id -ErrorAction SilentlyContinue }
foreach ($k in $K) {
	$f = "$Root\logs\oki_${Char}_${Dummy}_k$k.log"
	$d = @(Select-String -Path $f -Pattern "oki-diag (\w+) ")
	$g = $d | ForEach-Object { $_.Matches[0].Groups[1].Value } | Group-Object | ForEach-Object { "$($_.Name)=$($_.Count)" }
	"K=$k  n=$($d.Count)  " + ($g -join " ")
}
Select-String -Path "$Root\logs\oki_${Char}_${Dummy}_k*.log" -Pattern "wake-learn" | ForEach-Object { ($_.Line -split "\] ")[1] } | Sort-Object -Unique
