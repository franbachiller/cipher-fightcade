-- combos verificados por tools/combo_lab.lua: gouki a distancia 60, nivel 2. t y pt = frames desde el primer input.
return {
  { starter = "cl_MP>cl_HP", follow = "messatsu_gouhadou", kind = "sa1", t = {12}, dmg = 52, solo = 27, adv = -15, pt = {0,11} },
  { starter = "cl_LP>d_LK", follow = "messatsu_gouhadou", kind = "sa1", t = {18,20,22,26,17,19,21,23,25}, dmg = 44, solo = 4, adv = 0, pt = {0,9} },
  { starter = "d_LP>d_LK", follow = "messatsu_gouhadou", kind = "sa1", t = {18,20,22,24,26,17,19,21,23,25}, dmg = 44, solo = 4, adv = 0, pt = {0,9} },
  { starter = "d_LK>d_LK", follow = "messatsu_gouhadou", kind = "sa1", t = {19,21,23,25,27,18,20,22,24}, dmg = 44, solo = 4, adv = 0, pt = {0,10} },
  { starter = "cl_LP>cl_LP", follow = "messatsu_gouhadou", kind = "sa1", t = {9,17,19,21,23,25,29,16,18,20,22,24,26,30}, dmg = 42, solo = 4, adv = 0, pt = {0,8} },
  { starter = "d_LP>cl_LP", follow = "messatsu_gouhadou", kind = "sa1", t = {11,17,19,21,23,25,29,16,18,20,22,24,26,30}, dmg = 42, solo = 4, adv = 0, pt = {0,10} },
  { starter = "d_LK>cl_LP", follow = "messatsu_gouhadou", kind = "sa1", t = {12,18,20,22,24,26,30,17,19,21,23,25,27}, dmg = 42, solo = 4, adv = 0, pt = {0,11} },
  { starter = "cl_LP>d_LP", follow = "messatsu_gouhadou", kind = "sa1", t = {10,16,18,20,22,30,17,19,21,23}, dmg = 42, solo = 4, adv = 2, pt = {0,9} },
  { starter = "d_LK>d_LP", follow = "messatsu_gouhadou", kind = "sa1", t = {11,17,19,21,23,25,31,18,20,22,24}, dmg = 42, solo = 4, adv = 2, pt = {0,10} },
  { starter = "d_LP>d_LP", follow = "messatsu_gouhadou", kind = "sa1", t = {10,16,18,20,22,24,30,17,19,21,23,25}, dmg = 42, solo = 4, adv = 2, pt = {0,9} },
  { starter = "cl_MP>cl_HP", follow = "goshoryuken_HP", kind = "special", t = {12,13}, dmg = 38, solo = 27, adv = -15, pt = {0,11} },
  { starter = "cl_MP>cl_HP", follow = "goshoryuken_MP", kind = "special", t = {12,13}, dmg = 35, solo = 27, adv = -15, pt = {0,11} },
  { starter = "cl_MP>cl_HP", follow = "tatsumaki_HK", kind = "special", t = {12,13}, dmg = 34, solo = 27, adv = -15, pt = {0,11} },
  { starter = "cl_MP>cl_HP", follow = "tatsumaki_MK", kind = "special", t = {12,13}, dmg = 31, solo = 27, adv = -15, pt = {0,11} },
}
