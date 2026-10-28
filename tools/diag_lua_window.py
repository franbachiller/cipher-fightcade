"""Diagnóstico solo-lectura: ventanas del proceso fcadefbneo, texto de las ventanas de Lua (salida/errores), menú Lua."""
import ctypes
import os
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cipher_console as cc  # noqa: E402

u = cc.user32
pid = int(sys.argv[1])
WM_GETTEXT, WM_GETTEXTLENGTH = 0x000D, 0x000E


def get_text(h):
    n = u.SendMessageW(h, WM_GETTEXTLENGTH, 0, 0)
    b = ctypes.create_unicode_buffer(n + 1)
    u.SendMessageW(h, WM_GETTEXT, n + 1, b)
    return b.value


wins = []


@cc.EnumWindowsProc
def cb(h, _):
    if cc.pid_of(h) == pid:
        wins.append(h)
    return True


u.EnumWindows(cb, 0)
for h in wins:
    print("VENTANA", hex(h), cc.class_name(h), "visible=%d" % u.IsWindowVisible(h), repr(cc.window_text(h)[:90]))
    if cc.class_name(h) == "#32770":
        for c in cc.children(h):
            t = get_text(c)
            if t:
                print("   ", cc.class_name(c), repr(t[-400:]))
    m = u.GetMenu(h)
    if m:
        for i in range(u.GetMenuItemCount(m)):
            sub = u.GetSubMenu(m, i)
            b = ctypes.create_unicode_buffer(128)
            u.GetMenuStringW(m, i, b, 128, 0x400)
            if b.value.replace("&", "").lower().startswith("game") and sub:
                for j in range(u.GetMenuItemCount(sub)):
                    b2 = ctypes.create_unicode_buffer(128)
                    u.GetMenuStringW(sub, j, b2, 128, 0x400)
                    if "lua" in b2.value.lower():
                        st = u.GetMenuState(sub, j, 0x400)
                        print("   MENU", repr(b2.value), "gris=%s" % bool(st & 3))
