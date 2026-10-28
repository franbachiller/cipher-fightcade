-- combos verificados por tools/combo_lab.lua: ibuki a distancia 60, nivel 2. t y pt = frames desde el primer input.
return {
  { starter = "LK>MK", follow = "f_HK", kind = "chain", t = {16,18,22,24,26,17,19,21,23,25}, dmg = 20, solo = 9, adv = -12, pt = {0,10} },
  { starter = "LP>MP", follow = "f_LK", kind = "chain", t = {17,19,21,23,18,20,22}, dmg = 17, solo = 12, adv = -4, pt = {0,7} },
  { starter = "f_LK>LK", follow = "LK", kind = "chain", t = {19,21,23,25,27,20,22,24,26}, dmg = 5, solo = 4, adv = -10, pt = {0,11} },
  { starter = "f_LK>LK", follow = "f_LK", kind = "chain", t = {19,21,23,25,27,20,22,24,26}, dmg = 5, solo = 4, adv = -10, pt = {0,11} },
}
