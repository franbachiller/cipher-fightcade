"""Resumen de la verificación de combos (data/sfiii3/combos/wiki/*.lua): OK por personaje y SA, mejores combos,
errores del lab.  python -I tools\\combo_results.py [char]"""
import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
only = sys.argv[1] if len(sys.argv) > 1 else None
out = collections.defaultdict(lambda: collections.defaultdict(list))
for p in glob.glob(os.path.join(ROOT, "data", "sfiii3", "combos", "wiki", "*.lua")):
    m = re.match(r"(\w+?)_sa(\d)_", os.path.basename(p))
    if not m or (only and m.group(1) != only):
        continue
    for t, ok, d, dmg, hits in re.findall(r'text = "(.*?)", ok = (\w+), d = (\d+), sa = \d, dmg = (\d+), hits = (\d+)',
                                           open(p, encoding="utf-8").read()):
        out[m.group(1)][int(m.group(2))].append((ok == "true", int(dmg), int(hits), t))
errs = collections.Counter()
for p in glob.glob(os.path.join(ROOT, "logs", "wiki_combo_lab_*_ryu.log")):
    for l in open(p, encoding="utf-8", errors="replace"):
        if l.startswith("ERROR"):
            errs[re.sub(r"\d", "N", l.strip())[:60]] += 1
print("errores del lab:", dict(errs) or "ninguno")
tot = 0
for c in sorted(out):
    parts = []
    for sa in sorted(out[c]):
        v = out[c][sa]
        ok = [x for x in v if x[0]]
        tot += len(ok)
        parts.append("SA%d %d/%d (max %d)" % (sa, len(ok), len(v), max([x[1] for x in ok] or [0])))
    print("%-7s %s" % (c, "   ".join(parts)))
    if only:
        for sa in sorted(out[c]):
            for x in sorted(out[c][sa], key=lambda x: -x[1]):
                print("   SA%d %s dmg=%3d hits=%2d  %s" % (sa, "OK  " if x[0] else "FAIL", x[1], x[2], x[3]))
print("total OK:", tot)
