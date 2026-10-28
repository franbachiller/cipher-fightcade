"""Alcance EXACTO (px de distancia entre centros, como s.dist) de cada golpe/agarre de cada personaje contra cada
defensor de pie y agachado, desde las cajas de la frame data de effie (data/sfiii3nr1/framedata/@<char>_framedata.json).

Cajas: [tipo, base, alto, izquierda, ancho], adelante = x negativo. Tipos (effie tools.lua):
  1 push, 2 throwable, 3 vulnerability, 4 ext_vulnerability, 5/6 attack, 7 throw.
Atacante en 0 mirando a +X, defensor en D mirando a -X:
  borde lejano del ataque (mundo) = desplazamiento + (-izq_atk);  borde cercano del defensor = D + izq_def
  conecta si se superponen en altura y  D <= desplazamiento - izq_atk - izq_def   ->  alcance = máximo de eso.
El desplazamiento acumula "movement" por frame (como prediction.lua de effie). Golpes con "velocity" (se deslizan
con velocidad/aceleración) quedan marcados vel=true: su alcance real es mayor y se mide en el emulador.

  python -I tools\\compute_ranges.py   ->  data\\sfiii3\\ranges.lua
"""
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "third_party", "effie3rd__3rd_training_lua", "data", "sfiii3nr1", "framedata")
OUT = os.path.join(ROOT, "data", "sfiii3", "ranges.lua")
VULN, ATK, THROW, THROWABLE = (3, 4), (5, 6), (7,), (2,)


def boxes(frame, types):
    return [b[1:5] for b in (frame.get("boxes") or []) if b[0] in types]


def stance_boxes(data, state, types):
    anim = data.get(data.get(state, ""), {})
    fr = (anim.get("frames") or [{}])[0]
    return boxes(fr, types)


def overlap_y(a, b):
    return a[0] <= b[0] + b[1] and b[0] <= a[0] + a[1]


def move_reach(anim, types, def_boxes):
    """alcance máximo contra un set de cajas del defensor (None si nunca se superponen en altura)"""
    disp, best, first = 0, None, None
    for i, fr in enumerate(anim.get("frames") or []):
        mv = fr.get("movement")
        if mv:
            disp += mv[0]
        for a in boxes(fr, types):
            for v in def_boxes:
                if overlap_y(a, v):
                    r = disp - a[2] - v[2]
                    if best is None or r > best:
                        best = r
                    if first is None:
                        first = i
    return best, first


def main():
    chars = {}
    for f in glob.glob(os.path.join(SRC, "@*_framedata.json")):
        name = re.match(r"@(\w+)_framedata\.json", os.path.basename(f)).group(1)
        if name == "projectiles":
            continue
        with open(f, encoding="utf-8") as fh:
            chars[name] = json.load(fh)
    defenders = {}
    for name, data in chars.items():
        defenders[name] = {
            "st": stance_boxes(data, "standing", VULN), "cr": stance_boxes(data, "crouching", VULN),
            "thr_st": stance_boxes(data, "standing", THROWABLE), "thr_cr": stance_boxes(data, "crouching", THROWABLE),
        }
    lines = ["-- generado por tools/compute_ranges.py desde la frame data de effie (cajas). Alcance en px de distancia",
             "-- entre centros (s.dist): R[atacante][golpe] = { st = {defensor = px}, cr = {...}, f = 1er frame activo, vel = bool }",
             "return {"]
    n_moves = 0
    for att in sorted(chars):
        data = chars[att]
        lines.append("  [\"%s\"] = {" % att)
        for key, anim in sorted(data.items(), key=lambda kv: str(kv[0])):
            if not isinstance(anim, dict) or "frames" not in anim or "name" not in anim:
                continue
            frames = anim["frames"]
            has_atk = any(boxes(fr, ATK) for fr in frames)
            has_thr = any(boxes(fr, THROW) for fr in frames)
            if not (has_atk or has_thr):
                continue
            types, st_key, cr_key = (ATK, "st", "cr") if has_atk else (THROW, "thr_st", "thr_cr")
            st, cr, first = [], [], None
            for dfn in sorted(defenders):
                r, f0 = move_reach(anim, types, defenders[dfn][st_key])
                if r is not None:
                    st.append("%s=%d" % (dfn, r))
                    first = f0 if first is None else min(first, f0)
                r, f0 = move_reach(anim, types, defenders[dfn][cr_key])
                if r is not None:
                    cr.append("%s=%d" % (dfn, r))
            if not st and not cr:
                continue
            vel = bool(anim.get("uses_velocity")) or any(fr.get("velocity") for fr in frames)
            lines.append("    [\"%s\"] = { st = { %s }, cr = { %s }, f = %s, vel = %s, thr = %s }," % (
                anim["name"], ", ".join(st), ", ".join(cr), first if first is not None else "nil",
                "true" if vel else "false", "true" if not has_atk else "false"))
            n_moves += 1
        lines.append("  },")
    lines.append("}")
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("personajes:", len(chars), "golpes:", n_moves, "->", OUT)


if __name__ == "__main__":
    main()

