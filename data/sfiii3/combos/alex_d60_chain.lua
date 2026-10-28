-- combos verificados por tools/combo_lab.lua: alex a distancia 60, nivel 1. t y pt = frames desde el primer input.
return {
  { starter = "d_LK", follow = "d_MK", kind = "chain", t = {14,15}, dmg = 13, solo = 4, adv = 1, pt = {0} },
  { starter = "LP", follow = "LP", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13}, dmg = 7, solo = 4, adv = -11, pt = {0} },
  { starter = "LP", follow = "d_LP", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13,15}, dmg = 7, solo = 4, adv = -11, pt = {0} },
  { starter = "d_LP", follow = "LP", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13,15}, dmg = 7, solo = 4, adv = 0, pt = {0} },
  { starter = "d_LP", follow = "d_LP", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13}, dmg = 7, solo = 4, adv = 0, pt = {0} },
}
