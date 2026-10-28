"""Análisis del volcado de RAM de UMK3 (logs/umk3_dump.bin, tools/umk3_probe.lua con CIPHER_UMK3_DUMP=1).
1) formato: ¿la Lua de FBNeo direcciona por bit (TMS34010)? -> cada byte real ocupa 8 direcciones
2) candidatos a X de P1: palabras de 16 bits que suben al caminar a la derecha y bajan a la izquierda
3) candidatos a Y: cambian solo en la fase de salto y vuelven
  python -I tools\\umk3_dump_analyze.py"""
import os
import struct

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE, SIZE = 0x01000000, 0x80000
raw = open(os.path.join(ROOT, "logs", "umk3_dump.bin"), "rb").read()
REC = 10 + SIZE
n = len(raw) // REC
frames, phases, snaps = [], [], []
for i in range(n):
    r = raw[i * REC:(i + 1) * REC]
    frames.append(int(r[:8]))
    phases.append(int(r[8:10]))
    snaps.append(np.frombuffer(r[10:], dtype=np.uint8))
S = np.stack(snaps)
phases = np.array(phases)
print("snapshots:", n, "fases:", sorted(set(phases.tolist())))

# 1) formato: comparar el byte de cada dirección con el de la dirección +1..+7
s0 = S[len(S) // 2]
same = [(s0[0::8] == s0[k::8][:len(s0[0::8])]).mean() for k in range(1, 8)]
print("igualdad con +1..+7:", ["%.2f" % x for x in same])
nz = [(s0[k::8] != 0).mean() for k in range(8)]
print("no-cero por posición dentro de 8:", ["%.3f" % x for x in nz])

# bytes reales (uno de cada 8) y palabras de 16 bits little-endian en offsets pares
R = S[:, ::8].astype(np.int64)                     # (n, 65536)
W = R[:, 0::2] + 256 * R[:, 1::2]                  # (n, 32768) palabras
def addr(word_i):
    return BASE + word_i * 16                      # dirección Lua (bit) de la palabra


def sgn(x):
    return np.where(x >= 0x8000, x - 0x10000, x)


Ws = sgn(W)
ph = phases
idle1, right, left, idle2, up, idle3, down = (ph == 1), (ph == 2), (ph == 3), (ph == 4), (ph == 5), (ph == 6), (ph == 7)


def span(mask):
    idx = np.where(mask)[0]
    return idx[0], idx[-1]


r0, r1 = span(right)
l0, l1 = span(left)
dR = Ws[r1] - Ws[r0]
dL = Ws[l1] - Ws[l0]
still = (Ws[idle1].max(0) == Ws[idle1].min(0))
# monotonía dentro de cada fase
monoR = np.all(np.diff(Ws[r0:r1 + 1], axis=0) >= 0, axis=0)
monoL = np.all(np.diff(Ws[l0:l1 + 1], axis=0) <= 0, axis=0)
cand = np.where((dR > 20) & (dL < -20) & monoR & monoL & still)[0]
print("\nX de P1 (sube a la derecha, baja a la izquierda, quieto en idle):", len(cand))
for i in cand[:25]:
    print("  0x%08X  idle=%d  der %d->%d  izq %d->%d" % (addr(i), Ws[r0 - 1, i], Ws[r0, i], Ws[r1, i], Ws[l0, i], Ws[l1, i]))
# también al revés (si el eje está invertido / P1 mira a la izquierda)
cand2 = np.where((dR < -20) & (dL > 20) & still)[0]
print("invertidos:", [("0x%08X" % addr(i)) for i in cand2[:10]])

import sys
if len(sys.argv) > 1 and sys.argv[1] == "ptr":
    # dwords (32 bits LE = 2 palabras) que apuntan a [lo, hi) en el snapshot del medio
    lo, hi = int(sys.argv[2], 16), int(sys.argv[3], 16)
    s = len(S) // 2
    D = W[s, 0::1]
    dw = D[:-1] + 65536 * D[1:]                    # dword que empieza en cada palabra
    hits = np.where((dw >= lo) & (dw < hi))[0]
    print("\npunteros a 0x%08X-0x%08X:" % (lo, hi))
    for i in hits[:60]:
        stable = all(int(W[k, i]) + 65536 * int(W[k, i + 1]) == int(dw[i]) for k in range(0, len(S), 10))
        print("  en 0x%08X -> 0x%08X %s" % (addr(i), int(dw[i]), "estable" if stable else "cambia"))
    raise SystemExit
if len(sys.argv) > 2:
    lo, hi = int(sys.argv[1], 16), int(sys.argv[2], 16)
    pick = [r0 - 1, (r0 + r1) // 2, r1, (l0 + l1) // 2, l1]
    u0_, u1_ = span(up)
    d0_, d1_ = span(down)
    pick += [u0_ + (u1_ - u0_) // 4, (u0_ + u1_) // 2, (d0_ + d1_) // 2]
    names = ["idle", "der½", "derF", "izq½", "izqF", "salt¼", "salt½", "agach"]
    print("\nbloque 0x%08X-0x%08X (palabras de 16 bits, con signo):" % (lo, hi))
    print("  %-10s " % "addr" + " ".join("%7s" % n for n in names))
    for wi in range((lo - BASE) // 16, (hi - BASE) // 16):
        vals = [int(Ws[p, wi]) for p in pick]
        if len(set(vals)) > 1:
            print("  0x%08X " % addr(wi) + " ".join("%7d" % v for v in vals))
    raise SystemExit
u0, u1 = span(up)
inv = np.where((Ws[u0:u1 + 1].max(0) - Ws[u0:u1 + 1].min(0) > 30) & still & (np.abs(Ws[u1 + 1] - Ws[u0 - 1]) <= 2))[0]
print("\nY candidatos (cambia mucho en el salto y vuelve):", len(inv))
for i in inv[:25]:
    col = Ws[u0 - 1:u1 + 2, i]
    print("  0x%08X  min=%d max=%d antes=%d despues=%d" % (addr(i), col.min(), col.max(), col[0], col[-1]))
