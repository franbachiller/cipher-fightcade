"""Palabras del BLOQUE FIJO de un jugador (P1 0x010609D0, P2 0x01061580; 0xBB0 de largo) que cambian según la fase
del guion (volcado de tools/umk3_probe.lua).  python -I tools\\umk3_block_analyze.py [p1|p2]"""
import os
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE, SIZE = 0x01000000, 0x80000
PLAYER = {"p1": 0x010609D0, "p2": 0x01061580}
who = sys.argv[1] if len(sys.argv) > 1 else "p1"
raw = open(os.path.join(ROOT, "logs", "umk3_dump.bin"), "rb").read()
REC = 10 + SIZE
n = len(raw) // REC
names = {1: "idle", 2: "lp", 3: "hp", 4: "block", 5: "sweep", 6: "lk"}


def word(snap, a):
    i = (a - BASE) // 8 * 8
    return int(snap[i]) | (int(snap[i + 8]) << 8)


snaps, phs = [], []
for i in range(n):
    r = raw[i * REC:(i + 1) * REC]
    phs.append(int(r[8:10]))
    snaps.append(np.frombuffer(r[10:], dtype=np.uint8))
cols = []
for p in sorted(set(phs)):
    idx = [i for i, x in enumerate(phs) if x == p][:6]
    cols += [(p, i) for i in idx]
print("offset  " + " ".join("%6s" % ("%s%d" % (names.get(p, str(p))[:4], j % 6)) for j, (p, _) in enumerate(cols)))
for off in range(0, 0xBB0, 0x10):
    vals = [word(snaps[i], PLAYER[who] + off) for _, i in cols]
    if len(set(vals)) > 1:
        print("+0x%03X " % off + " ".join("%6d" % v for v in vals))
