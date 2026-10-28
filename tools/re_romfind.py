"""RE: ubica la región 0x06000000 (ROM de usuario de CPS3: cajas de ataque/empuje/agarre) dentro de fcadefbneo.exe
buscando los bytes que volcó tools/probe_rom.lua, y el puntero estático en el exe."""
import re
import struct
import sys

sys.path.insert(0, __import__("os").path.dirname(__file__))
from procmem import Proc  # noqa: E402

LOG = r"C:\Users\bachi\Desktop\CIPHER-Fightcade\logs\probe_rom.log"
pid = int(sys.argv[1])
p = Proc(pid)
exe, size = p.module("fcadefbneo.exe")
samples = []
for line in open(LOG):
    off, ptr, hexs = line.split()
    ptr = int(ptr, 16)
    if ptr >= 0x06000000 and bytes.fromhex(hexs)[:32].count(0) < 20:     # solo muestras con datos distintivos
        samples.append((ptr, bytes.fromhex(hexs)[:32]))
print("muestras", [hex(s[0]) for s in samples])


def xf(b, x):
    return bytes(b[i ^ x] for i in range(len(b)))


hits = {}
for base, rsize, prot, typ in p.regions():
    data = p.read(base, rsize)
    if not data:
        continue
    for ptr, blob in samples:
        a = ptr & ~3
        blk = blob[a - ptr:] if a == ptr else blob
        for x in (0, 1, 3):
            for m in re.finditer(re.escape(xf(blob[:32], x)), data):
                region0 = base + m.start() - (ptr - 0x06000000)
                hits.setdefault((x, region0), set()).add(hex(ptr))
for (x, r0), ptrs in hits.items():
    if len(ptrs) == len(samples):
        print("ROM 0x06000000 en 0x%X (xor=%d) coincide con %s" % (r0, x, sorted(ptrs)))
        import numpy as np
        img = np.frombuffer(p.read(exe, size), dtype="<u4")
        for k in np.nonzero(img == r0)[0]:
            print("   PTR exe+0x%X" % (int(k) * 4))
