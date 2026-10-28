-- combos verificados por tools/combo_lab.lua: yun a distancia 60, nivel 2. t y pt = frames desde el primer input.
return {
  { starter = "d_MP>d_MP", follow = "tetsuzan_EXP", kind = "special", t = {26,28,30,32,34,36,25,27,29,31,33,35}, dmg = 37, solo = 18, adv = 5, pt = {0,21} },
  { starter = "d_MP>d_MP", follow = "zesshou_MP", kind = "special", t = {25,26,27,28,29,30,31,32,34,35,36}, dmg = 32, solo = 18, adv = 5, pt = {0,21} },
  { starter = "d_MP>d_MP", follow = "zesshou_LP", kind = "special", t = {26,28,30,32,34,36,25,27,29,31,35}, dmg = 30, solo = 18, adv = 5, pt = {0,21} },
  { starter = "d_MP>d_LK", follow = "zesshou_LP", kind = "special", t = {26,28,30,32,25,27,29,31}, dmg = 27, solo = 14, adv = 1, pt = {0,21} },
  { starter = "d_MP>LK", follow = "zesshou_LP", kind = "special", t = {24,26,28,30,32,25,27,29,31}, dmg = 27, solo = 14, adv = -5, pt = {0,21} },
  { starter = "cl_LP>LK", follow = "tetsuzan_EXP", kind = "special", t = {14,16,18,20,15,17,19,21}, dmg = 25, solo = 4, adv = -4, pt = {0,9} },
  { starter = "d_MP>d_LP", follow = "zesshou_LP", kind = "special", t = {26,28,30,32,25,27,29,31}, dmg = 25, solo = 12, adv = 3, pt = {0,21} },
  { starter = "cl_LP>LK", follow = "nishoukyaku_HK", kind = "special", t = {14,15,16,17,18,19,20,21,22,23}, dmg = 24, solo = 4, adv = -4, pt = {0,9} },
  { starter = "cl_LP>LK", follow = "nishoukyaku_EXK", kind = "special", t = {10,14,16,18,20,22,15,17,19,21,23}, dmg = 21, solo = 4, adv = -4, pt = {0,9} },
  { starter = "cl_LP>LK", follow = "nishoukyaku_LK", kind = "special", t = {14,16,18,20,22,15,17,19,21,23}, dmg = 21, solo = 4, adv = -4, pt = {0,9} },
  { starter = "cl_LP>LK", follow = "nishoukyaku_MK", kind = "special", t = {10,14,15,16,17,18,19,20,21,22,23}, dmg = 21, solo = 4, adv = -4, pt = {0,9} },
  { starter = "d_LK>d_LK", follow = "zesshou_LP", kind = "special", t = {19,21,23,25,18,20,22,24}, dmg = 20, solo = 7, adv = 1, pt = {0,14} },
  { starter = "cl_LP>LK", follow = "zesshou_MP", kind = "special", t = {14,15,16,17,18,19,20,21,24,25,26}, dmg = 19, solo = 4, adv = -4, pt = {0,9} },
  { starter = "d_LP>d_LP", follow = "zesshou_LP", kind = "special", t = {20,22,24,26,19,21,23,25}, dmg = 17, solo = 4, adv = 3, pt = {0,15} },
  { starter = "cl_LP>LK", follow = "zesshou_LP", kind = "special", t = {14,16,18,20,22,15,17,19,21,23}, dmg = 17, solo = 4, adv = -4, pt = {0,9} },
}
