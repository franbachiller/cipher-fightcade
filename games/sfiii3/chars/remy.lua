-- Remy (wiki SuperCombo 3S/Remy/Strategy): carga, zoning con Light of Virtue. Su agarre neutral es clave (manda al
-- rival lejos, rumbo a la esquina) y el kara throw con st.MP da muchísimo alcance (pendiente de medir: kara = 0).
-- Aperturas: cl.MK (linkea SA2) y cr.LP x2. Pokes: cr.MK, cr.HK (barrida larga), MK. Anti-air: Rising Rage Flash (carga).
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "remy",
	ideal_range = 140,
	pokes = {
		{ name = "cr.MK", anim = "d_MK", range = { 0, 141 }, startup = 8, seq = function() return M.press("mk", { down = true }, 2) end, cancel = true },
		{ name = "MK", anim = "MK", range = { 60, 127 }, startup = 8, seq = function() return M.press("mk", nil, 2) end },
		{ name = "cr.HK", anim = "d_HK", range = { 120, 171 }, startup = 9, seq = function() return M.press("hk", { down = true }, 2) end },
	},
	throw = function() return { { mp = true }, { lp = true, lk = true }, { hold = 2 } } end,      -- kara st.MP
	confirm = {
		{ meter = 1, seq = function() return M.qcf2("lk") end, name = "> supreme_rising_rage" },
	},
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 4, trap = 2, low = 3, uoh = 2, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("remy", "cold_blue_kick", "LK", "approach", { range = { 100, 170 }, rate = 0.04, cd = 180 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.2, cd = 2400 }
	),
}
