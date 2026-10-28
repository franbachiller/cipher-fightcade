"""Campos del objeto de un jugador que cambian según la acción (volcado de tools/umk3_probe.lua, plan "attack").
Lee el puntero del bloque de jugador (P1 0x010609D0, P2 0x01061580) en cada copia y muestra las palabras del objeto
que varían, en los primeros frames de cada fase (cuando sale el golpe).
  python -I tools\\umk3_obj_analyze.py [p1|p2] [rango_bytes_objeto=0x600]"""
import os
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE, SIZE = 0x01000000, 0x80000
PLAYER = {"p1": 0x010609D0, "p2": 0x01061580}
who = sys.argv[1] if len(sys.argv) > 1 else "p1"
span_bits = int(sys.argv[2], 16) if len(sys.argv) > 2 else 0x600 * 8
raw = open(os.path.join(ROOT, "logs", "umk3_dump.bin"), "rb").read()
REC = 10 + SIZE
n = len(raw) // REC
names = {1: "idle", 2: "lp", 3: "hp", 4: "block", 5: "sweep", 6: "lk"}


def word(snap, a):
    i = (a - BASE) // 8 * 8
    if i < 0 or i + 8 >= len(snap):
        return -1
    return int(snap[i]) | (int(snap[i + 8]) << 8)


snaps, ks, phs = [], [], []
for i in range(n):
    r = raw[i * REC:(i + 1) * REC]
    ks.append(int(r[:8]))
    phs.append(int(r[8:10]))
    snaps.append(np.frombuffer(r[10:], dtype=np.uint8))
obj = [word(s, PLAYER[who]) | (word(s, PLAYER[who] + 0x10) << 16) for s in snaps]
print("puntero al objeto %s:" % who, sorted(set("0x%08X" % o for o in obj)))
o = obj[len(obj) // 2]
# índices: por fase, las 6 primeras copias (36 frames)
cols = []
for p in sorted(set(phs)):
    idx = [i for i, x in enumerate(phs) if x == p][:6]
    cols += [(p, i) for i in idx]
rows = []
for off in range(0, span_bits, 0x10):
    vals = [word(snaps[i], obj[i] + off) for _, i in cols]
    if len(set(vals)) > 1:
        rows.append((off, vals))
print("offset  " + " ".join("%6s" % ("%s%d" % (names[p][:4], j % 6)) for j, (p, _) in enumerate(cols)))
for off, vals in rows:
    print("+0x%03X " % off + " ".join("%6d" % v for v in vals))
