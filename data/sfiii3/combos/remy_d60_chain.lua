-- combos verificados por tools/combo_lab.lua: remy a distancia 60, nivel 1. t y pt = frames desde el primer input.
return {
  { starter = "cl_MK", follow = "d_HK", kind = "chain", t = {6,8,10,12,14,16,5,7,9,11,13,15}, dmg = 21, solo = 13, adv = -26, pt = {0} },
  { starter = "cl_MK", follow = "cl_HK", kind = "chain", t = {6,8,10,12,14,16,5,7,9,11,13,15}, dmg = 21, solo = 13, adv = -26, pt = {0} },
  { starter = "LP", follow = "LK", kind = "chain", t = {6,8,10,12,14,16,5,7,9,11,13,15}, dmg = 8, solo = 4, adv = -19, pt = {0} },
  { starter = "LP", follow = "LP", kind = "chain", t = {6,8,10,12,5,7,9,11}, dmg = 7, solo = 4, adv = -19, pt = {0} },
  { starter = "d_LP", follow = "d_LP", kind = "chain", t = {6,8,10,12,14,7,9,11,13,15}, dmg = 4, solo = 2, adv = 1, pt = {0} },
}
