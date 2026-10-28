"""Precisión online por tipo de decisión (todas las sesiones desde una fecha, todos los personajes):
castigos / confirms / post-parry / remates (combo-diag got), parries, techs, oki, agarres, jump-ins recibidos.
  python -I tools\\precision.py [desde_YYYY-MM-DD_HHMM]"""
import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
since = sys.argv[1] if len(sys.argv) > 1 else "2026-10-21_0000"
cd = collections.defaultdict(lambda: [0, 0, 0])      # tipo -> [intentos, got=0, daño total]
cd_char = collections.defaultdict(lambda: [0, 0])
cnt = collections.Counter()
air_hits = collections.Counter()
whiffs = collections.Counter()
skips = collections.Counter()
for p in sorted(glob.glob(os.path.join(ROOT, "logs", "online", "*.log"))):
    if os.path.basename(p) < since:
        continue
    me = "?"
    for l in open(p, encoding="utf-8", errors="replace"):
        m = re.search(r"\| P\d (\w+) hp=\d+ x=\d+ y=\d+ \| P\d \w+ .*bot=true", l)
        m2 = re.search(r"\] match=\w+ .*\| P1 (\w+) hp.*\| P2 (\w+) hp.*bot=true P(\d)", l)
        if m2:
            me = m2.group(1) if m2.group(3) == "1" else m2.group(2)
        m = re.match(r"\[\d+\] combo-diag (\S+)(?: (\S+))?.*got=(\d+)", l)
        if m:
            kind = m.group(1)
            if kind == "punish" and m.group(2) and ("shippu" in l or "super crudo" in l or "SA" in m.group(2)):
                kind = "punish(super)" if "xx" not in l else "punish"
            got = int(m.group(3))
            c = cd[kind]
            c[0] += 1
            c[1] += got == 0
            c[2] += got
            cc = cd_char[(me, kind)]
            cc[0] += 1
            cc[1] += got == 0
            continue
        m = re.match(r"\[\d+\] parry-diag (\S+) k=\d+ move=(\S+)", l)
        if m:
            cnt["parry " + m.group(1)] += 1
            continue
        m = re.match(r"\[\d+\] tech-result (\S+)", l)
        if m:
            cnt["tech " + m.group(1)] += 1
            continue
        m = re.match(r"\[\d+\] oki-diag (\S+)", l)
        if m:
            cnt["oki " + m.group(1)] += 1
            continue
        m = re.match(r"\[\d+\] grab-diag (GRAB|JUMPED|MISS)", l)
        if m:
            cnt["agarre " + m.group(1)] += 1
            continue
        m = re.match(r"\[\d+\] punish-skip op=(\S+) rec=(\d+) .* why=(.+?) synced", l)
        if m:
            skips[m.group(3)] += 1
            continue
        m = re.match(r"\[\d+\] whiff-diag move=(\S+) label=(.+) d=(\d+)", l)
        if m:
            whiffs[re.sub(r" vs .*|\d+|\(.*\)|\[.*\]", "", m.group(2)).strip()] += 1
            continue
        m = re.match(r"\[\d+\] hit-diag op=(\S+) .* label=(.+?) prev=.* op_air=true", l)
        if m and re.match(r"u", m.group(1)):
            air_hits[re.sub(r" vs .*|\d+", "", m.group(2)).strip()] += 1
print("combo-diag por tipo: intentos / got=0 / daño medio")
for k, (n, z, dmg) in sorted(cd.items(), key=lambda x: -x[1][0]):
    print("  %-16s %4d  %3d%% nulos  %5.1f" % (k, n, 100 * z // max(1, n), dmg / max(1, n)))
print("\npor personaje (got=0 / intentos):")
by = collections.defaultdict(list)
for (ch, kind), (n, z) in cd_char.items():
    by[ch].append("%s %d/%d" % (kind, z, n))
for ch in sorted(by):
    print("  %-8s %s" % (ch, ", ".join(sorted(by[ch]))))
print("\nresultados:")
for k, v in sorted(cnt.items()):
    print("  %-16s %d" % (k, v))
print("\nataques de salto recibidos (qué hacía el bot):")
for k, v in air_hits.most_common(8):
    print("  %4d  %s" % (v, k))
print("\ngolpes al aire (whiff-diag) por decisión:")
for k, v in whiffs.most_common(15):
    print("  %4d  %s" % (v, k))
print("\ncastigos dejados pasar (punish-skip) por motivo:")
for k, v in skips.most_common(10):
    print("  %4d  %s" % (v, k))
