@echo off
title CIPHER
mode con: cols=78 lines=34
python -c "import lupa.lua51" 2>nul || python -m pip install --quiet lupa
python -I "%~dp0tools\cipher_console.py"
pause
