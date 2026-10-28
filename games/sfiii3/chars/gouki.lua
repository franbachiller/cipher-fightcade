-- Gouki/Akuma (wiki SuperCombo 3S/Akuma/Strategy): shoto de mucho daño y poca vida (950, stun corto 52).
-- Pokes shoto: cr.MK (confirma a super), st.MP, cr.MP, st.MK. Anti-air: Goshoryuken. Castigo post-parry: s.HP xx
-- tatsu, SRK / s.HK xx super / c.MK xx super. Mejor opción en el wakeup del propio Gouki: bloquear.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "gouki",
	ideal_range = 135,
	pokes = {
		{ name = "cr.MK", anim = "d_MK", range = { 0, 142 }, startup = 6, seq = function() return M.press("mk", { down = true }, 2) end, cancel = true },
		{ name = "st.MP", anim = "MP", range = { 60, 107 }, startup = 5, seq = function() return M.press("mp", nil, 2) end, cancel = true },
		{ name = "cr.MP", anim = "d_MP", range = { 0, 103 }, startup = 5, seq = function() return M.press("mp", { down = true }, 2) end, cancel = true },
		{ name = "st.MK", anim = "MK", range = { 70, 111 }, startup = 5, seq = function() return M.press("mk", nil, 2) end },
	},
	antiair = {
		{ name = "goshoryuken_LP", startup = 3, dx = { 0, 70 }, seq = function() return M.dp("lp") end },
		{ name = "goshoryuken_HP", startup = 1, dx = { 0, 70 }, seq = function() return M.dp("hp") end },
	},
	confirm = {
		{ meter = 1, seq = function() return M.qcf2("lp") end, name = "> messatsu_gouhadou" },
		{ seq = function() return M.qcf("hp") end, name = "> gohadouken" },
	},
	fireball = { name = "gohadouken", seq = function() return M.qcf("lp") end, min_dist = 190, cooldown = 70 },
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 3, trap = 3, low = 3, uoh = 2, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("gouki", "hyakki", "LK", "approach", { range = { 100, 180 }, rate = 0.04, cd = 180 }),
		{ name = "zanku_hadou", role = "zoning", range = { 150, 260 }, rate = 0.03, cd = 150, seq = function() return { { up = true, fwd = true, hold = 3 }, { hold = 7 }, { down = true }, { down = true, fwd = true }, { fwd = true, lp = true }, { hold = 20 } } end },
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.25, cd = 2400 }
	),
}
