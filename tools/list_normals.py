"""Lista las animaciones con golpe de un personaje (nombre, startup, alcance vs ryu de pie/agachado) desde ranges.lua."""
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
char = sys.argv[1]
t = open(r"C:\Users\bachi\Desktop\CIPHER-Fightcade\data\sfiii3\ranges.lua", encoding="utf-8").read()
cur = None
for line in t.splitlines():
    m = re.match(r'  \["(\w+)"\] = \{$', line)
    if m:
        cur = m.group(1)
        continue
    m = re.match(r'    \["(\w+)"\] = \{ st = \{ (.*?) \}, cr = \{ (.*?) \}, f = (\w+), vel = (\w+), thr = (\w+)', line)
    if m and cur == char:
        st = dict(x.split("=") for x in m.group(2).split(", ") if x)
        cr = dict(x.split("=") for x in m.group(3).split(", ") if x)
        print("%-28s f=%-4s st=%-4s cr=%-4s vel=%s thr=%s" % (m.group(1), m.group(4), st.get("ryu"), cr.get("ryu"), m.group(5), m.group(6)))
