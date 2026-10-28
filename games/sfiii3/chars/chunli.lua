-- Chun-Li (wiki SuperCombo 3S/Chun-Li/Strategy): personaje de neutral. cr.MK es la base (rápido, seguro, confirma
-- SA2 Houyoku-Sen = su condición de victoria), 4HP le gana a los botones del rival, st.HP golpea de lejos, cr.MP es
-- el bajo más largo. Anti-air estándar st.MK; cr.HK derriba saltos bajos. Ofensiva: cr.LP (+) a frame traps / tick
-- throws, y el kara throw desde st.MK (+32 px, el más largo del juego). Defensa: crouch tech (abajo-atrás + LP+LK).
-- "anim" = nombre de la animación en la frame data: con eso el bot usa el alcance exacto (games/sfiii3/ranges.lua).
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "chunli",
	ideal_range = 128,         -- punta de cr.MK
	pokes = {
		{ name = "cr.MK", anim = "d_MK", range = { 0, 128 }, startup = 6, seq = function() return M.press("mk", { down = true }, 2) end, cancel = true },
		{ name = "4HP", anim = "b_HP", range = { 60, 132 }, startup = 7, seq = function() return M.press("hp", { back = true }, 2) end },
		{ name = "st.HP", anim = "HP", range = { 120, 168 }, startup = 8, seq = function() return M.press("hp", nil, 2) end },
		{ name = "cr.MP", anim = "d_MP", range = { 100, 147 }, startup = 8, seq = function() return M.press("mp", { down = true }, 2) end },
	},
	antiair = {
		-- dx = distancia horizontal al llegar: online st.MK erró 23 veces a 78-88 px y cr.HK 12 a 113-120 px
		{ name = "st.MK", anim = "MK", startup = 7, dx = { 0, 65 }, seq = function() return M.press("mk", nil, 2) end },
		{ name = "cr.HK", anim = "d_HK", startup = 7, dx = { 20, 80 }, seq = function() return M.press("hk", { down = true }, 2) end },
	},
	-- cr.MK conectó (RAM) -> SA2 si hay barra (los combos del laboratorio tienen prioridad sobre esto)
	confirm = {
		{ meter = 1, seq = function() return M.qcf2("lk") end, name = "> houyokusen" },
	},
	fireball = { name = "kikouken", seq = function()
		return { { back = true }, { down = true, back = true }, { down = true }, { down = true, fwd = true }, { fwd = true, lp = true } }
	end, min_dist = 200, cooldown = 90 },
	-- kara throw: st.MK cancelado al frame siguiente en agarre (+32 px de alcance)
	throw = function() return { { mk = true }, { lp = true, lk = true }, { hold = 2 } } end,
	-- la wiki dice +32 px, pero online 34 de 57 agarres erraron a 80-99 px (el kara de Ryu medido: ~+20 quieto).
	-- Medido (tools/test_range.lua vs Gouki): normal ~68, kara st.MK hasta 90-94 -> +20 (con margen)
	kara = 18,
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	meaty = { name = "cr.LK", anim = "d_LK", range = { 0, 108 }, startup = 4, seq = function() return M.press("lk", { down = true }, 2) end },
	pressure = { tick = 5, trap = 3, low = 2, uoh = 1, bait = 1 },     -- el agarre es su "abrelatas"
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		{ name = "lightning_legs", role = "poke", range = { 0, 95 }, rate = 0.04, cd = 150, seq = function() local s = {} for i = 1, 8 do s[#s + 1] = { lk = true } s[#s + 1] = {} end s[#s + 1] = { hold = 10 } return s end },
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.15, cd = 2400 }
	),
}
