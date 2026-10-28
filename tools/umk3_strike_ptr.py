"""Busca en los volcados de RAM (logs/umk3_dump.bin, plan "attack") dwords que apunten a registros de las tablas de
golpes de la ROM (0xFFAF2000-0xFFAFF000, registros de 7 palabras = 0x70 bits). Si el juego guarda el golpe activo
como puntero, aparece solo durante las fases de ataque.  python -I tools\\umk3_strike_ptr.py"""
import collections
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import umk3_rom  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE, SIZE = 0x01000000, 0x80000
LO, HI = 0xFFAF0000, 0xFFB00000
raw = open(os.path.join(ROOT, "logs", "umk3_dump.bin"), "rb").read()
REC = 10 + SIZE
n = len(raw) // REC
names = {1: "idle", 2: "lp", 3: "hp", 4: "block", 5: "sweep", 6: "lk"}
rom = umk3_rom.load_program()
W = umk3_rom.words(rom)

hits = collections.defaultdict(list)          # dirección RAM -> [(fase, k, valor)]
for i in range(n):
    r = raw[i * REC:(i + 1) * REC]
    k, ph = int(r[:8]), int(r[8:10])
    b = np.frombuffer(r[10:], dtype=np.uint8)[::8].astype(np.uint64)   # bytes reales
    w = b[0::2] + 256 * b[1::2]
    dw = w[:-1] + 65536 * w[1:]
    for j in np.where((dw >= LO) & (dw < HI))[0]:
        hits[BASE + j * 16].append((ph, k, int(dw[j])))
print("direcciones de RAM con punteros a 0xFFAF0000-0xFFB00000:", len(hits))
for a, lst in sorted(hits.items(), key=lambda kv: -len(set(x[2] for x in kv[1])))[:20]:
    by_phase = collections.defaultdict(set)
    for ph, k, v in lst:
        by_phase[names.get(ph, ph)].add(v)
    desc = "  ".join("%s:%s" % (p, ",".join("%08X" % v for v in sorted(vs)[:4])) for p, vs in by_phase.items())
    print("0x%08X  %3d veces  %s" % (a, len(lst), desc))
