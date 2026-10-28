"""Palabras de una ventana de RAM fija en cada copia del volcado (logs/umk3_dump.bin), agrupadas por fase del guion.
Solo muestra las palabras que cambian.  python -I tools\\umk3_ram_window.py 0x01073900 0x01073C00 [copias_por_fase]"""
import os
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE, SIZE = 0x01000000, 0x80000
lo, hi = int(sys.argv[1], 16), int(sys.argv[2], 16)
per = int(sys.argv[3]) if len(sys.argv) > 3 else 6
raw = open(os.path.join(ROOT, "logs", "umk3_dump.bin"), "rb").read()
REC = 10 + SIZE
n = len(raw) // REC
names = {1: "idle", 2: "lp", 3: "hp", 4: "bloq", 5: "swp", 6: "lk"}
snaps, phs, ks = [], [], []
for i in range(n):
    r = raw[i * REC:(i + 1) * REC]
    ks.append(int(r[:8]))
    phs.append(int(r[8:10]))
    snaps.append(np.frombuffer(r[10:], dtype=np.uint8))
cols = []
for p in sorted(set(phs)):
    cols += [i for i, x in enumerate(phs) if x == p][:per]


def word(s, a):
    i = (a - BASE) // 8 * 8
    return int(s[i]) | (int(s[i + 8]) << 8)


print("addr        " + " ".join("%5s" % (names.get(phs[i], "?")[:3] + str(ks[i] % 100)) for i in cols))
for a in range(lo, hi, 0x10):
    vals = [word(snaps[i], a) for i in cols]
    if len(set(vals)) > 1:
        print("0x%08X  " % a + " ".join("%5X" % v for v in vals))
