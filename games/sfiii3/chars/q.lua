-- Q (wiki SuperCombo 3S/Q/Strategy): defensivo y de mucho daño. Neutral: llenar barra whifeando pokes rápidos a
-- distancia segura; pokes st.MK, cr.MP, cr.LK, cr.MK (no cancelan: solo espacio y chip). Anti-air: cr.MP, b.MP.
-- Ofensiva: su agarre de comando (Capture & Deadly Blow, hcb+K) es el núcleo (lento pero mucho daño), con frame traps
-- desde st.LP / cr.LP / st.LK / cl.LP (sus únicos golpes plus). Pocos dash punch "random" (se parrean fácil).
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
local function capture()
	return { { fwd = true }, { down = true, fwd = true }, { down = true }, { down = true, back = true }, { back = true, lk = true }, { hold = 2 } }
end
return {
	name = "q",
	ideal_range = 125,
	pokes = {
		{ name = "st.MK", anim = "MK", range = { 60, 122 }, startup = 8, seq = function() return M.press("mk", nil, 2) end },
		{ name = "cr.MP", anim = "d_MP", range = { 0, 134 }, startup = 8, seq = function() return M.press("mp", { down = true }, 2) end },
		{ name = "cr.MK", anim = "d_MK", range = { 0, 122 }, startup = 7, seq = function() return M.press("mk", { down = true }, 2) end },
		{ name = "cr.LK", anim = "d_LK", range = { 0, 128 }, startup = 6, seq = function() return M.press("lk", { down = true }, 2) end },
	},
	antiair = {
		{ name = "cr.MP", anim = "d_MP", startup = 8, seq = function() return M.press("mp", { down = true }, 2) end },
		{ name = "b.MP", anim = "b_MP", startup = 8, seq = function() return M.press("mp", { back = true }, 2) end },
	},
	command_grab = { name = "capture_and_deadly_blow", seq = capture, range = 128 },
	throw = capture,           -- tick / oki con el agarre de comando
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 5, trap = 3, low = 2, uoh = 1, bait = 2 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("q", "dashing_head_attack", "LP", "approach", { range = { 110, 185 }, rate = 0.04, cd = 180 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.5, cd = 2400 }
	),
}
