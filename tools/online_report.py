"""Resumen de sesiones online (logs\\online\\*.log): rounds, golpes recibidos por movimiento del rival y estado del bot,
techs y agarres. Filtra por rival:  python -I tools\\online_report.py [rival1,rival2] [N_logs]"""
import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rivals = sys.argv[1].split(",") if len(sys.argv) > 1 and sys.argv[1] else None
n = int(sys.argv[2]) if len(sys.argv) > 2 else 4
logs = sorted(glob.glob(os.path.join(ROOT, "logs", "online", "*.log")), key=os.path.getmtime)[-n:]
for path in logs:
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    if rivals and not any(re.search(r"P2[ =](%s)\b" % r, l) for l in lines for r in rivals):
        continue
    print("=====", os.path.basename(path))
    for l in lines:
        if "PELEA" in l or "ROUND" in l:
            print(" ", l[:230])
    hits = collections.Counter()
    for l in lines:
        m = re.search(r"hit-diag op=(\S+).*?label=(.+?) prev=", l)
        if m:
            lab = re.sub(r" vs .*", "", re.sub(r"\d+", "N", m.group(2)))
            hits["%-28s | %s" % (m.group(1).replace("_ext", ""), lab)] += 1
    print("  -- golpes recibidos (movimiento rival | lo que hacía el bot):")
    for k, v in hits.most_common(16):
        print("   %3d  %s" % (v, k))
    labs = collections.Counter()
    for l in lines:
        m = re.search(r"match=true .*\[([^\[\]]+)\]$", l)
        if m:
            labs[re.sub(r"\d+", "N", m.group(1))[:50]] += 1
    print("  -- acciones del bot (muestras cada 60f):")
    for k, v in labs.most_common(18):
        print("   %3d  %s" % (v, k))
    ds = [int(m.group(1)) for l in lines for m in [re.search(r"hit-diag .*? d=(\d+)", l)] if m]
    if ds:
        print("  -- distancia al recibir golpe/agarre:", sorted(ds))
    ev = collections.Counter()
    for l in lines:
        m = re.search(r"(tech-result \S+ op=\S+|grab-diag \S+ \S+|tech-diag thrown: .*?prev=.*)", l)
        if m:
            ev[re.sub(r"\d+", "N", m.group(1))[:110]] += 1
    print("  -- agarres / techs:")
    for k, v in ev.most_common(14):
        print("   %3d  %s" % (v, k))
