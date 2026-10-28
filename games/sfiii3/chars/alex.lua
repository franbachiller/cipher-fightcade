-- Alex (wiki SuperCombo 3S/Alex/Strategy): brawler de media distancia / grappler, mucho stun. SA2 Boomerang Raid.
-- Pokes: cr.MP (rápido, seguro, cubre mucho; débil al parry), f.MP (pide parry alto y saca saltos), cr.MK (bajo que
-- frena a los que caminan), st.MK y cr.HK de lejos. Anti-air: cl.MP (rapidísimo) y cr.HP (varios golpes).
-- Agarres: el agarre NORMAL (kara f.HP, +16 px) es más seguro que el Power Bomb ("alto riesgo, recompensa media"):
-- en neutral agarra normal; el Power Bomb queda para castigos / post-parry. Tick throw desde st.LP / st.MK.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
local function power_bomb(btn)
	return { { fwd = true }, { down = true, fwd = true }, { down = true }, { down = true, back = true }, { back = true, [btn] = true }, { hold = 2 } }
end
return {
	name = "alex",
	ideal_range = 130,
	pokes = {
		-- starters de sus combos con super verificados (cl.MK xx Boomerang Raid 60, 5MP xx Boomerang Raid 59): con los
		-- pokes de antes (cr.MP, f.MP, cr.MK, st.MK) el confirm no encontraba ningún combo y la barra no se usaba
		{ name = "cl.MK", anim = "cl_MK", range = { 0, 58 }, startup = 5, seq = function() return M.press("mk", nil, 2) end },
		{ name = "st.MP", anim = "MP", range = { 55, 112 }, startup = 6, seq = function() return M.press("mp", nil, 2) end },
		{ name = "cr.MP", anim = "d_MP", range = { 0, 145 }, startup = 7, seq = function() return M.press("mp", { down = true }, 2) end },
		{ name = "f.MP", anim = "f_MP", range = { 60, 142 }, startup = 7, seq = function() return M.press("mp", { fwd = true }, 2) end },
		{ name = "cr.MK", anim = "d_MK", range = { 0, 132 }, startup = 8, seq = function() return M.press("mk", { down = true }, 2) end },
		{ name = "st.MK", anim = "MK", range = { 110, 150 }, startup = 11, seq = function() return M.press("mk", nil, 2) end },
	},
	antiair = {
		{ name = "cl.MP", anim = "MP", startup = 4, seq = function() return M.press("mp", nil, 2) end },
		{ name = "cr.HP", anim = "d_HP", startup = 13, seq = function() return M.press("hp", { down = true }, 2) end },
	},
	-- agarre de comando: castigo y post-parry (grappler = false: en neutral usa el agarre normal)
	-- Power Bomb medido: agarra hasta ~94 px vs Ryu (la tabla dice ~104)
	command_grab = { name = "power_bomb", seq = function() return power_bomb("lp") end, range = 90, fix = 10 },
	-- lab de castigos (2026-10-22): f.HP como castigo/post-parry salió sin daño 37-58% (lento, se lo bloquean)
	punish_exclude = { f_HP = true },
	confirm = {
		{ meter = 1, seq = function() return M.qcf2("lp") end, name = "> boomerang_raid" },
	},
	-- kara throw f.HP (+16 px)
	throw = function() return { { fwd = true, hp = true }, { fwd = true, lp = true, lk = true }, { hold = 2 } } end,
	kara = 12,         -- medido 2026-10-22 (tools/test_range.lua vs Ryu): agarre normal ~82 px, kara f.HP ~96 px
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 4, trap = 2, low = 2, uoh = 2, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("alex", "slash_elbow", "LK", "approach", { range = { 120, 190 }, rate = 0.06, cd = 150 }),
		SP.make("alex", "flash_chop", "LP", "poke", { range = { 60, 120 }, rate = 0.03, cd = 180 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.3, cd = 2400 }
	),
}
