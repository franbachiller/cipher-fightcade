-- combos verificados por tools/combo_lab.lua: hugo a distancia 60, nivel 2. t y pt = frames desde el primer input.
return {
  { starter = "LP>LP", follow = "LP", kind = "chain", t = {20,22,24,26,19,21,23,25}, dmg = 12, solo = 9, adv = -6, pt = {0,10} },
  { starter = "LP>LP", follow = "d_LP", kind = "chain", t = {20,22,24,26,19,21,23,25}, dmg = 11, solo = 9, adv = -6, pt = {0,10} },
  { starter = "d_LP>LP", follow = "LP", kind = "chain", t = {20,22,24,26,19,21,23,25}, dmg = 11, solo = 8, adv = -6, pt = {0,10} },
  { starter = "d_LP>LP", follow = "d_LP", kind = "chain", t = {20,22,24,26,19,21,23,25}, dmg = 10, solo = 8, adv = -6, pt = {0,10} },
}
