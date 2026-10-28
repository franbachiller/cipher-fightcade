"""Reporte del health check en emulador (logs\\health_<char>.log): errores del brain, si llegó a pelear, rounds,
variedad de acciones, combos ejecutados y su daño real."""
import collections
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bad = 0
for arg in sys.argv[1:]:
    c, ext = arg.split(":")
    p = os.path.join(ROOT, "logs", "health_%s.log" % c)
    if not os.path.exists(p):
        print("%-7s %s  SIN LOG (no arrancó)" % (c, "online " if ext == "1" else "offline"))
        bad += 1
        continue
    L = open(p, encoding="utf-8", errors="replace").read().splitlines()
    errs = collections.Counter(re.sub(r"\d+", "N", l.split("] ", 1)[-1])[:120] for l in L if "error" in l.lower() and "fundamentals" in l or "attempt to" in l)
    frames = sum(1 for l in L if "match=true" in l)
    labels = collections.Counter(re.sub(r"\d+", "N", m.group(1)).split(" ")[0] for l in L for m in [re.search(r"\[([^\[\]]+)\](?: radar=\S+)?$", l)] if m and "match=true" in l)
    combos = [int(m.group(1)) for l in L for m in [re.search(r"combo-diag .* got=(\d+)", l)] if m]
    rounds = [l for l in L if "ROUND" in l]
    ok = not errs and frames > 0
    bad += 0 if ok else 1
    print("%-7s %s %s  muestras=%d acciones=%d rounds=%d combos=%d (daño med %s)" % (
        c, "online " if ext == "1" else "offline", "OK  " if ok else "FALLA", frames, len(labels), len(rounds),
        len(combos), sorted(combos)[len(combos) // 2] if combos else "-"))
    for e, n in errs.most_common(5):
        print("     %3dx %s" % (n, e))
print("\n%s" % ("TODO OK" if bad == 0 else "%d personajes con problemas" % bad))
