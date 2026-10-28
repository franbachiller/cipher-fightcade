"""Junta y limpia (sin navegación) las páginas de la wiki de cada personaje: Strategy + Combos + Matchups + notas de
golpes de la página principal -> data\\sfiii3\\wiki\\digest\\<char>.md, para leerlas y armar las tablas del bot."""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W = os.path.join(ROOT, "data", "sfiii3", "wiki")
OUT = os.path.join(W, "digest")


def body(path):
    if not os.path.exists(path):
        return ""
    t = open(path, encoding="utf-8").read()
    i = t.find("From SuperCombo Wiki")
    t = t[i + 20:] if i >= 0 else t
    for stop in ("## 3S Navigation", "3S Navigation", "Retrieved from"):
        j = t.find(stop)
        if j >= 0:
            t = t[:j]
    t = re.sub(r"\n- \n", "\n", t)
    t = re.sub(r"(?m)^\s*(Share this page|More actions|Tools|What links here|Related changes|Printable version|"
               r"Permanent link|Page information|Cargo data|Overview|Starter Guide|Combos|Matchups|Strategy|Resources|Archive)\s*$", "", t)
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t.strip()


def main():
    os.makedirs(OUT, exist_ok=True)
    chars = sorted({re.sub(r"_(Strategy|Combos|Matchups|Resources|Archive)$", "", f[:-3])
                    for f in os.listdir(W) if f.endswith(".md") and not f.startswith("_")} -
                   {"System", "Controls", "FAQ", "Glossary", "HUD", "Notation"})
    for c in chars:
        parts = []
        for suf, title in (("_Strategy", "STRATEGY"), ("_Combos", "COMBOS"), ("_Matchups", "MATCHUPS"), ("", "MAIN")):
            b = body(os.path.join(W, c + suf + ".md"))
            if b:
                parts.append("=" * 20 + " " + title + "\n" + b)
        with open(os.path.join(OUT, c + ".md"), "w", encoding="utf-8") as f:
            f.write("\n\n".join(parts) + "\n")
        print("%-10s %7d" % (c, sum(len(p) for p in parts)))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
