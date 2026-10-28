-- Tabla de golpes generada desde la frame data para CUALQUIER personaje.
-- Normales: input desde el nombre (d_MK = abajo+MK, f_HK = adelante+HK, cl_HP = HP de cerca),
-- alcance = max(-left) de sus cajas de ataque, startup = primer frame activo.
local FD = require("games.sfiii3.framedata")
local M = input_lib.motion
local ROOT = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])games[\\/]") or ".\\")

local BODY = 26          -- media anchura típica del hurtbox rival: alcance efectivo centro a centro
local PREFIX = { [""] = {}, d = { down = true }, f = { fwd = true }, b = { back = true }, cl = {} }
local BTN = { LP = "lp", MP = "mp", HP = "hp", LK = "lk", MK = "mk", HK = "hk" }
local HEAVY = { hp = 3, hk = 3, mp = 2, mk = 2, lp = 1, lk = 1 }

local function reach_of(a)
	local reach, top = 0, 0
	for _, boxes in pairs(a.atk or {}) do
		for _, bx in ipairs(boxes) do
			-- bx = {bottom, height, left, width}
			if -bx[3] > reach then reach = -bx[3] end
			if bx[1] + bx[2] > top then top = bx[1] + bx[2] end
		end
	end
	return reach, top
end

local function normals(char)
	local c = FD.char(char)
	local out = {}
	if not c then return out end
	for _, a in pairs(c.anims) do
		local pre, b = (a.n or ""):match("^(%a-)_?([LMH][PK])$")
		if b and PREFIX[pre] and a.hit and not a.air then
			local reach, top = reach_of(a)
			local dirs = PREFIX[pre]
			out[#out + 1] = {
				name = a.n, btn = BTN[b], dirs = dirs, startup = a.hit[1][1], reach = reach, top = top,
				close = pre == "cl", low = a.ht and a.ht[1] == 2, recovery = (a.idle or a.len) - a.hit[#a.hit][2],
			}
		end
	end
	return out
end

local function press_seq(n)
	local dirs = {}
	for k, v in pairs(n.dirs) do dirs[k] = v end
	return function() return M.press(n.btn, dirs, 2) end
end

return function(char)
	local ns = normals(char)
	local t = { name = char .. " (auto)", pokes = {}, antiair = {}, punish = {}, confirm = {} }

	-- meaty de okizeme: débil bajo (wiki: cr.LK de Ken, 3 activos; deja al bot encima para seguir presionando).
	-- Antes el meaty era el poke más largo (cr.MK) y el empuje dejaba la pelea a 90-130 px.
	for _, n in ipairs(ns) do
		if n.name == "d_LK" then
			t.meaty = { name = "cr.LK", range = { 0, n.reach + BODY }, startup = n.startup, seq = press_seq(n) }
		end
	end

	-- pokes: alcance largo, startup razonable, recuperación no enorme
	table.sort(ns, function(a, b) return a.reach > b.reach end)
	for _, n in ipairs(ns) do
		if not n.close and n.startup <= 10 and n.recovery <= 22 and #t.pokes < 3 then
			t.pokes[#t.pokes + 1] = { name = n.name, range = { 0, n.reach + BODY }, startup = n.startup, seq = press_seq(n) }
		end
	end
	-- anti-air: normal rápido con caja alta
	table.sort(ns, function(a, b) return (a.top - a.startup * 6) > (b.top - b.startup * 6) end)
	for _, n in ipairs(ns) do
		if ((n.top >= 80 and n.startup <= 8) or (n.top >= 95 and n.startup <= 11)) and not n.low and #t.antiair < 2 then
			t.antiair[#t.antiair + 1] = { name = n.name, startup = n.startup, seq = press_seq(n) }
		end
	end
	-- castigo: más pesado primero, después más rápido
	table.sort(ns, function(a, b)
		if HEAVY[a.btn] ~= HEAVY[b.btn] then return HEAVY[a.btn] > HEAVY[b.btn] end
		return a.startup < b.startup
	end)
	for _, n in ipairs(ns) do
		if #t.punish < 4 then
			t.punish[#t.punish + 1] = { name = n.name, range = { 0, n.reach + BODY }, startup = n.startup, seq = press_seq(n) }
		end
	end
	-- respaldo: el normal NO bajo con la caja más alta (antes caía al primer castigo: Hugo usaba el barrido;
	-- sin ningún anti-air, Urien/Yun empeoraban)
	if #t.antiair == 0 then
		local best
		for _, n in ipairs(ns) do
			if not n.low and not n.dirs.down and n.startup <= 14 and (not best or n.top > best.top) then best = n end
		end
		if best then t.antiair[1] = { name = best.name, startup = best.startup, seq = press_seq(best) } end
	end
	t.antiair[2] = t.antiair[2] or t.antiair[1]

	-- especiales en neutral desde la frame data: proyectil (zoneo) y anti-air (startup corto + caja alta)
	local okm, moves = pcall(dofile, ROOT .. "data\\sfiii3\\moves\\" .. char .. ".lua")
	local c = FD.char(char)
	t.charge_moves = false
	if okm and c then
		local best_aa, best_fb
		local ex_of = {}            -- versión EX de cada especial (para el reversal)
		for _, m in ipairs(moves) do
			if m.type == "special" then
				for vi, v in ipairs(m.variants) do
					local a = c.anims and (function()
						for _, an in pairs(c.anims) do if an.n == m.name .. "_" .. v.btn or an.n == m.name then return an end end
					end)()
					if a and not a.air then
						if v.charge then t.charge_moves = true end
						local seq_copy = function()
							local out = {}
							for i, fr in ipairs(v.seq) do local f2 = {} for k, x in pairs(fr) do f2[k] = x end out[i] = f2 end
							return out
						end
						local entry = { name = m.name .. "_" .. v.btn, seq = seq_copy, charge = v.charge, ex = v.btn:match("^EX") ~= nil }
							if entry.ex then ex_of[m.name] = entry end
						if a.proj and #a.proj > 0 and not entry.ex and (not best_fb or vi == 1) then
							entry.min_dist, entry.cooldown = 170, 60
							best_fb = best_fb or entry
						end
						if a.hit and not entry.ex then
							local reach, top = reach_of(a)
							local su = a.hit[1][1]
							if su <= 7 and top >= 95 and (not best_aa or su < best_aa.startup) then
								entry.startup = su
								best_aa = entry
							end
						end
					end
				end
			end
		end
		t.fireball = best_fb
		t.antiair_special = best_aa
		-- reversal: la versión EX del especial anti-air (EX DP, EX SBK, EX Kazekiri...: invulnerables al salir)
		if best_aa then t.reversal = ex_of[(best_aa.name:gsub("_[^_]+$", ""))] end
	end
	t.throw = function() return M.press({ "lp", "lk" }, { fwd = true }, 2) end
	t.tech = function() return M.press({ "lp", "lk" }, nil, 3) end
	t.ideal_range = (t.pokes[1] and t.pokes[1].range[2] or 110) + 5
	t.normals = ns
	return t
end
