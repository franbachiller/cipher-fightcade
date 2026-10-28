-- combos verificados por tools/combo_lab.lua: yang a distancia 60, nivel 1. t y pt = frames desde el primer input.
return {
  { starter = "LK", follow = "f_MK", kind = "chain", t = {4,6,8,10,12,5,7,9,11}, dmg = 11, solo = 4, adv = -5, pt = {0} },
  { starter = "LK", follow = "cl_MK", kind = "chain", t = {4,6,8,10,12,5,7,9,11}, dmg = 11, solo = 4, adv = -5, pt = {0} },
  { starter = "d_LK", follow = "d_LK", kind = "chain", t = {14,15}, dmg = 7, solo = 4, adv = 1, pt = {0} },
  { starter = "d_LP", follow = "d_LP", kind = "chain", t = {4,6,8,10,12,14,5,7,9,11,13,15}, dmg = 4, solo = 2, adv = 3, pt = {0} },
  { starter = "LP", follow = "LP", kind = "chain", t = {4,6,8,10,12,14,5,7,9,11,13,15}, dmg = 4, solo = 2, adv = -8, pt = {0} },
}
