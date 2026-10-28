-- Sean (wiki SuperCombo 3S/Sean/Strategy): personaje "chippy": muchos golpes sueltos seguros, combos cortos.
-- Zoning: far HP (herramienta principal; también saca saltos), MP lejanos seguros, st.MK le gana a los bajos, cr.MK.
-- Cerca: cl.HK (5f, seguro, el mejor confirm a super, meaty) y el target combo cl.MP > HK (seguro, anti-air).
-- SU DRAGON SMASH ES EL PEOR DP DEL JUEGO: no se usa como anti-air (la tabla auto lo elegía).
-- Kara throw con f.HP (+14 px); el agarre hacia atrás hace +4 de daño y lo lleva a la esquina.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
local function tc() return { { mp = true, hold = 2 }, { hold = 5 }, { hk = true, hold = 2 } } end   -- cl.MP > HK
return {
	name = "sean",
	ideal_range = 130,
	pokes = {
		{ name = "far HP", anim = "HP", range = { 100, 141 }, startup = 9, seq = function() return M.press("hp", nil, 2) end },
		{ name = "cr.MK", anim = "d_MK", range = { 0, 136 }, startup = 7, seq = function() return M.press("mk", { down = true }, 2) end, cancel = true },
		{ name = "far MP", anim = "MP", range = { 70, 107 }, startup = 5, seq = function() return M.press("mp", nil, 2) end },
		{ name = "st.MK", anim = "MK", range = { 60, 99 }, startup = 6, seq = function() return M.press("mk", nil, 2) end },
	},
	antiair = {
		{ name = "far HP", anim = "HP", startup = 9, seq = function() return M.press("hp", nil, 2) end },
		{ name = "cl.MP>HK (TC)", anim = "cl_MP", startup = 4, seq = tc },
	},
	antiair_special = false,      -- el DP de Sean pierde contra casi todo: anti-air con normales
	punish = {
		{ name = "cl.HK > shoryu_cannon (SA2)", anim = "cl_HK", range = { 0, 95 }, startup = 5, meter = 1,
		  seq = function() local s = M.press("hk", nil, 2) s[#s + 1] = { hold = 2 }
		        for _, f in ipairs(M.qcf2("lp")) do s[#s + 1] = f end return s end },
		{ name = "cl.HK > tornado_HK", anim = "cl_HK", range = { 0, 95 }, startup = 5,
		  seq = function() local s = M.press("hk", nil, 2) s[#s + 1] = { hold = 2 }
		        for _, f in ipairs(M.qcb("hk")) do s[#s + 1] = f end return s end },
		{ name = "cl.MP>HK (TC)", anim = "cl_MP", range = { 0, 75 }, startup = 4, seq = tc },
	},
	confirm = {
		{ meter = 1, seq = function() return M.qcf2("lp") end, name = "> shoryu_cannon" },
		{ seq = function() return M.qcb("lk") end, name = "> tornado_LK" },
	},
	-- kara throw f.HP (+14 px). La mitad de las veces agarre hacia atrás (más daño, lo arrincona)
	throw = function()
		if math.random() < 0.5 then return { { fwd = true, hp = true }, { fwd = true, lp = true, lk = true }, { hold = 2 } } end
		return { { fwd = true, hp = true }, { back = true, lp = true, lk = true }, { hold = 2 } }
	end,
	kara = 12,
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	meaty = { name = "cl.HK", anim = "cl_HK", range = { 0, 95 }, startup = 5, seq = function() return M.press("hk", nil, 2) end },
	pressure = { tick = 3, trap = 3, low = 2, uoh = 2, bait = 2 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("sean", "tornado", "LK", "poke", { range = { 80, 130 }, rate = 0.03, cd = 180 }),
		SP.make("sean", "ryuubikyaku", "LK", "approach", { range = { 120, 180 }, rate = 0.03, cd = 180 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.2, cd = 2400 }
	),
}
