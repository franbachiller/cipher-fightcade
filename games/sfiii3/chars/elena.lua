-- Elena (wiki SuperCombo 3S/Elena/Strategy): uno de los mejores wakeups del juego, todo desde el mismo lugar: c.HK
-- (derribo bajo), T+MK overhead rapidísimo, UOH, kara throw y c.MP xx EX Spin Scythe / SA2. Pokes: c.MP, MK, c.MK.
-- Anti-air: Scratch Wheel (DP+K). SA2 Brave Dance.
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "elena",
	ideal_range = 130,
	pokes = {
		{ name = "c.MP", anim = "d_MP", range = { 0, 127 }, startup = 6, seq = function() return M.press("mp", { down = true }, 2) end, cancel = true },
		{ name = "MK", anim = "MK", range = { 60, 127 }, startup = 7, seq = function() return M.press("mk", nil, 2) end },
		{ name = "c.MK", anim = "d_MK", range = { 0, 129 }, startup = 8, seq = function() return M.press("mk", { down = true }, 2) end },
		{ name = "c.HK", anim = "d_HK", range = { 90, 137 }, startup = 11, seq = function() return M.press("hk", { down = true }, 2) end },
	},
	antiair_special = { name = "scratch_wheel_HK", startup = 3, seq = function() return M.dp("hk") end },
	overhead = { name = "T+MK overhead", seq = function() return { { fwd = true, mk = true, hold = 2 }, { hold = 14 } } end },
	confirm = {
		{ meter = 1, seq = function() return M.qcf2("lk") end, name = "> brave_dance" },
	},
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	pressure = { tick = 3, trap = 2, low = 3, uoh = 3, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("elena", "spin_sides", "LK", "poke", { range = { 90, 160 }, rate = 0.04, cd = 150 }),
		SP.make("elena", "rhino_horn", "LK", "approach", { range = { 120, 175 }, rate = 0.03, cd = 180 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.2, cd = 2400 }
	),
}
