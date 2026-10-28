"""ROM de programa de UMK3 (umk3.zip: u54 = bytes pares, u63 = impares) y búsqueda de las tablas de golpes.
Formato esperado (motor de Midway, doc/HITBOX_MODEL.md de junkwax/mk2-rev4): registros de 8 palabras de 16 bits
x_offset, y_offset, x_size, y_size, reacción, daño (golpe<<8 | bloqueo), score, flags.
Dirección de CPU (bit) del byte n de la ROM: 0xFF800000 + 8*n.
  python -I tools\\umk3_rom.py strikes        -> candidatos a tablas de golpes
  python -I tools\\umk3_rom.py dump ADDR N     -> N palabras desde la dirección de bit ADDR"""
import struct
import sys
import zipfile

ZIP = r"C:\Users\bachi\Documents\Fightcade\emulator\fbneo\ROMs\umk3.zip"
ROM_BASE = 0xFF800000


def load_program():
    z = zipfile.ZipFile(ZIP)
    even = z.read("l1.2_mortal_kombat_3_u54_ultimate.u54")
    odd = z.read("l1.2_mortal_kombat_3_u63_ultimate.u63")
    out = bytearray(len(even) * 2)
    out[0::2] = even
    out[1::2] = odd
    return bytes(out)


def words(rom):
    return struct.unpack("<%dh" % (len(rom) // 2), rom)


def cpu(byte_off):
    return ROM_BASE + byte_off * 8


def plausible(r):
    xo, yo, xs, ys, react, dmg, score, flags = r
    hit, blk = (dmg >> 8) & 0xFF, dmg & 0xFF
    return (-20 <= xo <= 230 and -60 <= yo <= 170 and 6 <= xs <= 170 and 6 <= ys <= 170
            and 2 <= hit <= 70 and blk <= 20 and blk < hit)


def strikes(rom):
    W = words(rom)
    found = []
    i = 0
    while i < len(W) - 8:
        n = 0
        while i + (n + 1) * 8 <= len(W) and plausible(W[i + n * 8:i + n * 8 + 8]):
            n += 1
        if n >= 8:
            found.append((i, n))
            i += n * 8
        else:
            i += 1
    print("tablas candidatas (>= 8 registros seguidos):", len(found))
    for i, n in found:
        print("\n== 0x%08X  %d registros" % (cpu(i * 2), n))
        for k in range(min(n, 6)):
            xo, yo, xs, ys, react, dmg, score, flags = W[i + k * 8:i + k * 8 + 8]
            print("   x_off=%4d y_off=%4d %3dx%-3d react=%04x golpe=%2d bloq=%2d score=%d flags=%04x" % (
                xo, yo, xs, ys, react & 0xFFFF, (dmg >> 8) & 0xFF, dmg & 0xFF, score, flags & 0xFFFF))


def rect_ok(xo, yo, xs, ys):
    return -20 <= xo <= 230 and -60 <= yo <= 170 and 8 <= xs <= 170 and 8 <= ys <= 170


def strikes_any(rom):
    """registros de largo S (5..20 palabras) cuyas 4 primeras palabras son un rectángulo plausible, >= 10 seguidos,
    con variedad (no constantes)"""
    W = words(rom)
    best = []
    for S in range(5, 21):
        i = 0
        while i < len(W) - S * 10:
            n = 0
            while i + (n + 1) * S <= len(W) and rect_ok(*W[i + n * S:i + n * S + 4]):
                n += 1
            if n >= 10:
                recs = [W[i + k * S:i + k * S + 4] for k in range(n)]
                if len(set(recs)) >= n * 0.7 and len(set(r[2] for r in recs)) >= 4:
                    best.append((n, S, i))
                i += n * S
            else:
                i += 1
    best.sort(reverse=True)
    print("candidatos (registros, largo en palabras, dirección):", len(best))
    for n, S, i in best[:25]:
        print("\n== 0x%08X  largo=%d palabras  %d registros" % (cpu(i * 2), S, n))
        for k in range(4):
            print("   " + " ".join("%5d" % W[i + k * S + j] for j in range(S)))


if __name__ == "__main__":
    if sys.argv[1] == "any":
        strikes_any(load_program())
        raise SystemExit
    rom = load_program()
    print("ROM de programa: %d bytes, %s-%s" % (len(rom), "0x%08X" % cpu(0), "0x%08X" % cpu(len(rom) - 1)))
    if sys.argv[1] == "strikes":
        strikes(rom)
    elif sys.argv[1] == "dump":
        a, n = int(sys.argv[2], 16), int(sys.argv[3])
        off = (a - ROM_BASE) // 8
        W = words(rom[off - off % 2:])
        print(" ".join("%04x" % (w & 0xFFFF) for w in W[:n]))
