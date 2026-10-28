"""Prueba la inyección de cipher.lua en una ventana de fcadefbneo ya abierta (sin pipe ni consola)."""
import os
import sys
import time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cipher_console as cc  # noqa: E402

for _ in range(30):
    for h in cc.top_windows():
        t = cc.window_text(h)
        if "FBNeo" in t and "3rd Strike" in t:
            pid = cc.pid_of(h)
            print("ventana:", t[:80], "pid", pid)
            dlg_ok, why = cc.inject(h, pid)
            print("inject:", dlg_ok, why)
            sys.exit(0 if dlg_ok else 1)
    time.sleep(1)
print("no encontré la ventana")
sys.exit(2)
