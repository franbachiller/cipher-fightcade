-- combos verificados por tools/combo_lab.lua: gouki a distancia 60, nivel 1. t y pt = frames desde el primer input.
return {
  { starter = "cl_MP", follow = "cl_HP", kind = "chain", t = {6,8,10,12,14,16,7,9,11,13,15}, dmg = 27, solo = 16, adv = -2, pt = {0} },
  { starter = "d_LK", follow = "LK", kind = "chain", t = {6,8,10,12,14,16,7,9,11,13,15}, dmg = 6, solo = 2, adv = 0, pt = {0} },
  { starter = "cl_LP", follow = "LK", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13,15}, dmg = 6, solo = 2, adv = 0, pt = {0} },
  { starter = "d_LP", follow = "LK", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13,15}, dmg = 6, solo = 2, adv = 2, pt = {0} },
  { starter = "d_LK", follow = "d_LP", kind = "chain", t = {6,8,10,12,14,7,9,11,13}, dmg = 4, solo = 2, adv = 0, pt = {0} },
  { starter = "d_LK", follow = "d_LK", kind = "chain", t = {6,8,10,12,14,7,9,11,13,15}, dmg = 4, solo = 2, adv = 0, pt = {0} },
  { starter = "d_LK", follow = "cl_LP", kind = "chain", t = {6,8,10,12,14,16,7,9,11,13,15}, dmg = 4, solo = 2, adv = 0, pt = {0} },
  { starter = "cl_LP", follow = "d_LP", kind = "chain", t = {6,8,10,12,5,7,9,11,13}, dmg = 4, solo = 2, adv = 0, pt = {0} },
  { starter = "cl_LP", follow = "d_LK", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13}, dmg = 4, solo = 2, adv = 0, pt = {0} },
  { starter = "cl_LP", follow = "cl_LP", kind = "chain", t = {6,8,10,12,5,7,9,11}, dmg = 4, solo = 2, adv = 0, pt = {0} },
  { starter = "d_LP", follow = "d_LP", kind = "chain", t = {6,8,10,12,5,7,9,11,13}, dmg = 4, solo = 2, adv = 2, pt = {0} },
  { starter = "d_LP", follow = "d_LK", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13}, dmg = 4, solo = 2, adv = 2, pt = {0} },
  { starter = "d_LP", follow = "cl_LP", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13,15}, dmg = 4, solo = 2, adv = 2, pt = {0} },
}
