"""Junta las partes del lab de combos (combo_lab_char.ps1) en el archivo por SA que carga el bot y resume.
  python -I tools\\combo_lab_merge.py <char> <dummy> <sa...> <partes>"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
char, dummy, parts = sys.argv[1], sys.argv[2], int(sys.argv[-1])
sas = sys.argv[3:-1]
D = os.path.join(ROOT, "data", "sfiii3", "combos", "wiki")
for sa in sas:
    rows = []
    missing = 0
    for p in range(parts):
        f = os.path.join(D, "%s_sa%s_%s_p%d.lua" % (char, sa, dummy, p))
        if not os.path.exists(f):
            missing += 1
            continue
        rows += [l for l in open(f, encoding="utf-8").read().splitlines() if l.strip().startswith("{ text")]
        os.remove(f)
    if missing == parts:
        print("SA%s: sin resultados (¿falló el lab?)" % sa)
        continue
    out = os.path.join(D, "%s_sa%s_%s.lua" % (char, sa, dummy))
    with open(out, "w", encoding="utf-8") as f:
        f.write("-- generado por tools/wiki_combo_lab.lua (%s_sa%s_%s, %d partes): combos de la wiki verificados en emulador\n"
                "return {\n" % (char, sa, dummy, parts))
        for r in rows:
            f.write(r + "\n")
        f.write("}\n")
    ok = [re.search(r'text = "([^"]*)".*dmg = (\d+)', r) for r in rows if "ok = true" in r]
    bad = [re.search(r'text = "([^"]*)"', r).group(1) for r in rows if "ok = false" in r]
    print("SA%s: %d OK, %d FALLAN%s" % (sa, len(ok), len(bad), (" (faltan %d partes)" % missing) if missing else ""))
    for m in sorted(ok, key=lambda m: -int(m.group(2))):
        print("   OK %3s  %s" % (m.group(2), m.group(1)))
    for b in bad:
        print("   FALLA    %s" % b)
