# Cadena completa del laboratorio para una lista de personajes: nivel 1, chains, nivel 2, nivel 2 chain, nivel 3.
param([string[]]$Chars)
$Pool = Join-Path $PSScriptRoot "combo_lab_pool.ps1"
$t0 = Get-Date
& $Pool -Chars $Chars -Level 1 -Workers 12 -PerChar 6 -TimeoutMin 15 | Select-String "combos ->"
& $Pool -Chars $Chars -Level 1 -Mode chain -Workers 12 -PerChar 6 -TimeoutMin 15 | Select-String "combos ->"
& $Pool -Chars $Chars -Level 2 -NoLinks -Workers 12 -PerChar 6 -TimeoutMin 15 | Select-String "combos ->"
& $Pool -Chars $Chars -Level 2 -Mode chain -Workers 12 -PerChar 6 -TimeoutMin 15 | Select-String "combos ->"
& $Pool -Chars $Chars -Level 3 -NoLinks -Workers 12 -PerChar 6 -TimeoutMin 15 | Select-String "combos ->"
"TOTAL CHARS {0:N0}s" -f ((Get-Date) - $t0).TotalSeconds
