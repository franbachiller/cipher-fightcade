"""Causa del primer golpe de cada combo recibido: la última acción que el bot DECIDIÓ antes (líneas "bot: ...")
y si estaba en el aire / parado.  python -I tools\\hit_causes.py [desde]"""
import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
since = sys.argv[1] if len(sys.argv) > 1 else "2026-10-21_1100"
air_c, stand_c = collections.Counter(), collections.Counter()
n_air = n_stand = 0
for p in sorted(glob.glob(os.path.join(ROOT, "logs", "online", "*.log"))):
    if os.path.basename(p) < since:
        continue
    last_hit, decisions = -999, []
    for l in open(p, encoding="utf-8", errors="replace"):
        m = re.match(r"\[(\d+)\] bot: (.+)", l) or re.match(r"\[(\d+)\] match=true .*\[([^\[\]]+)\]$", l)
        if m:
            decisions.append((int(m.group(1)), re.sub(r"\d+", "N", m.group(2)).split(" vs ")[0][:40]))
            decisions = decisions[-30:]
            continue
        m = re.match(r"\[(\d+)\] hit-diag .*? posture=(\S+) .*? air=(\w+)", l)
        if not m:
            continue
        fr = int(m.group(1))
        first = fr - last_hit > 40
        last_hit = fr
        if not first:
            continue
        # última decisión que NO sea defensiva (la que lo dejó expuesto), en los 60 frames previos
        cause = "?"
        for t, d in reversed(decisions):
            if fr - t > 130:
                break
            if not re.match(r"(block|effie|guardia|neutral para parry|throw tech|parry)", d):
                cause = d
                break
        if m.group(3) == "true":
            n_air += 1
            air_c[cause] += 1
        elif m.group(2) == "0":
            n_stand += 1
            stand_c[cause] += 1
print("EN EL AIRE (%d) - acción previa:" % n_air)
for k, v in air_c.most_common(14):
    print("  %4d  %s" % (v, k))
print("\nPARADO (%d) - acción previa:" % n_stand)
for k, v in stand_c.most_common(18):
    print("  %4d  %s" % (v, k))
