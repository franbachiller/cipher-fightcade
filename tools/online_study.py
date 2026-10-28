"""Estudio agregado de sesiones online: combos (qué se ejecutó y cuánto pegó de verdad), supers / barra, okizeme,
castigos, agarres y golpes recibidos.  python -I tools\\online_study.py [desde_YYYY-MM-DD_HHMM]"""
import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
since = sys.argv[1] if len(sys.argv) > 1 else "2026-10-21_0825"
only_char = sys.argv[2] if len(sys.argv) > 2 else None       # filtrar a cuando el bot jugaba con ese personaje
logs = [p for p in sorted(glob.glob(os.path.join(ROOT, "logs", "online", "*.log"))) if os.path.basename(p) >= since]

combo = collections.defaultdict(list)       # etiqueta -> daños reales
kinds = collections.Counter()
oki = collections.Counter()
oki_plan = collections.Counter()
labels = collections.Counter()
supers = collections.Counter()
knock = 0
hits = collections.Counter()
meter_end = []
for p in logs:
    cur = None
    for l in open(p, encoding="utf-8", errors="replace"):
        m = re.search(r"match=true .*?\| P1 (\w+) hp=.*?\| P2 (\w+) hp=.*bot=true P(\d)", l)
        if m:
            cur = m.group(1) if m.group(3) == "1" else m.group(2)
        if only_char and cur != only_char:
            continue
        m = re.search(r"combo-diag (.+?) got=(\d+)", l)
        if m:
            lab = re.sub(r" \(\+walk \d+\)| \(rec \d+\)|\[\d+\]", "", m.group(1)).strip()
            combo[lab].append(int(m.group(2)))
            kinds[lab.split(" ")[0]] += 1
        m = re.search(r"oki-diag (\w+) (\S+)", l)
        if m:
            oki[m.group(1)] += 1
        m = re.search(r"match=true .*\[([^\[\]]+)\]$", l)
        if m:
            lab = re.sub(r"\d+", "N", m.group(1))
            labels[lab[:40]] += 1
            if lab.startswith("oki"):
                oki_plan[lab.split(":")[0] if ":" not in lab else lab.split(":")[1].strip().split(" ")[0]] += 1
        if re.search(r"(shoryu_reppa|shinryuuken|shippu|messatsu|houyokusen|kikoushou|tenseiranka|supreme_rising|light_of_justice|"
                     r"brave_dance|spinning_beat|kasumisuzaku|yamishigure|tyrant|temporal|aegis|gigas|megaton|hammer|boomerang|"
                     r"hyper_bomb|stungun|rolling_thunder|corkscrew|rocket_upper|seichusen|abare|tanden|shinkuu|shin_shoryuken|denjin|"
                     r"hadou_burst|shoryu_cannon|hyper_tornado|xndl|xflat|xcopy|raishin|tenshin|seiei|youhou|sourai|geneijin|"
                     r"yagyou|tengu|kishin|critical|deadly_double|total_destruction|magnetic|slam_dance|electric|\bSA\b)", l) and "match=true" in l:
            m = re.search(r"\[([^\[\]]+)\]$", l)
            if m:
                supers[re.sub(r"\d+", "N", m.group(1))[:60]] += 1
        m = re.search(r"hit-diag op=(\S+).*?label=(.+?) prev=", l)
        if m:
            hits[re.sub(r" vs .*|\d+", "", m.group(2))[:30]] += 1

print("sesiones:", len(logs))
print("\n== combos ejecutados (combo-diag: daño REAL 120f después) ==")
print("por tipo:", dict(kinds))
rows = sorted(combo.items(), key=lambda kv: -len(kv[1]))
for lab, v in rows[:30]:
    print("  %3dx  med=%3d  max=%3d  ceros=%2d  %s" % (len(v), sorted(v)[len(v) // 2], max(v), sum(1 for x in v if x == 0), lab[:80]))
print("\n== supers / etiquetas con super (muestras de estado) ==")
for k, v in supers.most_common(15):
    print("  %3d  %s" % (v, k))
print("\n== okizeme ==  resultados meaty:", dict(oki), " planes:", dict(oki_plan))
print("\n== estado del bot al recibir golpes ==")
for k, v in hits.most_common(15):
    print("  %3d  %s" % (v, k))
print("\n== acciones más comunes ==")
for k, v in labels.most_common(30):
    print("  %3d  %s" % (v, k))
