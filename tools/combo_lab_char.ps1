# Lab de combos de UN personaje repartido en N instancias: los 3 SA y la lista de combos partida en partes
# (CIPHER_WCL_ONLY + CIPHER_WCL_PART, slot de savestate propio por instancia). Al final junta las partes en
# data\sfiii3\combos\wiki\<char>_sa<N>_<dummy>.lua con tools\combo_lab_merge.py
param([string]$Char = "ryu", [int]$Instances = 9, [int]$TimeoutSec = 900, [string]$Dummy = "ryu")
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$txt = (Get-Content "$Root\data\sfiii3\wiki_combos.lua" -Raw) + "`n" + (Get-Content "$Root\data\sfiii3\super_combos.lua" -Raw) + "`n" + (Get-Content "$Root\data\sfiii3\wiki_combos_auto.lua" -Raw)
$body = ""
foreach ($m in [regex]::Matches($txt, '(?ms)^\t(\w+) = \{(.*?)^\t\},')) { if ($m.Groups[1].Value -eq $Char) { $body += $m.Groups[2].Value } }
$n = ([regex]::Matches($body, '(?m)^\t\t\{ "')).Count
$sas = @([regex]::Matches($body, 'sa = (\d)') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique)
if ($sas.Count -eq 0) { $sas = @(1) }
# savestate numerado por instancia (slots 1-9): el anónimo crashea FBNeo (Guru Meditation C0000005) -> máximo 9
$Instances = [math]::Min(9, $Instances)
$parts = [math]::Max(1, [math]::Floor($Instances / $sas.Count))
$slot = 0
"$Char : $n combos, SA $($sas -join ','), $parts partes por SA = $($parts * $sas.Count) instancias"
$running = @()
$first = $true
foreach ($sa in $sas) {
	for ($p = 0; $p -lt $parts; $p++) {
		$idx = @(1..$n | Where-Object { ($_ % $parts) -eq $p }) -join ","
		$env:CIPHER_WCL_CHAR = $Char; $env:CIPHER_WCL_SA = "$sa"; $env:CIPHER_WCL_DUMMY = $Dummy
		$env:CIPHER_WCL_BASE = $(if ($first) { "1" } else { "0" })
		$env:CIPHER_WCL_ONLY = $idx; $env:CIPHER_WCL_PART = "$p"; $slot++; $env:CIPHER_WCL_SLOT = "$slot"
		$env:CIPHER_ROOT = $Root
		$proc = Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\wiki_combo_lab.lua" -WorkingDirectory (Split-Path $Exe) -PassThru -WindowStyle Hidden
		$running += [pscustomobject]@{ p = $proc; t = Get-Date; sa = $sa; part = $p }
		Start-Sleep 1
	}
	$first = $false
}
while (@($running | Where-Object { -not $_.p.HasExited }).Count -gt 0) {
	Start-Sleep 3
	Get-Process fcadefbneo -ErrorAction SilentlyContinue | ForEach-Object { try { $_.PriorityClass = 'BelowNormal' } catch {} }
	foreach ($r in $running) { if (-not $r.p.HasExited -and ((Get-Date) - $r.t).TotalSeconds -gt $TimeoutSec) { Stop-Process -Id $r.p.Id -ErrorAction SilentlyContinue; "TIMEOUT sa$($r.sa) p$($r.part)" } }
}
$env:CIPHER_WCL_ONLY = ""; $env:CIPHER_WCL_PART = ""; $env:CIPHER_WCL_SLOT = ""
python -I "$Root\tools\combo_lab_merge.py" $Char $Dummy @($sas | ForEach-Object { "$_" }) $parts
