-- Hugo: grappler. La tabla automática lo hacía jugar de footsies (cr.MK / LP LP LP, st.MK de anti-air) y nunca
-- usaba sus agarres de comando. Plan: acercarse y agarrar (Moonsault Press 360+P), anti-air con Shootdown
-- Backbreaker (DP+K, agarre aéreo), okizeme con agarre de comando. Lo que no está acá lo completa chars/auto.lua.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")

-- 360 verificado con tools\test_360.lua (variante F): empezar desde ATRÁS y terminar en arriba + botón.
-- Empezar con adelante después de caminar = adelante, neutral, adelante = DASH (el agarre nunca salía),
-- y "d, db, b + P" dentro de la vuelta = Giant Palm Bomber.
local function spin(btn)
	return { { back = true }, { down = true, back = true }, { down = true }, { down = true, fwd = true }, { fwd = true },
		{ up = true, fwd = true }, { up = true, [btn] = true }, { hold = 2 } }
end

return {
	name = "hugo",
	grappler = true,
	grab_range = 56,          -- medido: a 58-60 el 360 sale como salto (fuera de alcance)
	ideal_range = 70,         -- pegado al rival: su juego es el agarre
	antiair = {
		{ name = "shootdown_backbreaker_LK", startup = 5, seq = function() return M.dp("lk") end },
		{ name = "shootdown_backbreaker_MK", startup = 5, seq = function() return M.dp("mk") end },
	},
	antiair_special = { name = "shootdown_backbreaker_HK", startup = 5, seq = function() return M.dp("hk") end },
	-- agarre de comando: lo usa el brain en footsies cerca, en okizeme ("throw") y como castigo corto
	throw = function() return spin("lp") end,
	command_grab = { name = "moonsault_press", seq = function() return spin("lp") end, range = 56 },
	meat_squasher = { name = "meat_squasher", seq = function() return spin("lk") end, range = 75 },
	tech  = function() return M.press({ "lp", "lk" }, nil, 3) end,
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("hugo", "monster_lariat", "LK", "approach", { range = { 120, 190 }, rate = 0.03, cd = 200 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.35, cd = 2400 }
	),
}
