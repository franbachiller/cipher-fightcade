-- combos verificados por tools/combo_lab.lua: makoto a distancia 60, nivel 1. t y pt = frames desde el primer input.
return {
  { starter = "LK", follow = "MK", kind = "chain", t = {6,8,10,12,5,7,9,11,13}, dmg = 14, solo = 5, adv = -16, pt = {0} },
  { starter = "LP", follow = "LK", kind = "chain", t = {14,15}, dmg = 8, solo = 4, adv = -13, pt = {0} },
  { starter = "f_LP", follow = "LP", kind = "chain", t = {14,15}, dmg = 5, solo = 3, adv = -18, pt = {0} },
  { starter = "f_LP", follow = "f_LP", kind = "chain", t = {14,15}, dmg = 5, solo = 3, adv = -18, pt = {0} },
  { starter = "d_LP", follow = "d_LP", kind = "chain", t = {6,8,10,12,14,16,7,9,11,13,15}, dmg = 4, solo = 2, adv = 2, pt = {0} },
}
