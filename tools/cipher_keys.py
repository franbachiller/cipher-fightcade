"""CIPHER key bridge: recibe máscaras de input desde cipher.lua por named pipe y las
inyecta como scancodes (SendInput) para que entren por DirectInput ANTES de InputMake/GGPO.

Uso:
  python -I cipher_keys.py serve       # servidor del pipe (dejar corriendo mientras jugás)
  python -I cipher_keys.py calibrate   # descubre el mapeo P1 del emulador -> keymap.json

Protocolo: una línea ASCII por cambio de estado: "<mask>\\n". Bits (absolutos, ya resueltos por facing):
  0 up, 1 down, 2 left, 3 right, 4 lp, 5 mp, 6 hp, 7 lk, 8 mk, 9 hk
"""
import ctypes
import ctypes.wintypes as wt
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
KEYMAP_PATH = os.path.join(HERE, "keymap.json")
PIPE_NAME = r"\\.\pipe\cipher_input"
BITS = ["up", "down", "left", "right", "lp", "mp", "hp", "lk", "mk", "hk"]

# ---------------- SendInput ----------------
user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

KEYEVENTF_EXTENDEDKEY, KEYEVENTF_KEYUP, KEYEVENTF_SCANCODE = 0x1, 0x2, 0x8
ULONG_PTR = ctypes.c_size_t


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", wt.WORD), ("wScan", wt.WORD), ("dwFlags", wt.DWORD),
                ("time", wt.DWORD), ("dwExtraInfo", ULONG_PTR)]


class MOUSEINPUT(ctypes.Structure):
    _fields_ = [("dx", wt.LONG), ("dy", wt.LONG), ("mouseData", wt.DWORD),
                ("dwFlags", wt.DWORD), ("time", wt.DWORD), ("dwExtraInfo", ULONG_PTR)]


class _U(ctypes.Union):
    _fields_ = [("ki", KEYBDINPUT), ("mi", MOUSEINPUT)]


class INPUT(ctypes.Structure):
    _fields_ = [("type", wt.DWORD), ("u", _U)]


def send_keys(events):
    """events: lista de (scancode, down). scancode > 0xFF = extendido (0xE0xx)."""
    if not events:
        return
    arr = (INPUT * len(events))()
    for i, (sc, down) in enumerate(events):
        flags = KEYEVENTF_SCANCODE
        if sc > 0xFF:
            flags |= KEYEVENTF_EXTENDEDKEY
        if not down:
            flags |= KEYEVENTF_KEYUP
        arr[i].type = 1
        arr[i].u.ki = KEYBDINPUT(0, sc & 0xFF, flags, 0, 0)
    user32.SendInput(len(events), arr, ctypes.sizeof(INPUT))


# ---------------- named pipe ----------------
PIPE_ACCESS_INBOUND = 0x1
PIPE_TYPE_BYTE, PIPE_WAIT = 0x0, 0x0
INVALID_HANDLE = wt.HANDLE(-1).value
kernel32.CreateNamedPipeW.restype = wt.HANDLE
kernel32.CreateNamedPipeW.argtypes = [wt.LPCWSTR, wt.DWORD, wt.DWORD, wt.DWORD, wt.DWORD, wt.DWORD, wt.DWORD, wt.LPVOID]
kernel32.ConnectNamedPipe.argtypes = [wt.HANDLE, wt.LPVOID]
kernel32.ReadFile.argtypes = [wt.HANDLE, wt.LPVOID, wt.DWORD, ctypes.POINTER(wt.DWORD), wt.LPVOID]
kernel32.DisconnectNamedPipe.argtypes = [wt.HANDLE]
kernel32.CloseHandle.argtypes = [wt.HANDLE]


def load_keymap():
    with open(KEYMAP_PATH, "r", encoding="ascii") as f:
        km = json.load(f)
    return [int(km[name], 16) if isinstance(km[name], str) else int(km[name]) for name in BITS]


def serve():
    scancodes = load_keymap()
    print(f"[cipher_keys] keymap: " + ", ".join(f"{n}={s:#x}" for n, s in zip(BITS, scancodes)))
    while True:
        h = kernel32.CreateNamedPipeW(PIPE_NAME, PIPE_ACCESS_INBOUND, PIPE_TYPE_BYTE | PIPE_WAIT,
                                      1, 0, 4096, 0, None)
        if h == INVALID_HANDLE:
            raise OSError(ctypes.get_last_error(), "CreateNamedPipe")
        print("[cipher_keys] esperando a cipher.lua ...")
        kernel32.ConnectNamedPipe(h, None)
        print("[cipher_keys] conectado")
        cur = 0
        buf = ctypes.create_string_buffer(4096)
        n = wt.DWORD(0)
        pending = b""
        try:
            while kernel32.ReadFile(h, buf, 4096, ctypes.byref(n), None) and n.value:
                pending += buf.raw[:n.value]
                *lines, pending = pending.split(b"\n")
                if not lines:
                    continue
                try:
                    mask = int(lines[-1])        # solo importa el último estado
                except ValueError:
                    continue
                diff = mask ^ cur
                if diff:
                    send_keys([(scancodes[i], bool(mask >> i & 1)) for i in range(len(BITS)) if diff >> i & 1])
                    cur = mask
        finally:
            if cur:
                send_keys([(scancodes[i], False) for i in range(len(BITS)) if cur >> i & 1])
            kernel32.DisconnectNamedPipe(h)
            kernel32.CloseHandle(h)
            print("[cipher_keys] desconectado, todas las teclas liberadas")


# ---------------- calibración ----------------
CANDIDATES = {
    "up": 0xE048, "down": 0xE050, "left": 0xE04B, "right": 0xE04D,
    "A": 0x1E, "S": 0x1F, "D": 0x20, "F": 0x21, "Z": 0x2C, "X": 0x2D, "C": 0x2E, "V": 0x2F,
    "Q": 0x10, "W": 0x11, "E": 0x12, "R": 0x13, "U": 0x16, "I": 0x17, "O": 0x18,
    "J": 0x24, "K": 0x25, "L": 0x26, "1": 0x02, "5": 0x06,
}
BUTTON_TO_BIT = {"P1 Up": "up", "P1 Down": "down", "P1 Left": "left", "P1 Right": "right",
                 "P1 Weak Punch": "lp", "P1 Medium Punch": "mp", "P1 Strong Punch": "hp",
                 "P1 Weak Kick": "lk", "P1 Medium Kick": "mk", "P1 Strong Kick": "hk"}


def calibrate(state_file, hwnd_pid=None):
    found = {}
    for name, sc in CANDIDATES.items():
        send_keys([(sc, True)])
        time.sleep(0.18)
        try:
            with open(state_file, "r", encoding="ascii") as f:
                pressed = f.read().strip()
        except OSError:
            pressed = ""
        send_keys([(sc, False)])
        time.sleep(0.18)
        for btn in [p for p in pressed.split(",") if p]:
            if btn in BUTTON_TO_BIT and BUTTON_TO_BIT[btn] not in found:
                found[BUTTON_TO_BIT[btn]] = f"{sc:#x}"
        print(f"{name:>5} {sc:#06x} -> {pressed or '-'}")
    missing = [b for b in BITS if b not in found]
    with open(KEYMAP_PATH, "w", encoding="ascii") as f:
        json.dump({b: found.get(b, "0x0") for b in BITS}, f, indent=2)
    print("keymap.json:", json.dumps(found), "faltan:", missing)
    return not missing


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "serve"
    if cmd == "serve":
        serve()
    elif cmd == "calibrate":
        sys.exit(0 if calibrate(sys.argv[2]) else 1)
    else:
        print(__doc__)
