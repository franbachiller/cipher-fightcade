"""Aplana las páginas de combos de la wiki para leerlas: íconos -> notación (D.png + Mp.png -> 2MP), filas de tabla en
una línea. Solo lectura humana; los combos se curan a mano en data/sfiii3/wiki_combos.lua y se verifican en emulador.
  python -I tools\\wiki_flat.py Ken  ->  logs\\wiki_flat\\Ken.txt
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W = os.path.join(ROOT, "data", "sfiii3", "wiki")
OUT = os.path.join(ROOT, "logs", "wiki_flat")
DIRS = {"D": "2", "Df": "3", "Db": "1", "F": "6", "B": "4", "U": "8", "Uf": "9", "Ub": "7",
        "Qcf": "236", "Qcb": "214", "Dp": "623", "Rdp": "421", "Hcf": "41236", "Hcb": "63214", "360": "360"}


def flat(txt):
    txt = re.sub(r"\[(\w+)\.png\]\s*\+\s*", lambda m: DIRS.get(m.group(1).capitalize(), m.group(1)), txt)
    txt = re.sub(r"\[(\w+)\.png\]", lambda m: DIRS.get(m.group(1).capitalize(), m.group(1).upper()), txt)
    # tablas: "| \n celda \n |" -> una fila por línea
    rows, cur = [], []
    for line in txt.splitlines():
        s = line.strip()
        if s in ("|", "| |"):
            if cur:
                rows.append(" | ".join(cur))
                cur = []
            continue
        if s.endswith("|") or s.startswith("|"):
            cell = s.strip("|").strip()
            if cell:
                cur.append(cell)
            continue
        if cur:
            rows.append(" | ".join(cur))
            cur = []
        if s:
            rows.append(s)
    if cur:
        rows.append(" | ".join(cur))
    return "\n".join(r for r in rows if r)


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or [f[:-10] for f in os.listdir(W) if f.endswith("_Combos.md")]
    for n in names:
        p = os.path.join(W, n + "_Combos.md")
        if not os.path.exists(p):
            p = os.path.join(W, n + ".md")
        t = flat(open(p, encoding="utf-8").read())
        open(os.path.join(OUT, n + ".txt"), "w", encoding="utf-8").write(t)
        print(n, len(t))


if __name__ == "__main__":
    main()
