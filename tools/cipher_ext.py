"""CIPHER externo: corre el cerebro Lua FUERA del emulador.

- Lee la RAM principal de CPS3 (0x02000000, 512 KB) de fcadefbneo.exe con ReadProcessMemory.
    RamMain   = *(u32*)(exe + RVA_RAMPTR)      dwords en orden nativo: byte A está en (A - 0x02000000) ^ 3
    framecount =  (u32 )(exe + RVA_FRAME)      == emu.framecount(); sube al EMPEZAR cada frame (~1.5 ms antes de terminarlo)
- Corre cipher.lua en Lua 5.1 embebido (lupa) con core\\ext_shim.lua (API de FBNeo emulada).
- Inputs por SendInput (scancodes de keymap.json): entran antes de GGPO, válidos online.
Online (quark:served) Fightcade no ejecuta hooks de Lua dentro del emulador: así no los necesitamos.
"""
import array
import ctypes
import os
import struct
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import cipher_keys as ck  # noqa: E402
from procmem import Proc  # noqa: E402

# fcadefbneo.exe de Fightcade (32 bits, ASLR). Hallado con tools\re_ramfind.py + tools\probe_ramfind.lua.
EXE_NAME = "fcadefbneo.exe"
RVA_RAMPTR = 0x6B788F4
RVA_FRAME = 0x2D21B2C
RVA_FRAME_ALT = 0x2D72E38
RAM0, RAM_SIZE = 0x02000000, 0x80000
PLAYERS_OFF, PLAYERS_LEN = 0x68C00, 0xB00
# ROM de usuario de CPS3 (0x06000000): ahí apuntan las cajas de ataque/empuje/agarre (tools\re_romfind.py)
ROM0, ROM_SIZE = 0x06000000, 0x01000000
RVA_ROMPTR = 0x6B788C0  # puntero a la ROM de usuario (re_romfind.py; al lado de RamMain 0x6B788F4)
ROM_XOR = 3          # P1 0x02068C6C / P2 0x02069104: bloque para detectar fin de frame

user32 = ctypes.WinDLL("user32", use_last_error=True)
ctypes.WinDLL("winmm").timeBeginPeriod(1)
kernel32 = ctypes.WinDLL("kernel32")
kernel32.GetConsoleWindow.restype = ctypes.c_void_p
user32.GetForegroundWindow.restype = ctypes.c_void_p
user32.GetWindowThreadProcessId.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong)]

VK = {"insert": 0x2D, "home": 0x24, "end": 0x23, "pageup": 0x21, "pagedown": 0x22, "delete": 0x2E}


class AttachError(Exception):
    pass


class ExtRuntime:
    def __init__(self, pid, on_status=None, on_event=None, rom="sfiii3nr1"):
        self.pid = pid
        self.on_status = on_status or (lambda line: None)
        self.on_event = on_event or (lambda msg: None)
        self.p = Proc(pid)
        base, size = self.p.module(EXE_NAME)
        if not base:
            raise AttachError("no encontré %s en el pid %d" % (EXE_NAME, pid))
        self.exe = base
        ptr = self.p.read(base + RVA_RAMPTR, 4)
        self.ram = struct.unpack("<I", ptr)[0] if ptr else 0
        if not self.ram or self.p.read(self.ram, RAM_SIZE) is None:
            raise AttachError("RAM de CPS3 no accesible (¿versión de fcadefbneo distinta? correr tools\\re_ramfind.py)")
        self.fc_addr = base + RVA_FRAME
        rp = self.p.read(base + RVA_ROMPTR, 4) if RVA_ROMPTR else None
        self.rom_base = struct.unpack("<I", rp)[0] if rp else 0
        self.rom_cache = {}
        self.scancodes = ck.load_keymap()
        self.cur_mask = self.want_mask = 0
        self.console_hwnd = kernel32.GetConsoleWindow()
        self.frames = self.skipped = 0
        self.ms_sum = self.ms_max = 0.0
        self.lua = None
        self.rom = rom

    # ---------------------------------------------------------------- memoria
    def framecount(self):
        b = self.p.read(self.fc_addr, 4)
        return struct.unpack("<I", b)[0] if b else None

    def ram_linear(self):
        raw = self.p.read(self.ram, RAM_SIZE)
        if raw is None:
            return None
        a = array.array("I")
        a.frombytes(raw)
        a.byteswap()                 # dwords nativos -> bytes big-endian lineales (como los ve el SH-2)
        return a.tobytes()

    def wait_frame_end(self, fc):
        """El contador sube al empezar el frame: esperar a que la emulación termine (RAM de jugadores estable)."""
        t0 = time.perf_counter()
        prev = None
        while True:
            time.sleep(0.0005)
            now = time.perf_counter()
            f2 = self.framecount()
            if f2 is None:
                return None
            if f2 != fc:                       # arrancó otro frame (catch-up / rollback): seguir al último
                fc, t0, prev = f2, now, None
                continue
            blk = self.p.read(self.ram + PLAYERS_OFF, PLAYERS_LEN)
            el = now - t0
            if (el >= 0.002 and blk == prev) or el >= 0.007:
                return fc
            prev = blk

    # ---------------------------------------------------------------- ROM (cajas de ataque / empuje / agarre)
    def rom_byte(self, addr):
        """byte en 0x06000000+ (ROM de usuario, estática): lectura del proceso con caché por página de 4 KB"""
        if not self.rom_base or addr < ROM0 or addr >= ROM0 + ROM_SIZE:
            return 0
        off = (addr - ROM0) ^ ROM_XOR
        page = off & ~0xFFF
        data = self.rom_cache.get(page)
        if data is None:
            data = self.p.read(self.rom_base + page, 0x1000) or bytes(0x1000)
            self.rom_cache[page] = data
        return data[off & 0xFFF]

    # ---------------------------------------------------------------- teclas
    def keys(self):
        fg = user32.GetForegroundWindow()
        pid = ctypes.c_ulong(0)
        user32.GetWindowThreadProcessId(fg, ctypes.byref(pid))
        if pid.value != self.pid and fg != self.console_hwnd:
            return b""
        return ",".join(k for k, vk in VK.items() if user32.GetAsyncKeyState(vk) & 0x8000).encode()

    def sink(self, data):
        for ln in bytes(data).split(b"\n"):
            ln = ln.strip()
            if not ln:
                continue
            if ln.startswith(b"#"):
                self.on_status(ln.decode("utf-8", "replace"))
                continue
            try:
                mask = int(ln)
            except ValueError:
                continue
            self.set_mask(mask)

    def emu_focused(self):
        fg = user32.GetForegroundWindow()
        pid = ctypes.c_ulong(0)
        user32.GetWindowThreadProcessId(fg, ctypes.byref(pid))
        return pid.value == self.pid

    def set_mask(self, mask):
        self.want_mask = mask
        if not self.emu_focused():          # alt-tab: nunca escribir teclas en otra ventana
            mask = 0
        diff = mask ^ self.cur_mask
        if diff:
            ck.send_keys([(self.scancodes[i], bool(mask >> i & 1)) for i in range(len(ck.BITS)) if diff >> i & 1])
            self.cur_mask = mask

    # ---------------------------------------------------------------- lua
    def load(self):
        from lupa.luajit21 import LuaRuntime      # LuaJIT: librería bit (effie) y más velocidad
        lua = LuaRuntime(encoding=None, unpack_returned_tuples=True)
        py = lua.table_from({b"keys": self.keys, b"sink": self.sink, b"rom": self.rom.encode(), b"rom_byte": self.rom_byte})
        g = lua.globals()
        g[b"EXT_LATENCY"] = int(os.environ.get("CIPHER_LATENCY", "0"))
        # un log por sesión, nunca se pisa: logs\online\<fecha_hora>.log
        os.makedirs(os.path.join(ROOT, "logs", "online"), exist_ok=True)
        os.environ.setdefault("CIPHER_LOGNAME", "online\\" + time.strftime("%Y-%m-%d_%H%M%S"))
        run = lua.eval(b"function(path, arg) local f = assert(loadfile(path)) return f(arg) end")
        run(os.path.join(ROOT, "core", "ext_shim.lua").encode(), py)
        cwd = os.getcwd()
        os.chdir(os.path.join(ROOT, "third_party", "effie3rd__3rd_training_lua"))   # effie lee archivos relativos
        try:
            run(os.path.join(ROOT, "cipher.lua").encode(), None)
        finally:
            os.chdir(cwd)
        self.lua = lua
        self.frame_fn = g[b"__ext_frame"]
        self.exit_fn = g[b"__ext_exit"]

    def run(self, stop=lambda: False):
        """Bucle de frames hasta que el emulador se cierre o stop() sea verdadero."""
        if not self.lua:
            self.load()
        last = self.framecount()
        errors = 0
        try:
            while not stop():
                fc = self.framecount()
                if fc is None or not self.p.alive():
                    break
                if fc == last:
                    time.sleep(0.0005)
                    continue
                fc = self.wait_frame_end(fc)
                if fc is None:
                    break
                t0 = time.perf_counter()
                ram = self.ram_linear()
                if ram is None:
                    break
                if last is not None and fc - last > 1:
                    self.skipped += fc - last - 1
                last = fc
                if self.cur_mask != self.want_mask and self.emu_focused():
                    self.set_mask(self.want_mask)           # volvió el foco: reaplicar lo que el bot quiere
                elif self.cur_mask and not self.emu_focused():
                    self.set_mask(self.want_mask)           # perdió el foco: soltar
                try:
                    self.frame_fn(ram, fc)
                    self.frames += 1
                    ms = (time.perf_counter() - t0) * 1000
                    self.ms_sum += ms
                    self.ms_max = max(self.ms_max, ms)
                except Exception as e:  # error de Lua fuera del brain: avisar y seguir
                    errors += 1
                    if errors <= 5 or errors % 600 == 0:
                        self.on_event("lua: %s" % str(e).splitlines()[0][:120])
        finally:
            self.shutdown()

    def shutdown(self):
        if self.cur_mask:
            self.set_mask(0)
        if self.lua:
            try:
                self.exit_fn()
            except Exception:
                pass
            self.lua = None
        self.p.close()


if __name__ == "__main__":
    # prueba directa: python -I tools\cipher_ext.py <pid>
    rt = ExtRuntime(int(sys.argv[1]), on_status=lambda s: print(s), on_event=lambda m: print("EV", m))
    print("RAM 0x%X fc %d" % (rt.ram, rt.framecount()))
    # pruebas: dar el foco a la ventana del emulador (si no, la protección de foco no manda teclas)
    import cipher_console as cc
    for h in cc.top_windows():
        if cc.pid_of(h) == rt.pid and "FBNeo" in cc.window_text(h):
            user32.SetForegroundWindow(h)
    limit = float(os.environ.get("CIPHER_EXT_SECONDS", "0") or 0)
    t_end = time.time() + limit if limit else None
    rt.run(stop=lambda: t_end is not None and time.time() > t_end)
    print("frames procesados: %d · saltados: %d · ms/frame avg %.2f max %.2f" % (
        rt.frames, rt.skipped, rt.ms_sum / max(1, rt.frames), rt.ms_max))
