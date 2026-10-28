"""Tier list de CIPHER + SA de cada personaje.
- SA: recomendación de la wiki (data/sfiii3/wiki_sa.lua, tools/wiki_sa.py) cruzada con lo que el bot puede usar de
  verdad (combos con super verificados en emulador). Se escribe en data/sfiii3/sa_pick.lua (la autoridad: el bot ya
  no "aprende" el SA de la pelea).
- Tier: rendimiento MEDIDO del bot con cada personaje: historial online (logs/online/historial.csv) + combos
  verificados para su SA (cantidad y daño máximo). Sale en data/sfiii3/tier_list.md.
  python -I tools\\tier_list.py"""
import collections
import csv
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHARS = ["alex", "chunli", "dudley", "elena", "gouki", "hugo", "ibuki", "ken", "makoto", "necro", "oro", "q", "remy",
         "ryu", "sean", "twelve", "urien", "yang", "yun"]
NAMES = {"alex": "Alex", "chunli": "Chun-Li", "dudley": "Dudley", "elena": "Elena", "gouki": "Akuma", "hugo": "Hugo",
         "ibuki": "Ibuki", "ken": "Ken", "makoto": "Makoto", "necro": "Necro", "oro": "Oro", "q": "Q", "remy": "Remy",
         "ryu": "Ryu", "sean": "Sean", "twelve": "Twelve", "urien": "Urien", "yang": "Yang", "yun": "Yun"}

# SA elegido y por qué (wiki + capacidad real del bot). "wiki:" = lo que dice la página; "bot:" = dato medido
SA = {
    "ken": (3, "wiki: SA3 'Recomended / the universal choice'; SA1 y SA2 'Not recommended'"),
    "chunli": (2, "wiki: SA2 'Very, very recommended'; SA3 'Not recommended'"),
    "makoto": (1, "wiki: SA1 'Highly recommended'"),
    "hugo": (3, "wiki: SA1 y SA3 'Recommended'; bot: Gigas (agarre) no tiene combos, SA3 sí (2LP > 2LP xx SA, 60)"),
    "gouki": (1, "wiki: SA1 'by far the most practical choice'"),
    "alex": (2, "wiki: SA2 'the super of choice for Alex'"),
    "q": (1, "wiki: SA1 'usually the best choice'"),
    "twelve": (1, "wiki: SA1 'your go-to pick'"),
    "oro": (2, "wiki: SA1 'Not recommended'; SA2 loops / SA3 presión; bot: SA2 3 combos, SA3 1"),
    "urien": (3, "wiki: SA1 y SA2 'Not Recommended', SA3 'Character defining'"),
    "remy": (2, "wiki: SA2 'Midscreen damage and punishes'; SA3 'Pay one bar of meter to lose'"),
    "dudley": (1, "wiki: SA1 'one of Dudley's two best'; SA2 'the least popular option'"),
    "elena": (2, "wiki: SA2 'where it really shines' (SA1 empata en EX); bot: SA2 3 combos (max 65)"),
    "necro": (3, "wiki (página Necro): 'Super Art 3 is the main'"),
    "ibuki": (3, "wiki: SA3 'easy to combo into from a plethora of options'; bot: SA3 10 combos, SA1 1"),
    "ryu": (2, "wiki: SA2 'devastating'; SA3 (Denjin) exige cargar con el botón: el bot no lo hace; bot: SA2 16 combos, max 91"),
    "sean": (3, "wiki: SA3 '1f nuke'; SA2 'poor hit-confirm range'; bot: SA3 13 combos, max 73"),
    "yang": (1, "wiki: SA3 es instalación (el bot no la explota); SA1 '74 de daño, invencible'; bot: SA1 5 combos, max 69"),
    "yun": (2, "wiki: 'Sourai Rengeki would likely be Yun's first choice if Genei Jin wasn't so dominant'; "
               "Genei-Jin necesita combos en vivo que el bot no verificó"),
}

# combos verificados por personaje y SA (lo que carga el brain)
combos = collections.defaultdict(lambda: collections.defaultdict(list))
for p in glob.glob(os.path.join(ROOT, "data", "sfiii3", "combos", "wiki", "*.lua")):
    m = re.match(r"(\w+?)_sa(\d)_", os.path.basename(p))
    if not m:
        continue
    for t, ok, dmg in re.findall(r'text = "(.*?)", ok = (\w+), d = \d+, sa = \d, dmg = (\d+)', open(p, encoding="utf-8").read()):
        if ok == "true":
            has_super = bool(re.search(r"\bSA\b|SA:", t))
            combos[m.group(1)][int(m.group(2)) if has_super else 0].append((int(dmg), t))

# historial online
hist = collections.defaultdict(lambda: {"w": 0, "l": 0, "dealt": 0, "taken": 0})
path = os.path.join(ROOT, "logs", "online", "historial.csv")
if os.path.exists(path):
    for row in csv.reader(open(path, encoding="utf-8", errors="replace")):
        if len(row) < 10 or not row[2] in CHARS:
            continue
        h = hist[row[2]]
        if row[7].startswith("GAN"):
            h["w"] += 1
        else:
            h["l"] += 1
        h["dealt"] += int(row[8] or 0)
        h["taken"] += int(row[9] or 0)

rows = []
for c in CHARS:
    sa, why = SA[c]
    sup = sorted(combos[c][sa], reverse=True)
    base = sorted(combos[c][0], reverse=True)
    h = hist[c]
    n = h["w"] + h["l"]
    wr = h["w"] / n if n else None
    ratio = h["dealt"] / max(1, h["taken"]) if n else None
    # puntaje: online pesa según cuántas peleas hay (con 1-2 peleas casi no cuenta); combos: cantidad y daño máximo
    k_online = min(1.0, n / 6)
    online = ((wr - 0.5) * 60 + (min(ratio, 2) - 1) * 30) if n else 0
    combo_sc = min(len(sup), 15) * 1.5 + (sup[0][0] if sup else 0) * 0.35 + min(len(base), 20) * 0.6
    score = online * k_online + combo_sc
    rows.append((score, c, sa, why, sup, base, h, n, wr, ratio))
rows.sort(reverse=True)
tiers = []
for i, r in enumerate(rows):
    q = i / len(rows)
    tiers.append("S" if q < 0.16 else "A" if q < 0.42 else "B" if q < 0.74 else "C")

# sa_pick.lua (autoridad)
lines = ["-- SA de cada personaje para CIPHER (tools/tier_list.py): recomendación de la wiki + lo que el bot puede usar.",
         "-- Es la autoridad: el bot lo elige en la pantalla de SA y ya NO lo cambia por el SA con que se peleó.", "return {"]
for c in sorted(CHARS):
    lines.append('  ["%s"] = %d,' % (c, SA[c][0]))
lines.append("}")
open(os.path.join(ROOT, "data", "sfiii3", "sa_pick.lua"), "w", encoding="utf-8").write("\n".join(lines) + "\n")

# tier_list.md
md = ["# CIPHER — tier list del bot (SF3 3rd Strike)", "",
      "Rendimiento **medido** de CIPHER con cada personaje, no el tier competitivo humano. Puntaje = historial online",
      "(pesa según cuántas peleas hay) + combos verificados en emulador para su SA. Se regenera con",
      "`python -I tools\\tier_list.py` después de jugar o de verificar combos.", "",
      "| Tier | Personaje | SA | Online (G-P) | Daño hecho/recibido | Combos con super | Mejor combo con super | Combos sin barra |",
      "|---|---|---|---|---|---|---|---|"]
ROMAN = {1: "I", 2: "II", 3: "III"}
for t, r in zip(tiers, rows):
    score, c, sa, why, sup, base, h, n, wr, ratio = r
    md.append("| %s | %s | SA %s | %s | %s | %d | %s | %d |" % (
        t, NAMES[c], ROMAN[sa], ("%d-%d" % (h["w"], h["l"])) if n else "—", ("%.2f" % ratio) if n else "—",
        len(sup), ("%s (%d)" % (sup[0][1], sup[0][0])) if sup else "—", len(base)))
md += ["", "## Por qué ese SA", ""]
for c in sorted(CHARS, key=lambda x: NAMES[x]):
    md.append("- **%s — SA %s**: %s" % (NAMES[c], ROMAN[SA[c][0]], SA[c][1]))
open(os.path.join(ROOT, "data", "sfiii3", "tier_list.md"), "w", encoding="utf-8").write("\n".join(md) + "\n")
print("\n".join(md))
