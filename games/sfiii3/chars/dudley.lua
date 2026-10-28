-- Dudley (wiki SuperCombo 3S/Dudley): rushdown con las mejores mezclas del juego y mucho daño.
-- 6HK Dart Shot = overhead casi imposible de reaccionar (reemplaza al universal en las mezclas); cr.LK > cr.LK es el
-- bajo con confirm. Golpes plus para sostener la presión: st.HK (+4 en bloqueo, 5f, cancelable), cr.MP (+2), 6MK (+2),
-- st.MP (3f). Sin buen bajo largo: juega cerca (caminata rápida, salto bajo). Anti-air: Jet Upper (DP) y normales.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "dudley",
	ideal_range = 100,           -- rushdown: pegado
	pokes = {
		{ name = "st.HK", anim = "HK", range = { 0, 114 }, startup = 5, seq = function() return M.press("hk", nil, 2) end, cancel = true },
		{ name = "cr.MP", anim = "d_MP", range = { 0, 114 }, startup = 4, seq = function() return M.press("mp", { down = true }, 2) end, cancel = true },
		{ name = "6MK", anim = "f_MK", range = { 0, 101 }, startup = 5, seq = function() return M.press("mk", { fwd = true }, 2) end, cancel = true },
		{ name = "st.MP", anim = "MP", range = { 0, 129 }, startup = 3, seq = function() return M.press("mp", nil, 2) end },
	},
	-- overhead propio: 6HK Dart Shot (12f, linkea a super). Lo usan la presión y la mezcla en neutral.
	overhead = { name = "6HK dart shot", seq = function() return { { fwd = true, hk = true, hold = 2 }, { hold = 16 } } end },
	confirm = {
		{ meter = 1, seq = function() return M.qcf2("lp") end, name = "> rolling_thunder" },
	},
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 3, trap = 4, low = 3, uoh = 3, bait = 1 },     -- frame data plus: mucha presión
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("dudley", "machinegun_blow", "LP", "poke", { range = { 90, 150 }, rate = 0.04, cd = 150 }),
		SP.make("dudley", "ducking", "LK", "approach", { range = { 120, 200 }, rate = 0.04, cd = 180 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.25, cd = 2400 }
	),
}
