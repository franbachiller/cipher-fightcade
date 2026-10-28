-- Ken (wiki SuperCombo 3S/Ken/Strategy): fuerte en neutral. SA3 Shippu siempre (confirma de lejos: far MP / cr.MK).
-- Neutral: far MP castiga todo lo que erran y confirma super; cr.MP parecido con mejor ventaja; cr.MK es su bajo clave
-- (difícil de confirmar -> se confirma por RAM); st.HK poke medio largo contra quien busca parry bajo.
-- Anti-air: Shoryuken (invulnerable a casi todos los saltos). Ofensiva: cadenas bajas débiles (plus, confirman super),
-- cr.LK / cl.MP meaty, tick throw y frame traps. Dash de 11-12 frames.
-- Rangos: el bot usa el alcance exacto por "anim" (games/sfiii3/ranges.lua); "range" = mínimo y respaldo.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "ken",
	ideal_range = 135,
	pokes = {
		{ name = "cr.MK", anim = "d_MK", range = { 0, 140 }, startup = 6, seq = function() return M.press("mk", { down = true }, 2) end, cancel = true },
		{ name = "far MP", anim = "MP", range = { 70, 107 }, startup = 6, seq = function() return M.press("mp", nil, 2) end, cancel = true },
		{ name = "cr.MP", anim = "d_MP", range = { 60, 103 }, startup = 5, seq = function() return M.press("mp", { down = true }, 2) end, cancel = true },
		{ name = "st.HK", anim = "HK", range = { 120, 159 }, startup = 11, seq = function() return M.press("hk", nil, 2) end },
	},
	antiair = {
		{ name = "shoryuken_LP", seq = function() return M.dp("lp") end, startup = 3 },
		{ name = "shoryuken_HP", seq = function() return M.dp("hp") end, startup = 3 },
	},
	-- castigos: rango máximo y startup; el brain elige el de más daño que llegue a tiempo (después de los combos del lab)
	punish = {
		{ name = "shippu (SA3)", range = { 0, 105 }, startup = 4, meter = 1,
		  seq = function() return M.qcf2("lk") end },
		{ name = "cl.HP > shoryu", anim = "cl_HP", range = { 0, 58 }, startup = 3,
		  seq = function() local s = M.press("hp", nil, 2) s[#s + 1] = { hold = 3 }
		        for _, f in ipairs(M.dp("hp")) do s[#s + 1] = f end return s end },
		{ name = "cr.MK > hadou", anim = "d_MK", range = { 0, 140 }, startup = 6,
		  seq = function() local s = M.press("mk", { down = true }, 2) s[#s + 1] = { down = true, hold = 2 }
		        for _, f in ipairs(M.qcf("hp")) do s[#s + 1] = f end return s end },
		{ name = "shoryuken_HP", range = { 0, 70 }, startup = 3, seq = function() return M.dp("hp") end },
	},
	-- cancel tras confirmar hit con un normal cancelable (wiki: cr.MK -> EX hadouken es más seguro; con barra, Shippu)
	confirm = {
		{ meter = 1, seq = function() return M.qcf2("lk") end, name = "> shippu" },
		{ seq = function() return M.qcf("hp") end, name = "> hadouken" },
	},
	fireball = { name = "hadouken", seq = function() return M.qcf("lp") end, min_dist = 190, cooldown = 70 },
	-- kara throw con st.MK (+6 px, el más fácil de los de Ken según la wiki)
	throw = function() return { { mk = true }, { lp = true, lk = true }, { hold = 2 } } end,
	kara = 0,          -- medido: el kara de st.MK no extendió el alcance en el lab (agarre normal = 74)
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	sweep_low = function() return M.press("hk", { down = true }, 2) end,
	meaty = { name = "cr.LK", anim = "d_LK", range = { 0, 105 }, startup = 5, seq = function() return M.press("lk", { down = true }, 2) end },
	pressure = { tick = 3, trap = 3, low = 3, uoh = 1, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.3, cd = 2400 }
	),
}
