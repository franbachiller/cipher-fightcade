-- combos verificados por tools/combo_lab.lua: yun a distancia 60, nivel 1. t y pt = frames desde el primer input.
return {
  { starter = "d_HK", follow = "HK", kind = "chain", t = {14,16,15}, dmg = 20, solo = 13, adv = -8, pt = {0} },
  { starter = "d_LK", follow = "d_LK", kind = "chain", t = {14,15}, dmg = 7, solo = 4, adv = 1, pt = {0} },
  { starter = "d_LP", follow = "d_LP", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13,15}, dmg = 4, solo = 2, adv = 3, pt = {0} },
  { starter = "cl_LP", follow = "LK", kind = "chain", t = {4,6,8,10,12,14,5,7,9,11,13,15}, dmg = 4, solo = 2, adv = 0, pt = {0} },
}
