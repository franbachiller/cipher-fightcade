"""Resumen para armar una tabla: normales de piso (anim, 1er frame activo, alcance vs Ryu de pie/agachado) y especiales
con su input desde la move list. Uso: python -I tools\\char_moves.py makoto,yang"""
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
R = open(r"C:\Users\bachi\Desktop\CIPHER-Fightcade\data\sfiii3\ranges.lua", encoding="utf-8").read()
for char in sys.argv[1].split(","):
    print("#" * 20, char)
    cur, out = None, []
    for line in R.splitlines():
        m = re.match(r'  \["(\w+)"\] = \{$', line)
        if m:
            cur = m.group(1)
            continue
        m = re.match(r'    \["(\w+)"\] = \{ st = \{ (.*?) \}, cr = \{ (.*?) \}, f = (\w+), vel = (\w+), thr = (\w+)', line)
        if m and cur == char and not re.match(r"^(u|uf|ub|j|sj)_|_air|_ext", m.group(1)):
            st = dict(x.split("=") for x in m.group(2).split(", ") if x)
            cr = dict(x.split("=") for x in m.group(3).split(", ") if x)
            out.append("%s f%s %s/%s%s" % (m.group(1), m.group(4), st.get("ryu"), cr.get("ryu"), " T" if m.group(6) == "true" else ""))
    print("  " + " | ".join(out))
    try:
        mv = open(r"C:\Users\bachi\Desktop\CIPHER-Fightcade\data\sfiii3\moves\%s.lua" % char, encoding="utf-8").read()
        for m in re.finditer(r'name="(\w+)",type="(\w+)"[^}]*?\{btn="(\w*)",seq=(\{.*?\}\})(,charge="(\w)")?', mv):
            print("  %-22s [%s]%s %s" % (m.group(1), m.group(2), " charge=" + m.group(6) if m.group(6) else "", m.group(4)))
    except OSError:
        pass
