-- combos verificados por tools/combo_lab.lua: sean a distancia 60, nivel 2. t y pt = frames desde el primer input.
return {
  { starter = "cl_MP>cl_HK", follow = "tornado_EXK", kind = "special", t = {11,12}, dmg = 35, solo = 20, adv = -11, pt = {0,10} },
  { starter = "d_LP>d_LP", follow = "shoryu_cannon", kind = "sa2", t = {11,17,19,21,23,16,18,20,22,24}, dmg = 32, solo = 4, adv = 2, pt = {0,10} },
  { starter = "d_LK>LP", follow = "shoryu_cannon", kind = "sa2", t = {12,18,20,22,24,17,19,21,23,25}, dmg = 32, solo = 4, adv = 1, pt = {0,11} },
  { starter = "LP>LP", follow = "shoryu_cannon", kind = "sa2", t = {9,15,17,19,21,23,14,16,18,20,22}, dmg = 32, solo = 4, adv = 1, pt = {0,8} },
  { starter = "LP>d_LP", follow = "shoryu_cannon", kind = "sa2", t = {10,16,18,20,22,15,17,19,21,23}, dmg = 32, solo = 4, adv = 2, pt = {0,9} },
  { starter = "cl_MP>cl_HK", follow = "tornado_LK", kind = "special", t = {11}, dmg = 25, solo = 20, adv = -11, pt = {0,10} },
}
