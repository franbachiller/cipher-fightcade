-- Twelve (wiki SuperCombo 3S/Twelve/Strategy): de los más débiles; mucha movilidad y buenos pokes. Zoning: st.MP,
-- cr.MK, st.HK, NDL. Mezclas: Kokkuu HK, IAD (air dash). Pokes largos y rápidos: LP (3f, largo), cr.LK (3f).
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "twelve",
	ideal_range = 145,
	-- online: 30 cr.MK (no se cancela: nunca terminaba en X.N.D.L.) y 2 supers en 2 peleas. Primero los normales que
	-- cancelan al super de proyectil: st.MP xx SA (54 en el lab, 41 online) a toda su distancia y cl.MP xx SA de cerca
	pokes = {
		{ name = "st.MP", anim = "MP", range = { 90, 174 }, startup = 9, seq = function() return M.press("mp", nil, 2) end },
		{ name = "cl.MP", anim = "cl_MP", range = { 0, 50 }, startup = 6, seq = function() return M.press("mp", nil, 2) end },
		{ name = "cr.MK", anim = "d_MK", range = { 0, 153 }, startup = 8, seq = function() return M.press("mk", { down = true }, 2) end },
		{ name = "st.HK", anim = "HK", range = { 140, 205 }, startup = 17, seq = function() return M.press("hk", nil, 2) end },
		{ name = "cr.LK", anim = "d_LK", range = { 0, 130 }, startup = 3, seq = function() return M.press("lk", { down = true }, 2) end },
	},
	fireball = { name = "ndl", seq = function() return M.qcf("lp") end, min_dist = 150, cooldown = 80 },
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 3, trap = 2, low = 3, uoh = 2, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		{ name = "air_dash_in", role = "approach", range = { 120, 210 }, rate = 0.05, cd = 150, seq = function() return { { up = true, fwd = true, hold = 3 }, { hold = 5 }, { fwd = true }, {}, { fwd = true }, { hold = 8 }, { hk = true, hold = 3 }, { hold = 14 } } end },
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.3, cd = 2400 }
	),
}
