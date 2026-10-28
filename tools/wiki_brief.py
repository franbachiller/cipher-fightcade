"""Extrae de la página de estrategia de un personaje las secciones útiles para el bot (neutral, pokes, anti-air,
ofensiva, okizeme, super art) con un tope de caracteres por sección."""
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
W = r"C:\Users\bachi\Desktop\CIPHER-Fightcade\data\sfiii3\wiki"
KEYS = re.compile(r"neutral|poke|anti|offen|oki|wake|pressure|mixup|super art|basic|overview|footsie|zon|game ?plan|tip", re.I)
LIMIT = int(sys.argv[2]) if len(sys.argv) > 2 else 1800

for char in sys.argv[1].split(","):
    path = None
    for name in (char + "_Strategy.md", char + ".md"):
        p = os.path.join(W, name)
        if os.path.exists(p) and os.path.getsize(p) > 3000:
            path = p
            break
    print("#" * 30, char, os.path.basename(path or "-"))
    if not path:
        continue
    t = open(path, encoding="utf-8").read()
    i = t.find("From SuperCombo Wiki")
    t = t[i:] if i >= 0 else t
    t = t.split("3S Navigation")[0]
    t = re.sub(r"\n\s*\|\s*\n", " | ", t)
    t = re.sub(r"\n{2,}", "\n", t)
    parts = re.split(r"\n(?=#{1,5} )", t)
    for part in parts:
        head = part.split("\n", 1)[0]
        if KEYS.search(head):
            print(part[:LIMIT].strip())
            print("...")
