# Lab de juggles en paralelo (tools\juggle_lab.lua): un emulador oculto por personaje con su SA de data\sfiii3\sa_pick.lua,
# prioridad baja, savestate propio por slot. Cada corrida sigue desde lo ya probado (iterativo entre corridas).
param([string[]]$Chars = @("gouki", "ken", "ryu", "chunli", "yun", "dudley", "sean", "remy"), [int]$Budget = 170, [switch]$Corner)
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
if (Get-Process fcadefbneo -ErrorAction SilentlyContinue) { "hay un fcadefbneo abierto (¿jugando online?): no lanzo nada"; exit 1 }
$pick = @{}
foreach ($m in [regex]::Matches((Get-Content "$Root\data\sfiii3\sa_pick.lua" -Raw), '\["(\w+)"\] = (\d)')) { $pick[$m.Groups[1].Value] = $m.Groups[2].Value }
$procs = @()
$slot = 1
foreach ($c in $Chars | Select-Object -First 8) {
	$env:CIPHER_JL_CHAR = $c; $env:CIPHER_JL_SA = $(if ($pick[$c]) { $pick[$c] } else { "1" })
	$env:CIPHER_JL_SLOT = "$slot"; $env:CIPHER_JL_BUDGET = "$Budget"; $env:CIPHER_JL_CORNER = $(if ($Corner) { "1" } else { "0" })
	$procs += Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\juggle_lab.lua" -WorkingDirectory (Split-Path $Exe) -PassThru -WindowStyle Hidden
	$slot++
	Start-Sleep 1
}
$t0 = Get-Date
while (@($procs | Where-Object { -not $_.HasExited }).Count -gt 0) {
	Start-Sleep 3
	Get-Process fcadefbneo -ErrorAction SilentlyContinue | ForEach-Object { try { $_.PriorityClass = 'BelowNormal' } catch {} }
	if (((Get-Date) - $t0).TotalSeconds -gt $Budget + 90) { $procs | Where-Object { -not $_.HasExited } | ForEach-Object { Stop-Process -Id $_.Id -ErrorAction SilentlyContinue } }
}
"{0:N0} s" -f ((Get-Date) - $t0).TotalSeconds
foreach ($c in $Chars | Select-Object -First 8) {
	$sa = $(if ($pick[$c]) { $pick[$c] } else { "1" })
	"===== $c sa$sa"
	Get-Content "$Root\logs\juggle_lab_${c}_sa$sa$(if ($Corner) { "_corner" }).log" -ErrorAction SilentlyContinue | Where-Object { $_ -match '^(OK|FIN|ERROR|char)' }
}
