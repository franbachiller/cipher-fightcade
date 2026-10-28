"""Primer golpe de cada combo recibido (sin otro golpe en los 40 frames anteriores): qué movimiento del rival, qué
hacía el bot y en qué postura estaba. Separa los golpes "gratis" (el bot creía bloquear) de los demás.
  python -I tools\\first_hits.py [desde_YYYY-MM-DD_HHMM]"""
import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
since = sys.argv[1] if len(sys.argv) > 1 else "2026-10-21_1100"
POST = {"0": "parado", "24": "agachado", "32": "agachado?", "20": "agach/levant", "38": "agarrado", "2": "?"}
firsts = []
for p in sorted(glob.glob(os.path.join(ROOT, "logs", "online", "*.log"))):
    if os.path.basename(p) < since:
        continue
    last = -999
    for l in open(p, encoding="utf-8", errors="replace"):
        m = re.match(r"\[(\d+)\] hit-diag op=(\S+) af=(\d+) d=(\d+) my_move=(\S+) posture=(\S+) label=(.+?) prev=(.+?) effie=(\w+) lat=(\d+) air=(\w+) op_air=(\w+)", l)
        if not m:
            continue
        fr = int(m.group(1))
        if fr - last > 40:
            firsts.append(dict(op=m.group(2).replace("_ext", ""), af=int(m.group(3)), d=int(m.group(4)), my=m.group(5),
                               post=m.group(6), label=re.sub(r" vs .*|\d+", "", m.group(7)).strip(), air=m.group(11),
                               op_air=m.group(12)))
        last = fr
print("combos recibidos (primer golpe):", len(firsts))
c = collections.Counter(f["label"] for f in firsts)
print("\nqué hacía el bot:")
for k, v in c.most_common(12):
    print("  %4d  %s" % (v, k))
blk = [f for f in firsts if f["label"].startswith("block") or f["label"].startswith("effie") or f["label"].startswith("guardia")]
print("\n'bloqueando' y le pegaron igual: %d — postura:" % len(blk), dict(collections.Counter(POST.get(f["post"], f["post"]) for f in blk)))
print("  en el aire (yo):", sum(1 for f in blk if f["air"] == "true"), "  rival en el aire:", sum(1 for f in blk if f["op_air"] == "true"))
print("  golpes que los abrieron:")
for k, v in collections.Counter(f["op"] for f in blk).most_common(20):
    print("    %4d  %s" % (v, k))
print("  distancia:", sorted(f["d"] for f in blk)[::max(1, len(blk) // 25)])
