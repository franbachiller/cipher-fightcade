# Netplay local: dos fcadefbneo en quark:direct sobre 127.0.0.1.
# A (player 0 / P1) corre test_f0.lua -> cipher con bot ON en P1. B (player 1 / P2) solo observa.
param([int]$Seconds = 60)
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$Dir  = Split-Path $Exe
Remove-Item "$Root\logs\net_*.log" -ErrorAction SilentlyContinue

$env:CIPHER_ROOT = $Root
$env:CIPHER_AUTOSTART = "1"; $env:CIPHER_SIDE = "1"; $env:CIPHER_LUA = "$Root\cipher.lua"; $env:CIPHER_LOGNAME = "net_A"
$a = Start-Process $Exe -ArgumentList "quark:direct,sfiii3nr1,7000,127.0.0.1,7001,0,0,0", "$Root\tools\test_f0.lua" -WorkingDirectory $Dir -PassThru
$env:CIPHER_AUTOSTART = ""; $env:CIPHER_LOGNAME = "net_B"
$b = Start-Process $Exe -ArgumentList "quark:direct,sfiii3nr1,7001,127.0.0.1,7000,1,0,0", "$Root\tools\net_observer.lua" -WorkingDirectory $Dir -PassThru
Start-Sleep $Seconds
Stop-Process -Id $a.Id, $b.Id -Force -ErrorAction SilentlyContinue
Start-Sleep 1
"=== A (bot) ==="; Get-Content "$Root\logs\net_A.log" -ErrorAction SilentlyContinue | Select-Object -Last 12
"=== B (observer) ==="; Get-Content "$Root\logs\net_B.log" -ErrorAction SilentlyContinue | Select-Object -Last 12
