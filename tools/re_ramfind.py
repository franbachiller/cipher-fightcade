"""RE: ubica la RAM principal de CPS3 (0x02000000, 512 KB) dentro de fcadefbneo.exe usando la marca de probe_ramfind.lua,
deduce el orden de bytes, busca punteros estáticos a esa RAM en la imagen del exe y candidatos a contador de frames."""
import re
import struct
import sys
import time

sys.path.insert(0, __import__("os").path.dirname(__file__))
from procmem import Proc  # noqa: E402

MAGIC = bytes([0xC1, 0x9E, 0x7A, 0x33, 0x05, 0xD2, 0x11, 0xFB, 0x48, 0x6C, 0xA0, 0x0F, 0x93, 0x27, 0xE8, 0x5D])
MAGIC_ADDR, FC_ADDR, RAM0, RAM_SIZE = 0x0207FFF0, 0x0207FFE0, 0x02000000, 0x80000
LOG = r"C:\Users\bachi\Desktop\CIPHER-Fightcade\logs\probe_ramfind.log"


def xform(b, x):
    return bytes(b[i ^ x] for i in range(len(b)))


pid = int(sys.argv[1])
p = Proc(pid)
exe_base, exe_size = p.module("fcadefbneo.exe")
print("exe base=0x%X size=0x%X" % (exe_base, exe_size))

hits = []
for base, size, prot, typ in p.regions():
    data = p.read(base, size)
    if not data:
        continue
    for x in (0, 1, 3):
        pat = xform(MAGIC, x)
        for m in re.finditer(re.escape(pat), data):
            hits.append((x, base + m.start(), prot, typ))
for x, a, prot, typ in hits:
    ram = a - (MAGIC_ADDR - RAM0)
    print("MAGIC xor=%d at 0x%X -> RAM base 0x%X prot=0x%X type=0x%X" % (x, a, ram, prot, typ))

print("lua:", open(LOG).read().strip())
for x, a, prot, typ in hits:
    ram = a - (MAGIC_ADDR - RAM0)
    blk = p.read(ram, RAM_SIZE)
    if not blk:
        continue

    def rb(addr):
        return blk[(addr - RAM0) ^ x]
    print("  xor=%d p1hp=%d p2hp=%d" % (x, rb(0x02068C6C + 0x9F), rb(0x02069104 + 0x9F)))
    # punteros estáticos a la base (o a base+k) dentro de la imagen del exe
    img = p.read(exe_base, exe_size) or b""
    for k in range(0, len(img) - 3, 4):
        v = struct.unpack_from("<I", img, k)[0]
        if ram - 0x100 <= v <= ram + 0x100:
            print("  PTR exe+0x%X = 0x%X (base%+d)" % (k, v, v - ram))
    # contador de frames del emulador: dword en la imagen igual al fc de Lua (marcado en RAM)
    raw = bytes(blk[((FC_ADDR - RAM0) + i) ^ x] for i in range(4))
    fc = struct.unpack(">I", raw)[0]
    img = p.read(exe_base, exe_size)
    fc2 = struct.unpack(">I", bytes(p.read(ram, RAM_SIZE)[((FC_ADDR - RAM0) + i) ^ x] for i in range(4)))[0]
    lo, hi = min(fc, fc2) - 3, max(fc, fc2) + 3
    print("  fc en RAM=%d..%d" % (fc, fc2))
    cands = [k for k in range(0, len(img) - 3, 4) if lo <= struct.unpack_from("<I", img, k)[0] <= hi]
    time.sleep(1.0)
    img2 = p.read(exe_base, exe_size)
    for k in cands:
        a0, a1 = struct.unpack_from("<I", img, k)[0], struct.unpack_from("<I", img2, k)[0]
        print("  FC? exe+0x%X %d -> %d (d=%d)" % (k, a0, a1, a1 - a0))
