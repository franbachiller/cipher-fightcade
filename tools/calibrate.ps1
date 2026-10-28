# Calibra el mapeo de teclas P1 del emulador -> tools\keymap.json (no tocar teclado/mouse ~10 s).
$Root = Split-Path $PSScriptRoot -Parent
$Exe  = "C:\Users\bachi\Documents\Fightcade\emulator\fbneo\fcadefbneo.exe"
$Out  = Join-Path $env:TEMP "cipher_pressed.txt"
$env:CIPHER_PROBE_OUT = $Out
$p = Start-Process $Exe -ArgumentList "sfiii3nr1", "$Root\tools\keymap_probe.lua" -WorkingDirectory (Split-Path $Exe) -PassThru
Start-Sleep 7
$ws = New-Object -ComObject WScript.Shell; $null = $ws.AppActivate($p.Id); Start-Sleep -Milliseconds 600
python -I "$Root\tools\cipher_keys.py" calibrate $Out
$rc = $LASTEXITCODE
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
exit $rc
