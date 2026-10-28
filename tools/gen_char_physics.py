r"""Genera data/sfiii3/char_physics.lua: física por personaje (velocidad de caminata, ancho de empuje, offset contra la
pared, alturas) y límites de cada escenario, desde third_party/donsinp-design__SF/fbneo-training-mode (framedata.lua +
stage_data.lua, medidos del juego).  python -I tools\gen_char_physics.py"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "third_party", "donsinp-design__SF", "fbneo-training-mode", "src", "data")
fd = open(os.path.join(SRC, "framedata.lua"), encoding="utf-8").read()
st = open(os.path.join(SRC, "stage_data.lua"), encoding="utf-8").read()
F = {"forward_walk_speed": "fwd", "backward_walk_speed": "back", "corner_offset_left": "off_l",
     "corner_offset_right": "off_r", "pushbox_width": "push_w", "half_width": "half_w", "push_value": "push"}
chars = {}
for m in re.finditer(r"^character_specific\.(\w+)\.(\w+) = ([-\d.]+)\s*$", fd, re.M):
    c, k, v = m.groups()
    if k in F:
        chars.setdefault(c, {})[F[k]] = float(v) if "." in v else int(v)
for m in re.finditer(r"^character_specific\.(\w+)\.height = \{ crouching = \{ min = (\d+), max = (\d+) \}, standing = \{ min = (\d+), max = (\d+) \} \}", fd, re.M):
    c = m.group(1)
    chars.setdefault(c, {}).update(h_crouch=int(m.group(3)), h_stand=int(m.group(5)))
stages = re.findall(r"\[(\d+)\] = \{name = \"(\w+)\", left = (\d+), right = (\d+), screen_left = (\d+), screen_right = (\d+)\}", st)
out = ["-- generado por tools/gen_char_physics.py (fbneo-training-mode: framedata.lua / stage_data.lua)",
       "-- fwd/back = px por frame caminando; off_l/off_r = distancia del centro a la pared (x mínima = stage.left + off_l);",
       "-- push_w = ancho de la caja de empuje; stages[id] = límites del escenario y de la cámara (screen_x)",
       "return {", "  chars = {"]
for c in sorted(chars):
    out.append("    %s = { %s }," % (c, ", ".join("%s = %s" % (k, v) for k, v in sorted(chars[c].items()))))
out.append("  },")
out.append("  stages = {")
for i, n, l, r, sl, sr in stages:
    out.append("    [%s] = { name = \"%s\", left = %s, right = %s, screen_left = %s, screen_right = %s }," % (i, n, l, r, sl, sr))
out += ["  },", "}"]
open(os.path.join(ROOT, "data", "sfiii3", "char_physics.lua"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print(len(chars), "personajes", len(stages), "escenarios")
