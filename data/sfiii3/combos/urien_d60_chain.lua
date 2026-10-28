-- combos verificados por tools/combo_lab.lua: urien a distancia 60, nivel 1. t y pt = frames desde el primer input.
return {
  { starter = "f_MP", follow = "f_HP", kind = "chain", t = {10,12,14,16,11,13,15}, dmg = 19, solo = 11, adv = -12, pt = {0} },
  { starter = "f_MP", follow = "HP", kind = "chain", t = {10,12,14,16,11,13,15}, dmg = 19, solo = 11, adv = -12, pt = {0} },
  { starter = "LP", follow = "MP", kind = "chain", t = {6,8,10,12,5,7,9,11}, dmg = 7, solo = 2, adv = -7, pt = {0} },
  { starter = "LP", follow = "f_MP", kind = "chain", t = {6,8,10,12,5,7,9,11}, dmg = 7, solo = 2, adv = -7, pt = {0} },
  { starter = "LP", follow = "d_MP", kind = "chain", t = {6,8,10,12,5,7,9,11}, dmg = 7, solo = 2, adv = -7, pt = {0} },
  { starter = "LP", follow = "LP", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13,15}, dmg = 4, solo = 2, adv = -7, pt = {0} },
  { starter = "d_LP", follow = "d_LP", kind = "chain", t = {6,8,10,12,14,5,7,9,11,13}, dmg = 4, solo = 2, adv = 0, pt = {0} },
}
