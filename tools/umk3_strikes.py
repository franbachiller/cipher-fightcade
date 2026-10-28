"""Golpes de UMK3 desde la ROM: tabla maestra por personaje (0xFFAF2480) -> lista de golpes -> registro de 7 palabras
(x_off, y_off, x_size, y_size, reacción, daño golpe<<8|bloqueo, flags). Rutina del motor que hace lo mismo: 0xFFAF23D0.
  python -I tools\\umk3_strikes.py check     -> verifica con el volcado (golpe activo de P1)
  python -I tools\\umk3_strikes.py export    -> data/umk3/strikes.lua (todos los personajes)"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import umk3_rom  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER = 0xFFAF2480
# orden de personajes de MK3/UMK3 (confirmado por las listas compartidas: robots 7/8/14, mujeres ninja 15-17,
# ninjas 18-23; id leído en RAM: bloque de jugador +0x90)
CHARS = ["kano", "sonya", "jax", "nightwolf", "subzero", "stryker", "sindel", "sektor", "cyrax", "kunglao", "kabal",
         "sheeva", "shangtsung", "liukang", "smoke", "kitana", "jade", "mileena", "scorpion", "reptile", "ermac",
         "classic_subzero", "human_smoke", "noob_saibot"]
rom = umk3_rom.load_program()


def dw(bit):
    o = (bit - umk3_rom.ROM_BASE) // 8
    return struct.unpack("<I", rom[o:o + 4])[0]


def w(bit):
    o = (bit - umk3_rom.ROM_BASE) // 8
    return struct.unpack("<h", rom[o:o + 2])[0]


def record(ptr):
    xo, yo, xs, ys, react, dmg, flags = (w(ptr + k * 0x10) for k in range(7))
    return {"x_off": xo, "y_off": yo, "w": xs, "h": ys, "react": react & 0xFFFF, "hit": (dmg >> 8) & 0xFF,
            "block": dmg & 0xFF, "flags": flags & 0xFFFF, "ptr": ptr}


def strike_list(char_id, n=40):
    lst = dw(MASTER + char_id * 0x20)
    out = []
    for i in range(n):
        p = dw(lst + i * 0x20)
        if not (0xFF800000 <= p < 0xFFFFFFFF):
            break
        r = record(p)
        if not umk3_rom.rect_ok(r["x_off"], r["y_off"], r["w"], r["h"]):
            out.append(None)
            continue
        out.append(r)
    return lst, out


if __name__ == "__main__":
    if sys.argv[1] == "check":
        lst, recs = strike_list(15)
        print("Kitana (15): lista 0x%08X" % lst)
        for i, r in enumerate(recs[:12]):
            print("  [%2d] %s" % (i, r and "x_off=%d y_off=%d %dx%d golpe=%d bloq=%d react=%04X flags=%04X @0x%08X" % (
                r["x_off"], r["y_off"], r["w"], r["h"], r["hit"], r["block"], r["react"], r["flags"], r["ptr"])))
    elif sys.argv[1] == "export":
        lines = ["-- generado por tools/umk3_strikes.py desde la ROM (umk3 rev 1.2): golpes por personaje, índice = A11",
                 "-- del proceso del jugador. Campos: x_off (alcance desde el anipoint), y_off, w, h, daño golpe/bloqueo.",
                 "return {"]
        for cid, name in enumerate(CHARS):
            lst, recs = strike_list(cid)
            lines.append('  [%d] = { name = "%s", list = 0x%08X, strikes = {' % (cid, name, lst))
            for i, r in enumerate(recs):
                if r:
                    lines.append("    [%d] = { x_off = %d, y_off = %d, w = %d, h = %d, hit = %d, block = %d, react = 0x%04X, flags = 0x%04X }," % (
                        i, r["x_off"], r["y_off"], r["w"], r["h"], r["hit"], r["block"], r["react"], r["flags"]))
            lines.append("  } },")
        lines.append("}")
        out = os.path.join(ROOT, "data", "umk3", "strikes.lua")
        open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")
        print("->", out)
