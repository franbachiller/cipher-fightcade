"""Convierte move_list.json (effie3rd/3rd_training_lua) a data/sfiii3/moves/<char>.lua.

  python -I tools/import_movelist.py <move_list.json> <out_dir>

Cada movimiento: { name, type ("special"|"sa1"|...|"kara"|"tc"...), air, variants = { {btn="LP", seq={{down=true},...}}, ... } }
Las direcciones son relativas (fwd/back). "button" se reemplaza por cada botón de la lista; EXP = LP+MP, EXK = LK+MK.
"""
import json
import os
import re
import sys

DIR = {"down": "down", "up": "up", "forward": "fwd", "back": "back"}
BTN = {"LP": "lp", "MP": "mp", "HP": "hp", "LK": "lk", "MK": "mk", "HK": "hk"}
EX = {"EXP": ["lp", "mp"], "EXK": ["lk", "mk"], "PPP": ["lp", "mp", "hp"], "KKK": ["lk", "mk", "hk"]}


def frame(tokens, button):
    f = {}
    for t in tokens:
        if t == "button":
            if button is None:
                return None
            for b in (EX.get(button) or [BTN[button]]):
                f[b] = True
        elif t in DIR:
            f[DIR[t]] = True
        elif t in BTN:
            f[BTN[t]] = True
        elif t in EX:
            for b in EX[t]:
                f[b] = True
        elif t in ("360", "720"):
            continue      # el giro ya está descrito por los pasos siguientes (down, back, up...)
        elif t in ("h_charge", "v_charge"):
            f["_charge"] = "h" if t == "h_charge" else "v"
        else:
            return None   # token desconocido: se omite
    return f


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, str):
        return '"' + v.replace('"', '\\"') + '"'
    if isinstance(v, list):
        return "{" + ",".join(lua(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ",".join((k if re.fullmatch(r"[A-Za-z_]\w*", k) else f'["{k}"]') + "=" + lua(x) for k, x in v.items()) + "}"
    raise TypeError(type(v))


def main():
    src, out = sys.argv[1], sys.argv[2]
    data = json.load(open(src, encoding="utf-8"))
    os.makedirs(out, exist_ok=True)
    for char, moves in data.items():
        res = []
        for m in moves:
            buttons = m.get("buttons") or [None]
            variants = []
            for b in buttons:
                if isinstance(b, list):          # kara: listas de botones alternativas
                    continue
                seq = [frame(step, b) for step in m.get("input", [])]
                if seq and all(s is not None for s in seq):
                    v = {"btn": b or "", "seq": seq}
                    # carga: el brain la acumula sosteniendo la dirección; la variante guarda solo el "soltar"
                    ch = next((s.pop("_charge") for s in seq if "_charge" in s), None)
                    if ch:
                        v["charge"] = ch
                        v["seq"] = [s for s in seq if not (len(s) == 1 and ("back" in s or "down" in s))][-1:]
                    variants.append(v)
            if variants:
                res.append({"name": m["name"], "type": m.get("move_type", "?"), "air": m.get("air") == "yes", "variants": variants})
        path = os.path.join(out, f"{char}.lua")
        with open(path, "w", encoding="ascii", newline="\n") as f:
            f.write("-- generado por tools/import_movelist.py desde effie3rd/3rd_training_lua move_list.json\n")
            f.write("return " + lua(res) + "\n")
        print(f"{char:12s} moves={len(res):3d} variantes={sum(len(m['variants']) for m in res):3d}")


if __name__ == "__main__":
    main()
