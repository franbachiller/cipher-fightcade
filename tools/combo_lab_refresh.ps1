# Rehace los personajes incompletos y recalcula el nivel 2 para todo el plantel.
$Root = Split-Path $PSScriptRoot -Parent
$Pool = "$Root\tools\combo_lab_pool.ps1"
$d = "$Root\data\sfiii3\combos"
$all = @("alex","chunli","dudley","elena","gouki","hugo","ibuki","ken","makoto","necro","oro","q","remy","ryu","sean","twelve","urien","yang","yun")
$t0 = Get-Date
"== 1) nivel 1: elena, oro"; & $Pool -Chars @("elena","oro") -Level 1 -Workers 12 -PerChar 6 -TimeoutMin 15 | Select-String "combos ->|TOTAL"
"== 2) chains: elena, makoto, oro, alex"; & $Pool -Chars @("elena","makoto","oro","alex") -Level 1 -Mode chain -Workers 12 -PerChar 3 -TimeoutMin 15 | Select-String "combos ->|TOTAL"
"== 3) nivel 2 (prefijos -> especial/super)"
Get-ChildItem $d -Filter "*_d60_L2.lua" | Remove-Item
$chars = $all | Where-Object { $n = 0; foreach ($f in @("$d\$($_)_d60.lua", "$d\$($_)_d60_chain.lua")) { if (Test-Path $f) { $n += @(Select-String -Path $f -Pattern 'kind = "(link|chain)"').Count } }; $n -gt 0 }
& $Pool -Chars $chars -Level 2 -NoLinks -Workers 12 -PerChar 6 -TimeoutMin 20 | Select-String "combos ->|TOTAL"
"TOTAL REFRESH {0:N0}s" -f ((Get-Date) - $t0).TotalSeconds
