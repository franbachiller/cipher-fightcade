"""Candidatos de combos CON SUPER para los 3 SA de cada personaje (data/sfiii3/super_combos.lua). Se verifican en el
emulador igual que los de la wiki (tools/wiki_combo_lab.lua): solo entra al bot lo que conecta entero.
Fuentes: los combos sin barra de la wiki que terminan en especial (+ " xx SA") y los starters clásicos de super.
Se saltean los SA que no se combean (agarres de comando o activables).
  python -I tools\\gen_super_candidates.py"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIKI = os.path.join(ROOT, "data", "sfiii3", "wiki_combos.lua")
OUT = os.path.join(ROOT, "data", "sfiii3", "super_combos.lua")

# SA que no van en combo: agarres de comando (Gigas, Hyper Bomb, Yoroi Dooshi, Slam Dance, Total Destruction,
# Megaton de agarre no) y activables (Genei-Jin, Tanden Renki, Healing, X.C.O.P.Y.)
SKIP = {("hugo", 1), ("alex", 1), ("ibuki", 2), ("necro", 2), ("q", 3), ("yun", 3), ("makoto", 3), ("elena", 3),
        ("twelve", 3), ("oro", 1)}
GENERIC = [("2MK xx SA", 55), ("cl.HP xx SA", 42), ("cl.MP xx SA", 42), ("cl.MK xx SA", 42), ("2MP xx SA", 45),
           ("2LK > 2LK xx SA", 45), ("2LK > 2LP > 2LK xx SA", 42), ("2LP > 2LP xx SA", 42), ("UOH, SA", 45),
           ("2HP xx SA", 45), ("5MP xx SA", 60)]

txt = open(WIKI, encoding="utf-8").read()
blocks = dict(re.findall(r"(?ms)^\t(\w+) = \{(.*?)^\t\},", txt))
out = ["-- generado por tools/gen_super_candidates.py: combos con super para los 3 SA (CANDIDATOS: se verifican en emulador)",
       "return {"]
total = 0
for char, body in sorted(blocks.items()):
    have = set(re.findall(r'\{ "([^"]+)"(?:, sa = (\d))?', body))
    have_txt = {(t, s) for t, s in have}
    meterless = [(t, d) for t, d in re.findall(r'\{ "([^"]+)"(?:, d = (\d+))? \}', body) if " SA" not in t and "SA" not in t]
    lines = []
    for sa in (1, 2, 3):
        if (char, sa) in SKIP:
            continue
        cands = []
        for t, d in meterless:
            last = re.split(r" > | xx |, ", t)[-1]
            if ":" in last and "EX" not in last:          # termina en especial (no EX): cancelar al super
                cands.append((t + " xx SA", int(d) if d else (42 if t.startswith(("cl.", "UOH")) else 60)))
        cands += GENERIC
        seen = set()
        for t, d in cands:
            if (t, str(sa)) in have_txt or t in seen:
                continue
            seen.add(t)
            lines.append('\t\t{ "%s", sa = %d, d = %d, gen = true },' % (t, sa, d))
    out.append("\t%s = {" % char)
    out += lines
    out.append("\t},")
    total += len(lines)
    print("%-7s %3d candidatos" % (char, len(lines)))
out.append("}")
open(OUT, "w", encoding="utf-8").write("\n".join(out) + "\n")
print("total", total, "->", OUT)
