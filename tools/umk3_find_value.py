"""Busca en el primer snapshot del volcado offsets donde el bloque de P1 y el de P2 (o sus objetos) valen un par
dado (ej. el id de personaje: Kitana 15 / Scorpion 18).  python -I tools\\umk3_find_value.py 15 18"""
import os
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE, SIZE = 0x01000000, 0x80000
want = (int(sys.argv[1]), int(sys.argv[2]))
raw = open(os.path.join(ROOT, "logs", "umk3_dump.bin"), "rb").read()
s = np.frombuffer(raw[10:10 + SIZE], dtype=np.uint8)


def word(a):
    i = (a - BASE) // 8 * 8
    return int(s[i]) | (int(s[i + 8]) << 8)


def dword(a):
    return word(a) | (word(a + 0x10) << 16)


for name, p1, p2, span in (("bloque", 0x010609A0, 0x01061550, 0xBB0),
                           ("objeto", dword(0x010609D0), dword(0x01061580), 0x210),
                           ("proceso", dword(0x01060A10), dword(0x010615C0), 0x800)):
    for off in range(0, span, 0x10):
        a, b = word(p1 + off), word(p2 + off)
        if (a, b) == want or (a & 0xFF, b & 0xFF) == want:
            print("%s +0x%03X: P1=0x%04X P2=0x%04X" % (name, off, a, b))
