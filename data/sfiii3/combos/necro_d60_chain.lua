-- combos verificados por tools/combo_lab.lua: necro a distancia 60, nivel 1. t y pt = frames desde el primer input.
return {
  { starter = "b_LK", follow = "MP", kind = "chain", t = {4,6,8,10,12,5,7,9,11,13}, dmg = 13, solo = 6, adv = -6, pt = {0} },
  { starter = "b_LK", follow = "LK", kind = "chain", t = {14,13,15}, dmg = 11, solo = 6, adv = -6, pt = {0} },
  { starter = "b_LK", follow = "b_LK", kind = "chain", t = {14,13,15}, dmg = 11, solo = 6, adv = -6, pt = {0} },
}
