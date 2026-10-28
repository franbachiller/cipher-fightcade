-- Yang (wiki SuperCombo 3S/Yang/Strategy): cr.MK es su poke principal (castiga golpes errados, el más largo que
-- convierte sin barra), st.MK anti-air/poke, st.HP poke largo de mucho daño (lento), st.LK (4f, el débil más largo:
-- castigos), cr.LK, cl.MP (rápido, buena ventaja). SA2 contra casi todos (SA3 vs grandes: Alex, Hugo, Makoto, Necro,
-- Q, Urien). Rekka Tourouzan (qcf+P) tras confirmar.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "yang",
	ideal_range = 120,
	pokes = {
		{ name = "cr.MK", anim = "d_MK", range = { 0, 116 }, startup = 7, seq = function() return M.press("mk", { down = true }, 2) end, cancel = true },
		{ name = "st.MK", anim = "MK", range = { 80, 160 }, startup = 9, seq = function() return M.press("mk", nil, 2) end },
		{ name = "st.LK", anim = "LK", range = { 0, 108 }, startup = 3, seq = function() return M.press("lk", nil, 2) end },
		{ name = "st.HP", anim = "HP", range = { 120, 159 }, startup = 9, seq = function() return M.press("hp", nil, 2) end },
	},
	antiair = {
		{ name = "st.MK", anim = "MK", startup = 9, seq = function() return M.press("mk", nil, 2) end },
		{ name = "st.HP", anim = "HP", startup = 9, seq = function() return M.press("hp", nil, 2) end },
	},
	confirm = {
		{ meter = 1, seq = function() return M.qcf2("lk") end, name = "> tenshinsenkyuutai" },
		{ seq = function() return M.qcf("lp") end, name = "> tourouzan" },
	},
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 3, trap = 3, low = 3, uoh = 2, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		{ name = "tourouzan_x3", role = "poke", range = { 0, 115 }, rate = 0.05, cd = 150, seq = function() local s = {} for i = 1, 3 do for _, f in ipairs({ { down = true }, { down = true, fwd = true }, { fwd = true, lp = true }, { hold = 6 } }) do s[#s + 1] = f end end return s end },
		SP.make("yang", "senkyuutai", "LK", "approach", { range = { 110, 170 }, rate = 0.03, cd = 180 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.2, cd = 2400 }
	),
}
