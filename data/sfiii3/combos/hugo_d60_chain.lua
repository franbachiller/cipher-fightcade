-- combos verificados por tools/combo_lab.lua: hugo a distancia 60, nivel 1. t y pt = frames desde el primer input.
return {
  { starter = "LP", follow = "LP", kind = "chain", t = {6,8,10,12,14,16,5,7,9,11,13,15}, dmg = 9, solo = 5, adv = -6, pt = {0} },
  { starter = "d_LP", follow = "LP", kind = "chain", t = {6,8,10,12,14,16,5,7,9,11,13,15}, dmg = 8, solo = 4, adv = -2, pt = {0} },
  { starter = "LP", follow = "d_LP", kind = "chain", t = {6,8,10,12,14,16,5,7,9,11,13,15}, dmg = 8, solo = 5, adv = -6, pt = {0} },
  { starter = "d_LP", follow = "d_LP", kind = "chain", t = {6,8,10,12,14,16,5,7,9,11,13,15}, dmg = 7, solo = 4, adv = -2, pt = {0} },
}
