# Validación rápida del brain: meaty vs el rival que se levanta más rápido + pelea completa vs sparring.
param([int]$Seconds = 100)
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$env:CIPHER_ROOT = $Root; $env:CIPHER_AUTOSTART = "1"; $env:CIPHER_SIDE = "1"; $env:CIPHER_OUTPUT = "lua"
$env:CIPHER_BRAIN = "fundamentals"; $env:CIPHER_FRESH = "1"; $env:CIPHER_TURBO = "1"; $env:CIPHER_ARCADE = ""
$env:CIPHER_SPAR = ""; $env:CIPHER_P1 = "ken"; $env:CIPHER_P2 = "necro"; $env:CIPHER_LOGNAME = "val_oki_necro"; $env:CIPHER_OKI_PLAN = "meaty"
$a = Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\eval.lua" -WorkingDirectory (Split-Path $Exe) -PassThru
Start-Sleep 2
$env:CIPHER_OKI_PLAN = ""; $env:CIPHER_SPAR = "sparring"; $env:CIPHER_P1 = "chunli"; $env:CIPHER_P2 = "ryu"; $env:CIPHER_LOGNAME = "val_match"
$b = Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\eval.lua" -WorkingDirectory (Split-Path $Exe) -PassThru
Start-Sleep $Seconds
Stop-Process -Id $a.Id, $b.Id -ErrorAction SilentlyContinue
"--- meaty vs necro"
Select-String -Path "$Root\logs\val_oki_necro.log" -Pattern "oki-diag ([A-Z]+)" | ForEach-Object { $_.Matches[0].Groups[1].Value } | Group-Object | ForEach-Object { "$($_.Name)=$($_.Count)" }
"--- pelea chunli vs sparring"
Select-String -Path "$Root\logs\val_match.log" -Pattern "error" | Select-Object -First 3 | ForEach-Object Line
Select-String -Path "$Root\logs\val_match.log" -Pattern "bot: (.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value.Split(" ")[0..1] -join " " } |
	Group-Object | Sort-Object Count -Descending | Select-Object -First 22 Count, Name | Format-Table -AutoSize
Select-String -Path "$Root\logs\val_match.log" -Pattern "oki-diag ([A-Z]+)" | ForEach-Object { $_.Matches[0].Groups[1].Value } | Group-Object | ForEach-Object { "oki $($_.Name)=$($_.Count)" }
Select-String -Path "$Root\logs\val_match.log" -Pattern "ROUND" | ForEach-Object { $_.Line.Substring(10, 70) }
