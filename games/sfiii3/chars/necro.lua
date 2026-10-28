-- Necro (la wiki no tiene página de estrategia descargable: tabla desde la frame data). Extremidades elásticas:
-- pokes larguísimos (st.MK 170 px, cr.MK 204, st.LP 143). Snake Fang (hcf+K) es un agarre de comando de alcance
-- enorme (~170-190 px): se usa para castigar. Cr.LK / cr.LP rápidos de cerca.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
local function snake_fang()
	return { { back = true }, { down = true, back = true }, { down = true }, { down = true, fwd = true }, { fwd = true, lk = true }, { hold = 2 } }
end
return {
	name = "necro",
	ideal_range = 165,
	pokes = {
		{ name = "st.MK", anim = "MK", range = { 90, 167 }, startup = 9, seq = function() return M.press("mk", nil, 2) end },
		{ name = "st.LP", anim = "LP", range = { 60, 140 }, startup = 5, seq = function() return M.press("lp", nil, 2) end },
		{ name = "cr.MK", anim = "d_MK", range = { 120, 201 }, startup = 12, seq = function() return M.press("mk", { down = true }, 2) end },
		{ name = "cr.LK", anim = "d_LK", range = { 0, 132 }, startup = 6, seq = function() return M.press("lk", { down = true }, 2) end },
	},
	command_grab = { name = "snake_fang", seq = snake_fang, range = 165 },
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 3, trap = 2, low = 3, uoh = 2, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("necro", "flying_viper", "LP", "approach", { range = { 100, 170 }, rate = 0.03, cd = 180 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.25, cd = 2400 }
	),
}
