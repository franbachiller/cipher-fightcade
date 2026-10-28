# Arranca el bridge de teclas para jugar ONLINE con CIPHER (dejá esta ventana abierta).
# Después, en el fcadefbneo de Fightcade: Game > Lua Scripting > New Lua Script Window > cipher.lua > Run.
# El overlay debe mostrar "keys". Insert = ON/OFF, Home = lado (poné el tuyo), End = overlay, PageUp = debug.
$Root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path "$Root\tools\keymap.json")) {
	Write-Host "Falta tools\keymap.json: corré la calibración (ver README)." -ForegroundColor Red
	exit 1
}
python -I "$Root\tools\cipher_keys.py" serve
