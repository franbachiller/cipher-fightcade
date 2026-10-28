# Desensambla la ROM de UMK3 con Ghidra headless (módulo TMS34010). Recibe direcciones de CPU (bit) o offsets.
#   pwsh -File tools\ghidra_disasm.ps1 -Bit 0xFFAF27C0 -Count 40
param([string]$Bit = "", [string]$Offset = "", [int]$Count = 40)
$g = "C:\Users\bachi\tools\ghidra_12.1.4_PUBLIC"
$env:JAVA_HOME = "C:\Users\bachi\tools\jdk-21"; $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$proj = "C:\Users\bachi\Desktop\CIPHER-Fightcade\data\umk3\ghidra"
if ($Bit) { $off = ([Convert]::ToUInt64($Bit.Replace("0x", ""), 16) - 0xFF800000) / 8 } else { $off = [Convert]::ToUInt64($Offset.Replace("0x", ""), 16) }
$hex = "0x{0:X}" -f [uint64]$off
& "$g\support\analyzeHeadless.bat" $proj umk3 -process umk3_program.bin -noanalysis -readOnly `
	-scriptPath "C:\Users\bachi\Desktop\CIPHER-Fightcade\tools\ghidra" -postScript DisasmAt.java $hex $Count 2>&1 |
	ForEach-Object { "$_" } | Where-Object { $_ -match 'DisasmAt\.java> ' } |
	ForEach-Object { ($_ -replace '^.*DisasmAt\.java> ', '') -replace '\s*\(GhidraScript\)\s*$', '' }
