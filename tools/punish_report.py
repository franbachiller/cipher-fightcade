"""Reporte del lab de castigos: por escenario del muñeco, cuántas veces se castigó, daño medio y qué hizo el bot
(punish / post-parry / skip con motivo).  python -I tools\\punish_report.py <log> [<log>...]"""
import collections
import glob
import re
import sys

for arg in sys.argv[1:]:
    tag, _, pat = arg.rpartition("=") if "=" in arg else ("", "", arg)
    lines = []
    for path in sorted(glob.glob(pat)):
        lines += open(path, encoding="utf-8", errors="replace").read().splitlines()
    if not lines:
        print(pat, "sin logs")
        continue
    res = collections.defaultdict(list)          # escenario -> [(dmg, acciones)]
    acts = []
    for l in lines:
        m = re.match(r"\[\d+\] (combo-diag|punish-skip|whiff-diag|hit-diag)(.*)", l)
        if m:
            kind, rest = m.group(1), m.group(2)
            if kind == "combo-diag":
                acts.append(re.sub(r"\d+", "N", rest.strip().split(" got=")[0])[:50])
            elif kind == "punish-skip":
                w = re.search(r"why=(.+?) synced", rest)
                acts.append("SKIP " + (w.group(1) if w else "?"))
            elif kind == "hit-diag":
                acts.append("ME PEGARON")
            continue
        m = re.match(r"\[\d+\] dummy-res (\S+) d=(\d+) dmg=(\d+)", l)
        if m:
            res[m.group(1)].append((int(m.group(3)), acts))
            acts = []
    print("==", tag or pat)
    for sc, rows in res.items():
        n = len(rows)
        hit = sum(1 for d, _ in rows if d > 0)
        avg = sum(d for d, _ in rows) / max(1, n)
        c = collections.Counter(a for _, al in rows for a in al)
        print("  %-16s %2d intentos  castigado %2d (%3d%%)  daño medio %4.1f" % (sc, n, hit, 100 * hit // max(1, n), avg))
        for a, v in c.most_common(4):
            print("      %3d  %s" % (v, a))
