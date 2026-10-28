"""Auditoría del SA en las sesiones online: qué SA quiso elegir el bot en la pantalla de SA y con cuál peleó de verdad
(RAM), y cuándo se "recordó" (aprendió) un SA distinto.  python -I tools\\sa_audit.py [desde]"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
since = sys.argv[1] if len(sys.argv) > 1 else ""
for p in sorted(glob.glob(os.path.join(ROOT, "logs", "online", "*.log"))):
    if os.path.basename(p) < since:
        continue
    ev = []
    want = None
    for l in open(p, encoding="utf-8", errors="replace"):
        m = re.search(r"pantalla de SA: (\w+) -> elijo SA (\w+)", l)
        if m:
            want = (m.group(1), m.group(2))
            ev.append("elige %s SA %s" % want)
        m = re.search(r"pantalla de SA: el cursor .*", l)
        if m:
            ev.append("ABORTA: " + m.group(0))
        m = re.search(r"SA recordado: (\w+) -> SA (\w+) \S+ \(antes (\w+)\)", l)
        if m:
            ev.append("APRENDE %s SA %s (antes %s)" % (m.group(1), m.group(2), m.group(3)))
        m = re.search(r"PELEA \w+: (\w+) \(SA (\w+) [^)]*\) vs (\w+)", l)
        if m:
            tag = ""
            if want and want[0] == m.group(1) and want[1] != m.group(2):
                tag = "   <-- QUERÍA SA %s" % want[1]
            if not want or want[0] != m.group(1):
                tag += "   (sin elección del bot)"
            ev.append("pelea %s con SA %s vs %s%s" % (m.group(1), m.group(2), m.group(3), tag))
            want = None
    if ev:
        print("==", os.path.basename(p))
        for e in ev:
            print("  ", e)
