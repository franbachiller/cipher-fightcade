-- combos verificados por tools/combo_lab.lua: ibuki a distancia 60, nivel 1. t y pt = frames desde el primer input.
return {
  { starter = "d_HK", follow = "cl_HK", kind = "chain", t = {12,14,16,11,13,15}, dmg = 27, solo = 14, adv = -11, pt = {0} },
  { starter = "MK", follow = "f_HK", kind = "chain", t = {6,8,10,12,14,16,7,9,11,13,15}, dmg = 25, solo = 14, adv = -8, pt = {0} },
  { starter = "MP", follow = "f_LK", kind = "chain", t = {8,10,12,14,16,7,9,11,13,15}, dmg = 17, solo = 10, adv = -4, pt = {0} },
  { starter = "b_MP", follow = "d_HK", kind = "chain", t = {16,15}, dmg = 16, solo = 11, adv = -21, pt = {0} },
  { starter = "LP", follow = "MP", kind = "chain", t = {4,6,8,10,3,5,7,9,11}, dmg = 12, solo = 3, adv = -7, pt = {0} },
  { starter = "LP", follow = "d_MP", kind = "chain", t = {4,6,8,10,3,5,7,9,11}, dmg = 12, solo = 3, adv = -7, pt = {0} },
  { starter = "LK", follow = "MK", kind = "chain", t = {6,8,10,12,14,16,5,7,9,11,13,15}, dmg = 9, solo = 2, adv = -10, pt = {0} },
  { starter = "LK", follow = "f_MK", kind = "chain", t = {6,8,10,12,14,16,5,7,9,11,13,15}, dmg = 9, solo = 2, adv = -10, pt = {0} },
  { starter = "LK", follow = "b_MK", kind = "chain", t = {6,8,10,12,14,16,5,7,9,11,13,15}, dmg = 9, solo = 2, adv = -10, pt = {0} },
  { starter = "LP", follow = "LP", kind = "chain", t = {14,13,15}, dmg = 5, solo = 3, adv = -7, pt = {0} },
  { starter = "LP", follow = "d_LP", kind = "chain", t = {14,13}, dmg = 5, solo = 3, adv = -7, pt = {0} },
  { starter = "f_LK", follow = "LK", kind = "chain", t = {6,8,10,12,14,16,7,9,11,13,15}, dmg = 4, solo = 2, adv = -10, pt = {0} },
  { starter = "f_LK", follow = "f_LK", kind = "chain", t = {6,8,10,12,14,16,7,9,11,13,15}, dmg = 4, solo = 2, adv = -10, pt = {0} },
  { starter = "d_LP", follow = "LP", kind = "chain", t = {16,15}, dmg = 4, solo = 2, adv = 4, pt = {0} },
}
