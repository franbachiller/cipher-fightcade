"""Analiza un log de CIPHER: python -I analyze_log.py <log> [rival]  -> por rival: golpes recibidos, agarres, parries."""
import re, sys, collections
path = sys.argv[1]; only = sys.argv[2] if len(sys.argv) > 2 else None
opp = None
stats = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
for line in open(path, encoding="utf-8", errors="replace"):
    m = re.search(r"\| P1 (\w+) hp=\d+ .*\| P2 (\w+) hp=", line)
    if m:
        opp = m.group(2) if m.group(1) == "ken" else m.group(1)
    if only and opp != only:
        continue
    m = re.search(r"parry-diag (\S+) .*move=(\S+)", line)
    if m: stats[opp]["parry:" + m.group(1)][m.group(2)] += 1
    m = re.search(r"tech-diag thrown: .*op=(\S+)", line)
    if m: stats[opp]["thrown"][m.group(1)] += 1
    m = re.search(r"pp-diag (.+?)(?: \(\+walk \d+\))? dmg=(\d+)", line)
    if m: stats[opp]["pp"][m.group(1) + (" OK" if int(m.group(2)) > 0 else " miss")] += 1
    m = re.search(r"bot: (anti-air|tech)", line)
    if m: stats[opp]["acts"][m.group(1)] += 1
for o, kinds in stats.items():
    print(f"=== {o}")
    for k, c in sorted(kinds.items()):
        print(f"  {k:14s} " + ", ".join(f"{n}={v}" for n, v in c.most_common(8)))
