-- Ibuki (wiki SuperCombo 3S/Ibuki/Strategy): SA1 Kasumi Suzaku (3 stocks, mucho EX) contra todos. Pokes: c.MK, MK,
-- c.LP (3f), c.LK. Anti-air: c.HP (mejor caja, sale un poco lento), b.MP, Kazekiri (DP+K, 4f). Reversal: EX Kazekiri.
-- Raida (hcb+P) es su hit-grab (se puede combear y no respeta la protección de agarre).
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "ibuki",
	ideal_range = 115,
	pokes = {
		{ name = "c.MK", anim = "d_MK", range = { 0, 113 }, startup = 6, seq = function() return M.press("mk", { down = true }, 2) end, cancel = true },
		{ name = "MK", anim = "MK", range = { 0, 111 }, startup = 5, seq = function() return M.press("mk", nil, 2) end },
		{ name = "c.LP", anim = "d_LP", range = { 0, 99 }, startup = 3, seq = function() return M.press("lp", { down = true }, 2) end },
	},
	antiair = {
		{ name = "c.HP", anim = "d_HP", startup = 8, seq = function() return M.press("hp", { down = true }, 2) end },
		{ name = "b.MP", anim = "b_MP", startup = 6, seq = function() return M.press("mp", { back = true }, 2) end },
	},
	-- online: Kazekiri LK como anti-air recibió golpe en 5 de 7 usos (la versión LK casi no tiene invencibilidad;
	-- la invencible es la EX). Anti-air con normales (b.MP 6f, c.HP), como recomienda la wiki
	antiair_special = false,
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 3, trap = 3, low = 3, uoh = 2, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		-- online: Tsumuji LK de lejos y Hien de acercamiento fueron castigados 4 veces cada uno (inseguros si se
		-- bloquean): Tsumuji solo de cerca y menos seguido, Hien a la mitad
		SP.make("ibuki", "tsumuji", "LK", "poke", { range = { 70, 120 }, rate = 0.02, cd = 240 }),
		SP.make("ibuki", "hien", "LK", "approach", { range = { 110, 180 }, rate = 0.015, cd = 300 }),
		-- Kunai aéreo (salto adelante + qcf+LP): zoneo / aproximación característica de Ibuki
		-- verificado en el lab de inputs: salto > kunai_LP > conecta
		{ name = "kunai_aereo", role = "zoning", range = { 150, 260 }, rate = 0.03, cd = 200, seq = function()
			-- frame neutro antes (desde agachada / recuperación el salto se perdía y salía Kubiori, el qcf+P de piso)
			-- y 9 frames en el aire antes del motion
			return { { hold = 2 }, { up = true, fwd = true, hold = 3 }, { hold = 9 }, { down = true }, { down = true, fwd = true },
				{ fwd = true, lp = true }, { hold = 24 } } end },
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.15, cd = 2400 }
	),
}
