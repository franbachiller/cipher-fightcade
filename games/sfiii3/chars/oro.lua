-- Oro (wiki SuperCombo 3S/Oro/Strategy): neutral fuerte de "pega y se va", sin conversiones grandes desde golpes sueltos.
-- Pokes: far MK (8f, le gana al cr.MK de los shotos bien espaciado), st.HK (7f, muchísimo stun), far MP (caja más baja:
-- contra los que se agachan bajo las patadas: Chun, Elena, Yun/Yang), cr.MK (bajo 6f, +0 en bloqueo, combo a su
-- hit-grab Niouriki = derribo duro), cr.HP (6f, castiga golpes errados). Anti-air: st.HK, cr.HP, cl.LP y las bolas
-- MP/HP (en ángulo). Kara throw con st.HK (+14, sin normal de proximidad). Carga: Nichirin (bola) y Oniyanma (subida).
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
local function hcb(btn)
	return { { fwd = true }, { down = true, fwd = true }, { down = true }, { down = true, back = true }, { back = true, [btn] = true } }
end
return {
	name = "oro",
	ideal_range = 140,
	pokes = {
		{ name = "far MK", anim = "MK", range = { 100, 156 }, startup = 8, seq = function() return M.press("mk", nil, 2) end },
		{ name = "st.HK", anim = "HK", range = { 90, 144 }, startup = 7, seq = function() return M.press("hk", nil, 2) end },
		{ name = "cr.MK", anim = "d_MK", range = { 0, 109 }, startup = 6, seq = function() return M.press("mk", { down = true }, 2) end, cancel = true },
		{ name = "far MP", anim = "MP", range = { 90, 150 }, startup = 8, seq = function() return M.press("mp", nil, 2) end },
	},
	antiair = {
		-- dx = distancia horizontal al llegar (lección de Ryu/Chun: sin rango salían al aire)
		-- abajo-ADELANTE + HP: desde la carga agachado-atrás, abajo + HP completaba el medio círculo atrás y salía Niouriki
		-- (5 anti-airs al aire online)
		{ name = "cr.HP", anim = "d_HP", startup = 6, dx = { 0, 45 }, seq = function() return M.press("hp", { down = true, fwd = true }, 2) end },
		{ name = "st.HK", anim = "HK", startup = 7, dx = { 30, 65 }, seq = function() return M.press("hk", nil, 2) end },
	},
	punish = {
		{ name = "cr.HP", anim = "d_HP", range = { 0, 119 }, startup = 6, seq = function() return M.press("hp", { down = true }, 2) end },
	},
	-- cr.MK conectó -> Niouriki (hit-grab, derribo duro). cr.MK xx hcb+P (wiki: mixups)
	confirm = {
		{ seq = function() return hcb("lp") end, name = "> niouriki" },
	},
	-- kara throw st.HK (+14 px; far MK da +28 pero choca con el cl.MK de proximidad)
	throw = function() return { { hk = true }, { lp = true, lk = true }, { hold = 2 } } end,
	kara = 14,                   -- medido (tools/test_range.lua vs Ryu): kara st.HK agarra hasta ~86 px
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 3, trap = 3, low = 3, uoh = 2, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("oro", "tenguishi", "", "install", { meter = 1, sa = 3, rate = 0.5, cd = 900 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.1, cd = 2400 }
	),
}
