-- combos verificados por tools/combo_lab.lua: necro a distancia 60, nivel 2. t y pt = frames desde el primer input.
return {
  { starter = "b_HK>MK", follow = "electric_snake", kind = "sa3", t = {30}, dmg = 53, solo = 29, adv = -3, pt = {0,29} },
  { starter = "b_HK>MP", follow = "electric_snake", kind = "sa3", t = {31,39,41,43,45,47,49,38,40,42,44,46,48,50}, dmg = 53, solo = 27, adv = -10, pt = {0,30} },
  { starter = "b_HK>LP", follow = "electric_snake", kind = "sa3", t = {32,38,40,42,44,46,48,37,39,41,43,45,47}, dmg = 53, solo = 24, adv = -11, pt = {0,31} },
  { starter = "b_HK>d_LK", follow = "electric_snake", kind = "sa3", t = {32,38,40,42,44,48,50,37,39,41,43,45,47,49}, dmg = 53, solo = 24, adv = 1, pt = {0,31} },
  { starter = "b_HK>d_LP", follow = "electric_snake", kind = "sa3", t = {32,38,40,42,44,48,50,37,39,41,43,45,47,49}, dmg = 53, solo = 24, adv = 4, pt = {0,31} },
  { starter = "b_LK>LK", follow = "electric_snake", kind = "sa3", t = {17,21,23,25,27,20,22,24,26}, dmg = 50, solo = 11, adv = -6, pt = {0,14} },
  { starter = "d_LP>b_LK", follow = "electric_snake", kind = "sa3", t = {25,27,29,31,26,28,30}, dmg = 48, solo = 9, adv = -6, pt = {0,18} },
  { starter = "b_HK>MK", follow = "tornado_hook_EXP", kind = "special", t = {30}, dmg = 48, solo = 29, adv = -3, pt = {0,29} },
  { starter = "d_LP>b_LP", follow = "electric_snake", kind = "sa3", t = {25,27,29,31,33,26,28,30,32}, dmg = 48, solo = 9, adv = -10, pt = {0,18} },
  { starter = "b_LK>MP", follow = "electric_snake", kind = "sa3", t = {9,11,13,17,19,21,23,25,27,10,12,16,18,20,22,24,26,28}, dmg = 45, solo = 13, adv = -13, pt = {0,8} },
  { starter = "b_LK>MP", follow = "tornado_hook_LP", kind = "special", t = {9,11,12}, dmg = 22, solo = 13, adv = -13, pt = {0,8} },
  { starter = "b_LK>MP", follow = "tornado_hook_EXP", kind = "special", t = {9,11,10}, dmg = 22, solo = 13, adv = -13, pt = {0,8} },
}
