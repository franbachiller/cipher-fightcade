-- Yun (wiki SuperCombo 3S/Yun): rushdown; SA3 Genei-Jin (install) es su fuerza. Pokes: cr.MK (cancela a especiales),
-- st.MK, st.HP largo, st.LK (3f). Anti-air: Nishoukyaku (DP+K) y st.MK. Zesshou (qcf+P) y Tetsuzan (DP+P) tras confirm.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "yun",
	ideal_range = 120,
	pokes = {
		{ name = "cr.MK", anim = "d_MK", range = { 0, 124 }, startup = 6, seq = function() return M.press("mk", { down = true }, 2) end, cancel = true },
		{ name = "st.MK", anim = "MK", range = { 80, 160 }, startup = 9, seq = function() return M.press("mk", nil, 2) end },
		{ name = "st.LK", anim = "LK", range = { 0, 108 }, startup = 3, seq = function() return M.press("lk", nil, 2) end },
		{ name = "st.HP", anim = "HP", range = { 120, 158 }, startup = 9, seq = function() return M.press("hp", nil, 2) end },
	},
	antiair = {
		{ name = "nishoukyaku_MK", startup = 6, seq = function() return M.dp("mk") end },
		{ name = "st.MK", anim = "MK", startup = 9, seq = function() return M.press("mk", nil, 2) end },
	},
	confirm = {
		{ seq = function() return M.qcf("lp") end, name = "> zesshou" },
	},
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 3, trap = 3, low = 3, uoh = 2, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("yun", "geneijin", "", "install", { meter = 1, sa = 3, rate = 0.6, cd = 600 }),
		{ name = "zesshou_x", role = "poke", range = { 0, 120 }, rate = 0.03, cd = 180, seq = function() return { { down = true }, { down = true, fwd = true }, { fwd = true, lp = true }, { hold = 2 } } end },
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.2, cd = 2400 }
	),
}
