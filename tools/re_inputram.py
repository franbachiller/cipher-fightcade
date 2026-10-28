"""RE: ubica en RAM de CPS3 el input de cada jugador correlacionando las máscaras que manda CIPHER externo
(P1 del emulador) con cada bit de cada byte de RAM, para delays de 0..6 frames.
  python -I tools\\re_inputram.py <pid> [segundos]"""
import os
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cipher_ext as ce  # noqa: E402

pid = int(sys.argv[1])
secs = float(sys.argv[2]) if len(sys.argv) > 2 else 20
frames, masks = [], []
rt = ce.ExtRuntime(pid)
orig = rt.ram_linear


def rec():
    ram = orig()
    if ram is not None:
        frames.append(np.frombuffer(ram, dtype=np.uint8).copy())
        masks.append(rt.cur_mask)      # máscara vigente durante el frame recién emulado
    return ram


rt.ram_linear = rec
t_end = time.time() + secs
rt.run(stop=lambda: time.time() > t_end)
R = np.stack(frames)                   # [T, 512K]
M = np.array(masks, dtype=np.int32)
cols = np.nonzero(R.min(0) != R.max(0))[0]   # solo bytes que cambian
R = R[:, cols]
print("frames", len(R), "máscaras distintas", len(set(masks)), "bytes variables", len(cols))
names = ce.ck.BITS
for b, name in enumerate(names):
    mb = (M >> b) & 1
    if mb.min() == mb.max():
        print(name, "sin variación")
        continue
    best = []
    for d in range(0, 7):
        tgt = mb[: len(mb) - d] if d else mb     # máscara en t-d contra RAM en t
        ram = R[d:]
        for bit in range(8):
            v = (ram >> bit) & 1               # [T-d, 512K]
            eq = (v == tgt[:, None]).mean(0)
            for inv, score in ((0, eq), (1, 1 - eq)):
                idx = np.argsort(score)[-3:]
                for i in idx:
                    best.append((score[i], d, 0x02000000 + int(cols[i]), bit, inv))
    best.sort(reverse=True)
    print(name, " | ".join("%.3f d=%d 0x%08X b%d%s" % (s, d, a, bt, " inv" if inv else "") for s, d, a, bt, inv in best[:5]))
