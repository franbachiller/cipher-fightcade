"""CIPHER Console: detecta SF3 en Fightcade y juega solo, desde FUERA del emulador.

  python -I tools\\cipher_console.py        (o doble clic en CIPHER.bat)

- Busca ventanas de fcadefbneo con "3rd Strike" en el título y se engancha al proceso (tools\\cipher_ext.py):
  lee la RAM de CPS3 con ReadProcessMemory, corre cipher.lua en un Lua 5.1 embebido y aprieta las teclas
  con SendInput. No usa la ventana de Lua del emulador: online (quark:served) Fightcade no corre hooks de Lua.
- El lado (P1/P2) se detecta solo comparando nuestras teclas con el input que leyó el juego.
- Insert (en el emulador o en esta consola) pausa / reactiva el bot.
"""
import ctypes
import ctypes.wintypes as wt
import os
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import cipher_keys as ck  # noqa: E402  (SendInput, keymap)
import cipher_ext as ce  # noqa: E402  (runtime externo: RAM + Lua embebido)

CIPHER_LUA = os.path.join(ROOT, "cipher.lua")
user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

WM_COMMAND, WM_SETTEXT, WM_GETTEXT, BM_CLICK = 0x0111, 0x000C, 0x000D, 0x00F5
SW_MINIMIZE = 6

# ------------------------------------------------------------------ consola
RED, DIM, BOLD, RST, GRN, YEL, CYN, WHT = "\x1b[91m", "\x1b[90m", "\x1b[1m", "\x1b[0m", "\x1b[92m", "\x1b[93m", "\x1b[96m", "\x1b[97m"
BANNER = r"""
   ██████╗██╗██████╗ ██╗  ██╗███████╗██████╗
  ██╔════╝██║██╔══██╗██║  ██║██╔════╝██╔══██╗
  ██║     ██║██████╔╝███████║█████╗  ██████╔╝
  ██║     ██║██╔═══╝ ██╔══██║██╔══╝  ██╔══██╗
  ╚██████╗██║██║     ██║  ██║███████╗██║  ██║
   ╚═════╝╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"""


def enable_vt():
    h = kernel32.GetStdHandle(-11)
    mode = wt.DWORD()
    if kernel32.GetConsoleMode(h, ctypes.byref(mode)):
        kernel32.SetConsoleMode(h, mode.value | 0x0004)
    os.system("")  # activa VT en consolas viejas
    kernel32.SetConsoleTitleW("CIPHER")
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


STATE = {"emu": "buscando Fightcade / SF3 ...", "inject": "-", "link": "esperando emulador",
         "bot": "-", "side": "-", "chars": "-", "act": "-", "round": "-", "events": []}
LOCK = threading.Lock()


def event(msg):
    with LOCK:
        STATE["events"].append(time.strftime("%H:%M:%S ") + msg)
        STATE["events"] = STATE["events"][-6:]


def render():
    with LOCK:
        st = dict(STATE)
        ev = list(STATE["events"])
    bot = st["bot"]
    bot_col = GRN if bot.startswith("ON") else (YEL if bot.startswith("OFF") else DIM)
    lines = ["\x1b[H\x1b[2J", RED + BOLD + BANNER + RST,
             DIM + "   street fighter III 3rd strike  ·  fightcade autopilot" + RST, ""]

    def row(k, v, col=WHT):
        lines.append(f"   {DIM}{k:<12}{RST} {col}{v}{RST}")

    row("emulador", st["emu"])
    row("motor", st["inject"])
    row("enlace", st["link"], GRN if st["link"].startswith("enganchado") else YEL)
    lines.append("")
    row("bot", bot, bot_col)
    row("lado", st["side"], CYN)
    row("pelea", st["chars"])
    row("round", st["round"])
    row("acción", st["act"])
    lines.append("")
    lines.append(f"   {DIM}Insert{RST} pausa/reactiva   {DIM}Home{RST} cambia lado   {DIM}End{RST} overlay   {DIM}Ctrl+C{RST} salir")
    lines.append("")
    for e in ev:
        lines.append(f"   {DIM}{e}{RST}")
    sys.stdout.write("\n".join(lines) + "\n")
    sys.stdout.flush()


# ------------------------------------------------------------------ win32: inyección
EnumWindowsProc = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)


def window_text(h):
    n = user32.GetWindowTextLengthW(h)
    b = ctypes.create_unicode_buffer(n + 1)
    user32.GetWindowTextW(h, b, n + 1)
    return b.value


def class_name(h):
    b = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(h, b, 256)
    return b.value


def pid_of(h):
    p = wt.DWORD()
    user32.GetWindowThreadProcessId(h, ctypes.byref(p))
    return p.value


def top_windows():
    out = []

    @EnumWindowsProc
    def cb(h, _):
        if user32.IsWindowVisible(h):
            out.append(h)
        return True
    user32.EnumWindows(cb, 0)
    return out


def children(h):
    out = []

    @EnumWindowsProc
    def cb(c, _):
        out.append(c)
        return True
    user32.EnumChildWindows(h, cb, 0)
    return out


def find_menu_id(hmenu, wanted):
    n = user32.GetMenuItemCount(hmenu)
    for i in range(max(n, 0)):
        b = ctypes.create_unicode_buffer(256)
        user32.GetMenuStringW(hmenu, i, b, 256, 0x400)
        txt = b.value.replace("&", "")
        sub = user32.GetSubMenu(hmenu, i)
        if sub:
            r = find_menu_id(sub, wanted)
            if r is not None:
                return r
        elif txt.lower().startswith(wanted):
            return user32.GetMenuItemID(hmenu, i)
    return None


def inject(hwnd, pid):
    hmenu = user32.GetMenu(hwnd)
    if not hmenu:
        return False, "sin menú"
    cmd = find_menu_id(hmenu, "new lua script window")
    if cmd is None:
        return False, "no encontré 'New Lua Script Window'"
    before = {h for h in top_windows() if pid_of(h) == pid}
    user32.PostMessageW(hwnd, WM_COMMAND, cmd, 0)
    dlg = None
    for _ in range(40):
        time.sleep(0.1)
        for h in top_windows():
            if pid_of(h) == pid and h not in before and class_name(h) == "#32770":
                dlg = h
                break
        if dlg:
            break
    if not dlg:
        return False, "no apareció la ventana de Lua"
    # la ventana tiene la ruta (edit de una línea) y la salida (multilínea): usar la de una línea
    GWL_STYLE, ES_MULTILINE = -16, 0x0004
    edits = [c for c in children(dlg) if class_name(c).lower() == "edit"]
    edit = next((c for c in edits if not (user32.GetWindowLongW(c, GWL_STYLE) & ES_MULTILINE)), edits[0] if edits else None)
    run = next((c for c in children(dlg) if class_name(c).lower() == "button" and window_text(c).replace("&", "").lower() == "run"), None)
    if not edit or not run:
        return False, "controles de la ventana de Lua no encontrados"
    user32.SendMessageW(edit, WM_SETTEXT, 0, ctypes.c_wchar_p(CIPHER_LUA))
    time.sleep(0.15)
    user32.SendMessageW(run, BM_CLICK, 0, 0)
    time.sleep(0.3)
    user32.ShowWindow(dlg, SW_MINIMIZE)
    user32.SetForegroundWindow(hwnd)
    return True, "ok"


def injector_loop():
    done = {}
    while True:
        try:
            found = None
            for h in top_windows():
                t = window_text(h)
                if "FBNeo" in t and "3rd Strike" in t:
                    found = (h, pid_of(h), t)
                    break
            if found:
                h, pid, t = found
                with LOCK:
                    STATE["emu"] = "SF3 3rd Strike detectado (pid %d)" % pid
                if pid not in done:
                    time.sleep(1.0)  # dejar que termine de cargar
                    ok, why = inject(h, pid)
                    done[pid] = ok
                    with LOCK:
                        STATE["inject"] = "cipher.lua cargado" if ok else ("error: " + why)
                    event("script cargado en el emulador" if ok else "no pude cargar el script: " + why)
            else:
                with LOCK:
                    STATE["emu"] = "buscando Fightcade / SF3 ..."
                    STATE["inject"] = "-"
                done = {p: v for p, v in done.items() if any(pid_of(w) == p for w in top_windows())}
        except Exception as e:  # nunca matar la consola por un error de UI
            event("injector: %s" % e)
        time.sleep(1.0)


# ------------------------------------------------------------------ pipe: inputs + estado
def handle_status(line):
    kv = {}
    for part in line[1:].split("|"):
        if "=" in part:
            k, v = part.split("=", 1)
            kv[k.strip()] = v.strip()
    with LOCK:
        if "bot" in kv:
            new = "ON  (jugando)" if kv["bot"] == "on" else "OFF (pausado: Insert para reactivar)"
            if STATE["bot"] != new and STATE["bot"] != "-":
                STATE["events"].append(time.strftime("%H:%M:%S ") + ("bot activado" if kv["bot"] == "on" else "bot pausado"))
            STATE["bot"] = new
        if "side" in kv:
            STATE["side"] = "P" + kv["side"] + (" (detectado · input delay %s f)" % kv.get("dl", "?") if kv.get("auto") == "1" else "  (detectando...)")
        if "me" in kv and "op" in kv:
            sa = kv.get("sa", "-")
            STATE["chars"] = f"{kv['me']}  vs  {kv['op']}" + (f"   ({sa})" if sa not in ("-", "") else "")
        if "act" in kv:
            STATE["act"] = kv["act"][:60]
        if "hp" in kv:
            STATE["round"] = kv["hp"]
        if "msg" in kv and kv["msg"] != STATE.get("last_msg"):
            STATE["last_msg"] = kv["msg"]
            STATE["events"].append(time.strftime("%H:%M:%S ") + kv["msg"])
        STATE["events"] = STATE["events"][-6:]


def find_sf3():
    """Ventana de SF3 en fcadefbneo; con varias abiertas, la que tiene el foco."""
    fg = user32.GetForegroundWindow()
    found = []
    for h in top_windows():
        t = window_text(h)
        if "FBNeo" in t and "3rd Strike" in t:
            found.append((h, pid_of(h), t))
    for f in found:
        if f[0] == fg:
            return f
    return found[0] if len(found) == 1 else None    # varias y ninguna con foco: esperar a que elijas una


def ext_loop():
    """Modo externo: engancharse al emulador y correr el bot desde acá (online y offline)."""
    failed = set()
    while True:
        try:
            found = find_sf3()
            if not found:
                with LOCK:
                    STATE.update(emu="buscando Fightcade / SF3 ...", inject="-", link="esperando emulador", bot="-")
                time.sleep(1.0)
                continue
            h, pid, t = found
            if pid in failed:
                time.sleep(2.0)
                continue
            with LOCK:
                STATE["emu"] = "SF3 3rd Strike detectado (pid %d)" % pid
            try:
                rt = ce.ExtRuntime(pid, on_status=handle_status, on_event=event)
            except ce.AttachError as e:
                failed.add(pid)
                with LOCK:
                    STATE["inject"] = "error: %s" % e
                event("no pude engancharme: %s" % e)
                continue
            with LOCK:
                STATE["inject"] = "externo · RAM CPS3 @0x%X · Lua 5.1 embebido" % rt.ram
                STATE["link"] = "enganchado (lectura de RAM + SendInput)"
            event("enganchado al emulador: el bot arranca al empezar la pelea")
            rt.run()
            event("emulador cerrado (teclas liberadas) · %d frames jugados" % rt.frames)
        except Exception as e:  # nunca matar la consola
            event("motor: %s" % e)
            time.sleep(2.0)


def pipe_loop():
    scancodes = ck.load_keymap()
    while True:
        h = ck.kernel32.CreateNamedPipeW(ck.PIPE_NAME, ck.PIPE_ACCESS_INBOUND, ck.PIPE_TYPE_BYTE | ck.PIPE_WAIT, 1, 0, 4096, 0, None)
        if h == ck.INVALID_HANDLE:
            event("no pude crear el pipe (¿otra consola abierta?)")
            time.sleep(3)
            continue
        with LOCK:
            STATE["link"] = "esperando cipher.lua"
        ck.kernel32.ConnectNamedPipe(h, None)
        with LOCK:
            STATE["link"] = "conectado (inputs por SendInput)"
        event("cipher.lua conectado")
        cur, pending = 0, b""
        buf = ctypes.create_string_buffer(4096)
        n = wt.DWORD(0)
        try:
            while ck.kernel32.ReadFile(h, buf, 4096, ctypes.byref(n), None) and n.value:
                pending += buf.raw[:n.value]
                *lines, pending = pending.split(b"\n")
                mask = None
                for ln in lines:
                    ln = ln.strip()
                    if ln.startswith(b"#"):
                        handle_status(ln.decode("utf-8", "replace"))
                    elif ln:
                        try:
                            mask = int(ln)
                        except ValueError:
                            pass
                if mask is not None and mask != cur:
                    diff = mask ^ cur
                    ck.send_keys([(scancodes[i], bool(mask >> i & 1)) for i in range(len(ck.BITS)) if diff >> i & 1])
                    cur = mask
        finally:
            if cur:
                ck.send_keys([(scancodes[i], False) for i in range(len(ck.BITS)) if cur >> i & 1])
            ck.kernel32.DisconnectNamedPipe(h)
            ck.kernel32.CloseHandle(h)
            with LOCK:
                STATE["link"] = "desconectado"
                STATE["bot"] = "-"
            event("cipher.lua desconectado (teclas liberadas)")


def single_instance():
    """Una sola consola a la vez (mutex de Windows). Dos consolas mandando teclas al mismo emulador se pisan (una
    aprieta, la otra suelta cada frame) y Fightcade lo ve como TURBO."""
    k32 = ctypes.windll.kernel32
    k32.CreateMutexW.restype = wt.HANDLE
    h = k32.CreateMutexW(None, True, "Global\\CIPHER_Console_SF3")
    if k32.GetLastError() == 183:                # ERROR_ALREADY_EXISTS
        return None
    return h


def main():
    enable_vt()
    lock = single_instance()
    if lock is None:
        print(RED + "Ya hay una consola de CIPHER abierta: cerrala antes de abrir otra (dos a la vez = alerta de turbo)."
              + RST)
        time.sleep(5)
        return
    if not os.path.exists(ck.KEYMAP_PATH):
        print(RED + "Falta tools\\keymap.json: corré tools\\calibrate.ps1 una vez." + RST)
        return
    threading.Thread(target=ext_loop, daemon=True).start()
    event("CIPHER listo: abrí una partida de SF3 3rd Strike en Fightcade")
    try:
        while True:
            render()
            time.sleep(0.5)
    except KeyboardInterrupt:
        sys.stdout.write(RST + "\nCIPHER cerrado.\n")


if __name__ == "__main__":
    main()
