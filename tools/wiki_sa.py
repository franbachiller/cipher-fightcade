"""SA recomendado por la wiki: de la sección "Super Arts" de cada página principal (data/sfiii3/wiki/<Char>.md) saca
cada SA con su etiqueta (Recommended / Not recommended / Sometimes...). Si la página no tiene etiquetas, muestra las
frases que hablan de la elección.  python -I tools\\wiki_sa.py   (también exporta data/sfiii3/wiki_sa.lua)"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W = os.path.join(ROOT, "data", "sfiii3", "wiki")
OUT = os.path.join(ROOT, "data", "sfiii3", "wiki_sa.lua")
NAMES = {"Akuma": "gouki", "Alex": "alex", "Chun-Li": "chunli", "Dudley": "dudley", "Elena": "elena", "Hugo": "hugo",
         "Ibuki": "ibuki", "Ken": "ken", "Makoto": "makoto", "Necro": "necro", "Oro": "oro", "Q": "q", "Remy": "remy",
         "Ryu": "ryu", "Sean": "sean", "Twelve": "twelve", "Urien": "urien", "Yang": "yang", "Yun": "yun"}
TAG = re.compile(r"(Very,? very recommended|Highly recommended|Sometimes recommended|Situationally recommended|"
                 r"Not recommended|Recomm?ended)", re.I)
sys.stdout.reconfigure(encoding="utf-8")
out = ["-- generado por tools/wiki_sa.py: etiqueta de la wiki por SA (2 = muy recomendado, 1 = recomendado,",
       "-- 0.5 = a veces, 0 = sin etiqueta, -1 = no recomendado) y la frase de origen", "return {"]
for wname, char in NAMES.items():
    p = os.path.join(W, wname + ".md")
    txt = re.sub(r"[ \t]+", " ", open(p, encoding="utf-8").read()) if os.path.exists(p) else ""
    i = txt.find("Super Arts")
    sec = txt[i:i + 6000] if i >= 0 else ""
    rows = {}
    for m in re.finditer(r"SA ?(I{1,3}|[123])\s*[:\-]\s*([^\n]{0,80})\n+\s*([^\n]{0,260})", sec):
        n = {"I": 1, "II": 2, "III": 3}.get(m.group(1), None) or int(m.group(1))
        if n in rows:
            continue
        line = m.group(2).strip() + " | " + m.group(3).strip()
        t = TAG.search(line)
        tag = t.group(1).lower() if t else ""
        score = 2 if ("very" in tag or "highly" in tag) else -1 if "not" in tag else 0.5 if ("sometimes" in tag or "situation" in tag) else 1 if tag else 0
        rows[n] = (score, line[:150])
    print("=====", wname)
    for n in sorted(rows):
        print("   SA%d  %+.1f  %s" % (n, rows[n][0], rows[n][1]))
    if not rows:
        print("   (sin sección Super Arts con etiquetas)")
    out.append('  ["%s"] = { %s },' % (char, ", ".join("[%d] = { score = %s, text = %s }" % (n, rows[n][0], repr(rows[n][1]).replace("\\'", "'").replace('"', "'").join('""') if False else '"' + rows[n][1].replace('"', "'").replace("\\", "") + '"') for n in sorted(rows))))
out.append("}")
open(OUT, "w", encoding="utf-8").write("\n".join(out) + "\n")
