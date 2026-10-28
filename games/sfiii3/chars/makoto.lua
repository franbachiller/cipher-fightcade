-- Makoto (wiki SuperCombo 3S/Makoto/Strategy): grappler de rushdown, el mejor okizeme del juego. Todo gira alrededor
-- del Karakusa (agarre de comando, hcb+K) y de cargar el super. st.LP saca saltos (después dash por debajo), Hayate
-- (qcf+P) para entrar. Okizeme: meaty st.MP -> Karakusa (agarre) o frame trap; st.LK -> tick Karakusa; UOH.
-- Caminata lenta y dash malo: los personajes de pokes largos la zonean.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
local function karakusa()
	return { { fwd = true }, { down = true, fwd = true }, { down = true }, { down = true, back = true }, { back = true, lk = true }, { hold = 2 } }
end
return {
	name = "makoto",
	grappler = true,
	ideal_range = 95,
	pokes = {
		{ name = "cr.MP", anim = "d_MP", range = { 0, 138 }, startup = 7, seq = function() return M.press("mp", { down = true }, 2) end },
		{ name = "st.MK", anim = "MK", range = { 60, 160 }, startup = 7, seq = function() return M.press("mk", nil, 2) end },
		{ name = "st.LK", anim = "LK", range = { 0, 120 }, startup = 4, seq = function() return M.press("lk", nil, 2) end },
	},
	antiair = {
		{ name = "st.LP", anim = "LP", startup = 4, seq = function() return M.press("lp", nil, 2) end },
		{ name = "st.MK", anim = "MK", startup = 7, seq = function() return M.press("mk", nil, 2) end },
	},
	command_grab = { name = "karakusa", seq = karakusa, range = 86 },
	throw = karakusa,
	confirm = {
		{ seq = function() return M.qcf("lp") end, name = "> hayate" },
	},
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	meaty = { name = "st.MP", anim = "MP", range = { 0, 105 }, startup = 8, seq = function() return M.press("mp", nil, 2) end },
	pressure = { tick = 5, trap = 3, low = 2, uoh = 2, bait = 1 },     -- tick Karakusa: su arma
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("makoto", "hayate", "LP", "approach", { range = { 100, 180 }, rate = 0.07, cd = 120 }),
		SP.make("makoto", "oroshi", "LP", "poke", { range = { 0, 80 }, rate = 0.03, cd = 180 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.2, cd = 2400 }
	),
}
