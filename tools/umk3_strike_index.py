"""Tablas de golpes de UMK3: lista completa (inicio exacto de cada una) y dónde se las referencia en la ROM.
Una tabla de golpes es una corrida de registros de 7 palabras con rectángulo plausible y daño (golpe<<8|bloqueo).
Busca en la ROM dwords que apunten al inicio de cada tabla (tabla de punteros por personaje).
  python -I tools\\umk3_strike_index.py"""
import collections
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import umk3_rom  # noqa: E402

rom = umk3_rom.load_program()
W = umk3_rom.words(rom)
S = 7


def rec_ok(r):
    xo, yo, xs, ys, react, dmg, flags = r
    hit, blk = (dmg >> 8) & 0xFF, dmg & 0xFF
    return umk3_rom.rect_ok(xo, yo, xs, ys) and 1 <= hit <= 90 and blk <= 30


tables = []
i = 0
while i < len(W) - S * 6:
    n = 0
    while i + (n + 1) * S <= len(W) and rec_ok(W[i + n * S:i + n * S + S]):
        n += 1
    if n >= 6:
        tables.append((i, n))
        i += n * S
    else:
        i += 1
print("tablas de golpes:", len(tables))
# dwords de la ROM (alineados a palabra) que valgan la dirección de bit del inicio de una tabla
DW = struct.unpack("<%dI" % (len(rom) // 4 - 1), rom[2:2 + (len(rom) // 4 - 1) * 4])   # alineación impar de palabra
DW0 = struct.unpack("<%dI" % (len(rom) // 4), rom[:len(rom) // 4 * 4])
refs = collections.defaultdict(list)
starts = {umk3_rom.cpu(i * 2): k for k, (i, n) in enumerate(tables)}
for j, v in enumerate(DW0):
    if v in starts:
        refs[v].append(umk3_rom.cpu(j * 4))
for j, v in enumerate(DW):
    if v in starts:
        refs[v].append(umk3_rom.cpu(2 + j * 4))
for k, (i, n) in enumerate(tables):
    a = umk3_rom.cpu(i * 2)
    first = W[i:i + S]
    print("%2d  0x%08X  %2d golpes  1º: %dx%d a %d, daño %d/%d   refs: %s" % (
        k, a, n, first[2], first[3], first[0], (first[5] >> 8) & 0xFF, first[5] & 0xFF,
        ", ".join("0x%08X" % r for r in sorted(refs.get(a, []))[:6]) or "-"))
