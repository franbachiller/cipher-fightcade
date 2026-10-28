-- Ryu (wiki SuperCombo 3S/Ryu/Strategy): pokes cr.MK (cancela a SA1/EX hadouken), st.MP, cr.MP (rapidísimo, barra),
-- st.MK (pasa por encima de bajos). EX Hadouken es seguro en bloqueo/parry: usarlo. Anti-air: st.LP/cl.LP es el mejor
-- (si lo parrean, otro LP), Shoryuken, cr.HP. Wakeup: f.MP overhead lento (meaty linkea a SA1), cl.MK meaty seguro,
-- cr.LK cr.LK, UOH meaty. Kara throw con f.MP (medido: +~20 px sobre el agarre normal).
local M = input_lib.motion
local SP = require("games.sfiii3.chars.sp")
return {
	name = "ryu",
	ideal_range = 135,
	pokes = {
		{ name = "cr.MK", anim = "d_MK", range = { 0, 138 }, startup = 7, seq = function() return M.press("mk", { down = true }, 2) end, cancel = true },
		{ name = "st.MP", anim = "MP", range = { 60, 107 }, startup = 5, seq = function() return M.press("mp", nil, 2) end, cancel = true },
		{ name = "cr.MP", anim = "d_MP", range = { 0, 103 }, startup = 5, seq = function() return M.press("mp", { down = true }, 2) end, cancel = true },
		{ name = "st.MK", anim = "MK", range = { 70, 111 }, startup = 6, seq = function() return M.press("mk", nil, 2) end },
	},
	-- wiki Ryu/Strategy: st.LP/cl.LP el mejor anti-air (si lo parrean, otro LP; si pega, link a SA), cr.HP con el
	-- rival casi encima, Shoryuken rápido pero riesgoso si lo parrean (va último). dx = distancia horizontal al llegar.
	-- Online: 13 st.LP al aire con el rival a 69-120 px (llega a ~60): más lejos, nada (guardia / parry aéreo)
	antiair = {
		{ name = "cr.HP", anim = "d_HP", startup = 5, dx = { 0, 35 }, seq = function() return M.press("hp", { down = true }, 2) end },
		{ name = "st.LP", anim = "LP", startup = 4, dx = { 25, 60 }, seq = function() return M.press("lp", nil, 2) end },
		{ name = "shoryuken_HP", startup = 3, dx = { 0, 75 }, seq = function() return M.dp("hp") end },
	},
	-- sin anti-air especial automático (shoryuken_LP de chars/auto.lua le ganaba al LP / cr.HP el 80%: 46 de 52 en el
	-- health check). El Shoryuken queda último en la lista de arriba, como pide la wiki (riesgoso si lo parrean)
	antiair_special = false,
	overhead = { name = "f.MP overhead", seq = function() return { { fwd = true, mp = true, hold = 2 }, { hold = 14 } } end },
	confirm = {
		{ meter = 1, seq = function() return M.qcf2("lp") end, name = "> shinkuu_hadouken" },
		{ meter = 1, seq = function() return M.qcf({ "lp", "mp" }) end, name = "> EX hadouken" },
		{ seq = function() return M.qcf("hp") end, name = "> hadouken" },
	},
	-- poke bloqueado xx EX Hadouken (wiki: "EX Hadouken it's incredible. It's safe on block and almost always safe on
	-- parry. Use it.")
	-- no con SA2: una sola barra (wiki: ~3 EX); el EX la vaciaba y no quedaba Shin Shoryuken para los combos
	block_cancel = { name = "EX hadouken", meter = 1, rate = 0.4, from = { d_MK = true, MP = true, d_MP = true }, no_sa = { [2] = true },
		seq = function() return M.qcf({ "lp", "mp" }) end },
	fireball = { name = "hadouken", seq = function() return M.qcf("lp") end, min_dist = 190, cooldown = 70 },
	-- kara throw (wiki Ryu/Strategy: adelante sostenido, f.MP y LP+LK al frame siguiente). Medido en el emulador
	-- (tools/test_range.lua, Ryu vs Ryu): agarre normal hasta ~72 px, kara hasta 94 px
	throw = function() return { { fwd = true, hold = 2 }, { fwd = true, mp = true }, { fwd = true, lp = true, lk = true }, { hold = 2 } } end,
	kara = 18,                   -- px extra sobre el agarre normal medido (~72 -> kara ~90-94)
	tech  = function() return { { down = true, back = true, lp = true, lk = true }, { down = true, back = true, hold = 2 } } end,
	meaty = { name = "cl.MK", anim = "cl_MK", range = { 0, 97 }, startup = 4, seq = function() return M.press("mk", nil, 2) end },
	pressure = { tick = 3, trap = 3, low = 3, uoh = 2, bait = 1 },
	-- especiales de identidad por rol (tools/add_specials.py)
	specials = SP.list(
		SP.make("ryu", "hadouken", "EXP", "zoning", { range = { 160, 280 }, meter = 1, rate = 0.03, cd = 120, no_sa = { [2] = true } }),
		SP.make("ryu", "joudan", "MK", "approach", { range = { 130, 175 }, rate = 0.03, cd = 180 }),
		{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = 0.2, cd = 2400 }
	),
}
