"""Cambia el script de la ventana de Lua abierta de un proceso fcadefbneo y lo ejecuta (Run/Restart)."""
import ctypes
import os
import sys
import time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cipher_console as cc  # noqa: E402

u = cc.user32
pid, script = int(sys.argv[1]), sys.argv[2]
dlg = next((h for h in cc.top_windows() if cc.pid_of(h) == pid and cc.class_name(h) == "#32770"), None)
if not dlg:
    print("sin ventana de Lua")
    sys.exit(1)
kids = cc.children(dlg)
btn = lambda name: next((c for c in kids if cc.class_name(c).lower() == "button" and cc.window_text(c).replace("&", "").lower() == name), None)
stop = btn("stop")
if stop:
    u.SendMessageW(stop, cc.BM_CLICK, 0, 0)
    time.sleep(0.3)
edit = next((c for c in kids if cc.class_name(c).lower() == "edit" and not (u.GetWindowLongW(c, -16) & 4)), None)
u.SendMessageW(edit, cc.WM_SETTEXT, 0, ctypes.c_wchar_p(script))
time.sleep(0.2)
kids = cc.children(dlg)
run = next((c for c in kids if cc.class_name(c).lower() == "button" and cc.window_text(c).replace("&", "").lower() in ("run", "restart")), None)
u.SendMessageW(run, cc.BM_CLICK, 0, 0)
print("ejecutado:", script)
