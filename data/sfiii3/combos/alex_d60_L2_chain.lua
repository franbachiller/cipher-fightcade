-- combos verificados por tools/combo_lab.lua: alex a distancia 60, nivel 2. t y pt = frames desde el primer input.
return {
  { starter = "LP>LP", follow = "d_LP", kind = "chain", t = {19,21,23,25,18,20,22,24}, dmg = 9, solo = 7, adv = -11, pt = {0,9} },
  { starter = "LP>d_LP", follow = "LP", kind = "chain", t = {18,20,22,24,17,19,21,23}, dmg = 9, solo = 7, adv = 0, pt = {0,10} },
  { starter = "d_LP>LP", follow = "d_LP", kind = "chain", t = {18,20,22,24,26,17,19,21,23,25}, dmg = 9, solo = 7, adv = -11, pt = {0,10} },
}
