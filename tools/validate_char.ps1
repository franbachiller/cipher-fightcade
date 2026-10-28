# Valida un personaje: pelea contra sparring + okizeme forzado contra rival quieto. Resume acciones, agarres y oki.
param([string]$Char = "hugo", [string]$Opp = "ryu", [int]$Seconds = 100, [string]$OkiPlan = "throw", [string]$Spar = "sparring")
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$env:CIPHER_ROOT = $Root; $env:CIPHER_AUTOSTART = "1"; $env:CIPHER_SIDE = "1"; $env:CIPHER_OUTPUT = "lua"
$env:CIPHER_BRAIN = "fundamentals"; $env:CIPHER_FRESH = "1"; $env:CIPHER_TURBO = "1"; $env:CIPHER_ARCADE = ""
$env:CIPHER_P1 = $Char; $env:CIPHER_P2 = $Opp
$env:CIPHER_SPAR = $Spar; $env:CIPHER_LOGNAME = "valc_${Char}_match"; $env:CIPHER_OKI_PLAN = ""
$a = Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\eval.lua" -WorkingDirectory (Split-Path $Exe) -PassThru
Start-Sleep 2
$env:CIPHER_SPAR = ""; $env:CIPHER_LOGNAME = "valc_${Char}_oki"; $env:CIPHER_OKI_PLAN = $OkiPlan
$b = Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\eval.lua" -WorkingDirectory (Split-Path $Exe) -PassThru
Start-Sleep $Seconds
Stop-Process -Id $a.Id, $b.Id -ErrorAction SilentlyContinue
foreach ($t in "match", "oki") {
	$f = "$Root\logs\valc_${Char}_$t.log"
	"===== $t"
	Select-String -Path $f -Pattern "error" | Select-Object -First 3 | ForEach-Object Line
	Select-String -Path $f -Pattern "bot: (.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value.Split(" ")[0..1] -join " " } |
		Group-Object | Sort-Object Count -Descending | Select-Object -First 15 Count, Name | Format-Table -AutoSize
	"agarres: " + ((Select-String -Path $f -Pattern "grab-diag ([A-Z]+)" | ForEach-Object { $_.Matches[0].Groups[1].Value } | Group-Object | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join " ")
	"tech: " + ((Select-String -Path $f -Pattern "tech-result ([A-Z]+)" | ForEach-Object { $_.Matches[0].Groups[1].Value } | Group-Object | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join " ")
	Select-String -Path $f -Pattern "tech-diag|tech-result" | Select-Object -First 10 | ForEach-Object { ($_.Line -split "\] ")[1] }
	"oki: " + ((Select-String -Path $f -Pattern "oki-diag ([A-Z]+)" | ForEach-Object { $_.Matches[0].Groups[1].Value } | Group-Object | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join " ")
	Select-String -Path $f -Pattern "grab-diag" | Select-Object -First 6 | ForEach-Object { ($_.Line -split "\] ")[1] }
	Select-String -Path $f -Pattern "ROUND" | ForEach-Object { $_.Line.Substring(10, 60) }
}
