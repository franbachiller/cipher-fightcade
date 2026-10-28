param(
	[string]$Rom = "sfiii3nr1",
	[string]$State = "",          # ruta a .fs opcional (arranca dentro de la pelea)
	[switch]$Autostart,           # bot ON + debug desde el frame 0
	[int]$Side = 0                # 1/2 fuerza el lado controlado
)
$ErrorActionPreference = "Stop"
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$Lua  = Join-Path (Split-Path $PSScriptRoot -Parent) "cipher.lua"

$env:CIPHER_AUTOSTART = $(if ($Autostart) { "1" } else { "" })
$env:CIPHER_SIDE      = $(if ($Side -gt 0) { "$Side" } else { "" })

# FBNeo no quita comillas del cmdline: rutas sin espacios, sin comillas.
if ("$State$Lua" -match " ") { throw "Rutas con espacios no soportadas por fcadefbneo: $State $Lua" }
$args_ = @()
if ($State) { $args_ += $State } else { $args_ += $Rom }
$args_ += $Lua
Start-Process -FilePath $Exe -ArgumentList $args_ -WorkingDirectory (Split-Path $Exe) -PassThru
