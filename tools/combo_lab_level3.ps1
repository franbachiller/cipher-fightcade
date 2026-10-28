# Nivel 3: (a) cadenas de 2 normales + tercer normal en chain; (b) cadenas de 3 normales -> especial/super.
$Root = Split-Path $PSScriptRoot -Parent
$Pool = "$Root\tools\combo_lab_pool.ps1"
$d = "$Root\data\sfiii3\combos"
$all = @("alex","chunli","dudley","elena","gouki","hugo","ibuki","ken","makoto","necro","oro","q","remy","ryu","sean","twelve","urien","yang","yun")
function WithPrefixes($files) {
	$all | Where-Object { $c = $_; $n = 0; foreach ($f in $files) { $p = "$d\$c$f"; if (Test-Path $p) { $n += @(Select-String -Path $p -Pattern 'kind = "(link|chain)"').Count } }; $n -gt 0 }
}
$t0 = Get-Date
$c2 = @(WithPrefixes @("_d60.lua", "_d60_chain.lua"))
"== a) nivel 2 chain: $($c2 -join ', ')"
& $Pool -Chars $c2 -Level 2 -Mode chain -Workers 12 -PerChar 6 -TimeoutMin 20 | Select-String "combos ->|TOTAL"
$c3 = @(WithPrefixes @("_d60_L2.lua", "_d60_L2_chain.lua"))
"== b) nivel 3 (-> especial/super): $($c3 -join ', ')"
if ($c3.Count -gt 0) { & $Pool -Chars $c3 -Level 3 -NoLinks -Workers 12 -PerChar 6 -TimeoutMin 20 | Select-String "combos ->|TOTAL" }
"TOTAL NIVEL 3 {0:N0}s" -f ((Get-Date) - $t0).TotalSeconds
