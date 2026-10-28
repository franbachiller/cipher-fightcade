"""Une las partes de combo_lab en una sola tabla Lua ordenada por daño.
  python -I merge_combos.py <parts_dir> <char> <dist> <out.lua> [level]
"""
import os
import re
import sys

parts, char, dist, out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
level = int(sys.argv[5]) if len(sys.argv) > 5 else 1
suffix = sys.argv[6] if len(sys.argv) > 6 else ""
lv = (f"_L{level}" if level > 1 else "") + suffix
rx = re.compile(r'\{ starter = "([^"]+)", follow = "([^"]+)", kind = "([^"]+)", t = \{([^}]*)\}, dmg = (\d+), solo = (\d+), adv = (-?\d+)(?:, pt = \{([^}]*)\})? \}')
rows = []
for fn in sorted(os.listdir(parts)):
    if re.fullmatch(rf"{re.escape(char)}_d{dist}{lv}_s\d+\.lua", fn):
        for line in open(os.path.join(parts, fn), encoding="utf-8"):
            m = rx.search(line)
            if m:
                rows.append((m.group(1), m.group(2), m.group(3), m.group(4), int(m.group(5)), int(m.group(6)), int(m.group(7)), m.group(8) or "0"))
rows.sort(key=lambda r: -r[4])
with open(out, "w", encoding="ascii", newline="\n") as f:
    f.write(f"-- combos verificados por tools/combo_lab.lua: {char} a distancia {dist}, nivel {level}. t y pt = frames desde el primer input.\n")
    f.write("return {\n")
    for r in rows:
        f.write(f'  {{ starter = "{r[0]}", follow = "{r[1]}", kind = "{r[2]}", t = {{{r[3]}}}, dmg = {r[4]}, solo = {r[5]}, adv = {r[6]}, pt = {{{r[7]}}} }},\n')
    f.write("}\n")
print(f"{len(rows)} combos -> {out}")
for r in rows[:15]:
    t = [int(x) for x in r[3].split(",") if x]
    print(f"  {r[0]:22s} > {r[1]:22s} {r[2]:7s} dmg={r[4]:3d}  t={min(t)}..{max(t)} ({len(t)} frames)")
