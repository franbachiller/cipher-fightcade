-- Urien (wiki SuperCombo 3S/Urien/Strategy): carga, alto, juego a la esquina. SA3 Aegis Reflector (su fuerza).
-- Pokes principales: s.MP (no le pega agachados), s.HP, s.MK, c.MK, c.LK, c.HK. Mezclas: bajos agachados, UOH y
-- f.HP (alto). Anti-air: Dangerous Headbutt (carga abajo -> arriba+P) y s.HP.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "urien",
	ideal_range = 135,
	pokes = {
		{ name = "c.MK", anim = "d_MK", range = { 0, 134 }, startup = 7, seq = function() return M.press("mk", { down = true }, 2) end },
		{ name = "s.HP", anim = "HP", range = { 80, 131 }, startup = 10, seq = function() return M.press("hp", nil, 2) end },
		{ name = "s.MK", anim = "MK", range = { 90, 161 }, startup = 8, seq = function() return M.press("mk", nil, 2) end },
		{ name = "c.HK", anim = "d_HK", range = { 100, 143 }, startup = 12, seq = function() return M.press("hk", { down = true }, 2) end },
	},
	antiair = {
		{ name = "s.HP", anim = "HP", startup = 10, seq = function() return M.press("hp", nil, 2) end },
		{ name = "c.HP", anim = "d_HP", startup = 9, seq = function() return M.press("hp", { down = true }, 2) end },
	},
	overhead = { name = "f.HP overhead", seq = function() return { { fwd = true, hp = true, hold = 2 }, { hold = 16 } } end },
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 3, trap = 2, low = 3, uoh = 3, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("urien", "aegis_reflector", "", "install", { meter = 1, sa = 3, rate = 0.5, cd = 900 }),
		SP.make("urien", "chariot_tackle", "LK", "approach", { range = { 100, 180 }, rate = 0.05, cd = 150 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.2, cd = 2400 }
	),
}
