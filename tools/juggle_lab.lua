-- Lab de JUGGLES / combos largos: extiende rutas YA verificadas paso a paso con todo lo que tiene el personaje
-- (especiales en todas las fuerzas + EX, super, normales pesados), por cancel ("xx") o por link mientras el rival cae
-- (", "). Cada extensión que SUMA daño sin cortar el combo se guarda y se vuelve a extender: búsqueda iterativa hasta
-- que nada más entra o se acaba el tiempo. La próxima corrida sigue desde lo ya probado (_juggle_tested.lua).
-- Rápido: los tiempos del prefijo no se vuelven a buscar; cada ensayo arranca de un savestate tomado justo antes del
-- paso nuevo; la búsqueda de un link se corta en cuanto el rival tocó el piso (los t posteriores fallan seguro).
-- P2 = personaje, P1 = muñeco parado en el centro.
-- Env: CIPHER_JL_CHAR, CIPHER_JL_SA, CIPHER_JL_SLOT (1-9), CIPHER_JL_BUDGET (segundos, 170)
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
package.path = ROOT .. "?.lua;" .. package.path
input_lib = require("core.input")
local H = dofile(ROOT .. "tools\\harness.lua")
local S = require("games.sfiii3.state")
local WC = require("games.sfiii3.wiki_combo")

local CHAR = os.getenv("CIPHER_JL_CHAR") or "ryu"
local SA = tonumber(os.getenv("CIPHER_JL_SA") or "2")
local SLOT = tonumber(os.getenv("CIPHER_JL_SLOT") or "9")
local BUDGET = tonumber(os.getenv("CIPHER_JL_BUDGET") or "170")
local DUMMY = "ryu"
-- CIPHER_JL_CORNER=1: muñeco contra la pared izquierda (x ~125). Muchos juggles de 3S son solo de esquina (el rival
-- no se aleja con el golpe): Shippu > DP de Ken, etc. El brain los usa solo con el rival contra la pared
local CORNER = os.getenv("CIPHER_JL_CORNER") == "1"
local TAG = string.format("%s_sa%d_%s_juggle%s", CHAR, SA, DUMMY, CORNER and "_corner" or "")
local WDIR = ROOT .. "data\\sfiii3\\combos\\wiki\\"
local OUT, TESTED = WDIR .. TAG .. ".lua", WDIR .. TAG .. "_tested.lua"
local logf = io.open(ROOT .. "logs\\juggle_lab_" .. CHAR .. "_sa" .. SA .. (CORNER and "_corner" or "") .. ".log", "w")
local function L(...) logf:write(string.format(...) .. "\n") logf:flush() end
local T0 = os.time()

local rb, wb, rws = memory.readbyte, memory.writebyte, memory.readwordsigned
local P1B, P2B = S.P[1].base, S.P[2].base
local P2_COMBO, P2_STOCK, P2_MAXCOUNT = 0x0206961D, 0x020695EB, 0x020695E9
local NAMES = { lp = "Weak Punch", mp = "Medium Punch", hp = "Strong Punch", lk = "Weak Kick", mk = "Medium Kick", hk = "Strong Kick" }
local NEUTRAL = { standing = true, crouching = true, standing_begin = true, crouching_begin = true,
	standing_turn = true, crouching_turn = true, walk_forward = true, walk_back = true, walk_transition = true }

local MOVES = dofile(ROOT .. "data\\sfiii3\\moves\\" .. CHAR .. ".lua")
local function parse(text) return WC.parse(text, MOVES, SA) end

-- ---------------------------------------------------------------- catálogo de extensiones
local TOKS = { { tok = "SA", kind = "super" } }
for _, m in ipairs(MOVES) do
	if m.type == "special" then
		for _, v in ipairs(m.variants) do
			if not v.charge and v.btn ~= "" then TOKS[#TOKS + 1] = { tok = m.name .. ":" .. v.btn, kind = "special" } end
		end
	end
end
for _, n in ipairs({ "5HP", "2HP", "5HK", "5MK", "cl.HP" }) do TOKS[#TOKS + 1] = { tok = n, kind = "normal" } end

-- ---------------------------------------------------------------- persistencia
local results, tested, known = {}, {}, {}
do
	local ok, t = pcall(dofile, OUT)
	for _, r in ipairs(ok and type(t) == "table" and t or {}) do results[#results + 1] = r known[r.text] = true end
	local ok2, t2 = pcall(dofile, TESTED)
	for _, k in ipairs(ok2 and type(t2) == "table" and t2 or {}) do tested[k] = true end
end
local function save()
	local f = io.open(OUT, "w")
	f:write("-- generado por tools/juggle_lab.lua (" .. TAG .. "): combos largos / juggles verificados en emulador\nreturn {\n")
	for _, r in ipairs(results) do
		f:write(string.format("  { text = %q, ok = true, d = %d, sa = %d, dmg = %d, hits = %d, done = %d, t = {%s}, win = {%s}, pre = 0, jug = %d%s },\n",
			r.text, r.d, SA, r.dmg, r.hits, #r.t, table.concat(r.t, ","), table.concat(r.win, ","), r.jug or 1,
			CORNER and ", corner = true" or ""))
	end
	f:write("}\n")
	f:close()
	local g = io.open(TESTED, "w")
	g:write("return {\n")
	for k in pairs(tested) do g:write(string.format("  %q,\n", k)) end
	g:write("}\n")
	g:close()
end

-- ---------------------------------------------------------------- semillas: rutas verificadas + especiales sueltos
local queue = {}
local function add_node(n)
	if not n.steps then n.steps = parse(n.text) end
	if not n.steps or #n.steps ~= #n.t then return end
	for _, st in ipairs(n.steps) do if st.charge then return end end
	queue[#queue + 1] = n
end
for sa = 1, 3 do
	for _, suf in ipairs(CORNER and { "", "_auto", "_juggle" } or { "", "_auto" }) do
		local ok, list = pcall(dofile, WDIR .. CHAR .. "_sa" .. sa .. "_ryu" .. suf .. ".lua")
		for _, r in ipairs(ok and type(list) == "table" and list or {}) do
			local has_sa = r.text:find("SA") ~= nil
			if r.ok and (r.pre or 0) == 0 and r.dmg > 0 and (sa == SA or not has_sa) and not known[r.text] then
				known[r.text] = true
				local win = {} for i, w in ipairs(r.win or {}) do win[i] = tonumber(w) or 1 end
				add_node({ text = r.text, t = r.t, win = win, dmg = r.dmg, d = r.d, jug = 0 })
			end
		end
	end
end
for _, r in ipairs(results) do
	local win = {} for i, w in ipairs(r.win or {}) do win[i] = tonumber(w) or 1 end
	add_node({ text = r.text, t = r.t, win = win, dmg = r.dmg, d = r.d, jug = r.jug or 1 })
end
for _, tk in ipairs(TOKS) do
	if tk.kind ~= "normal" and not known[tk.tok] then add_node({ text = tk.tok, t = { 0 }, win = { 1 }, dmg = 25, d = 50, jug = 0, single = true }) end
end
table.sort(queue, function(a, b) return (a.jug or 0) > (b.jug or 0) or ((a.jug or 0) == (b.jug or 0) and a.dmg > b.dmg) end)

-- ---------------------------------------------------------------- máquina de estados
local function to_joy(fr, fwd_key)
	local j = {}
	if not fr then return j end
	if fr.up then j["P2 Up"] = true end
	if fr.down then j["P2 Down"] = true end
	if fr.fwd then j[fwd_key] = true end
	if fr.back then j[fwd_key == "P2 Left" and "P2 Right" or "P2 Left"] = true end
	for b, n in pairs(NAMES) do if fr[b] then j["P2 " .. n] = true end end
	return j
end

local st = { mode = "next" }
local node, phase, fwd_key, SAVE, HPF
local function over() return os.time() - T0 >= BUDGET end

-- arma la lista de pruebas de la fase actual del nodo
local function make_jobs()
	local last = node.steps[#node.steps]
	local tl = node.t[#node.t]
	local jobs = {}
	for _, tk in ipairs(TOKS) do
		local sep = (phase == "cancel") and " xx " or ", "
		local text = node.text .. sep .. tk.tok
		local key = text
		local ok_kind = true
		if phase == "cancel" then
			-- cancel: normal -> especial / super; especial -> super (super cancel)
			ok_kind = (last.normal and tk.kind ~= "normal") or (not last.normal and not last.super and tk.kind == "super")
		end
		if tk.kind == "super" and node.text:find("SA") and phase == "cancel" then ok_kind = false end
		if ok_kind and not tested[key] and not known[text] then
			local steps = parse(text)
			if steps then
				local ns = steps[#steps]
				local lo, hi
				if phase == "cancel" then
					local a, b = WC.window(ns, last)
					lo, hi = tl + a, tl + b
				else
					lo = math.max(node.F + ns.press - 1, node.A - 3)
					hi = node.E + 1
				end
				if hi >= lo then jobs[#jobs + 1] = { text = text, steps = steps, lo = lo, hi = hi, tok = tk.tok } end
			end
		end
	end
	return jobs
end

local job, cands, ci, succ
local function next_cand()
	ci = ci + 1
	if ci > #cands then
		-- fino: vecinos de los éxitos gruesos
		if not job.refined and #succ > 0 then
			job.refined = true
			local have = {}
			for _, c in ipairs(cands) do have[c] = true end
			for _, s in ipairs(succ) do
				for _, x in ipairs({ s.t - 1, s.t + 1 }) do
					if not have[x] and x >= job.lo and x <= job.hi then cands[#cands + 1] = x have[x] = true end
				end
			end
			if ci <= #cands then return cands[ci] end
		end
		return nil
	end
	return cands[ci]
end

local function finish_job()
	tested[job.text] = true
	if #succ > 0 then
		local top = 0
		for _, s in ipairs(succ) do top = math.max(top, s.dmg) end
		local good = {}
		for _, s in ipairs(succ) do if s.dmg >= top - 2 then good[#good + 1] = s.t end end
		table.sort(good)
		-- centro del tramo contiguo más largo (paso 1 tras el refinado)
		local ba, bb, a = good[1], good[1], good[1]
		for i = 2, #good + 1 do
			if i > #good or good[i] - good[i - 1] > 2 then
				if good[i - 1] - a > bb - ba then ba, bb = a, good[i - 1] end
				a = good[i]
			end
		end
		local t = math.floor((ba + bb) / 2)
		local hits = 0
		for _, s in ipairs(succ) do if s.t == t or hits == 0 then hits = math.max(hits, s.peak) end end
		local ts, win = {}, {}
		for i, x in ipairs(node.t) do ts[i] = x end
		for i, x in ipairs(node.win) do win[i] = x end
		ts[#ts + 1], win[#win + 1] = t, bb - ba + 1
		local r = { text = job.text, d = node.d, dmg = top, hits = hits, t = ts, win = win, jug = (node.jug or 0) + 1 }
		results[#results + 1] = r
		known[job.text] = true
		L("OK   %-70s dmg=%d (+%d) t=%d win=%d", job.text, top, top - node.dmg, t, bb - ba + 1)
		local n2 = { text = r.text, t = ts, win = win, dmg = top, d = node.d, jug = r.jug }
		add_node(n2)
		table.sort(queue, function(a, b) return (a.jug or 0) > (b.jug or 0) or ((a.jug or 0) == (b.jug or 0) and a.dmg > b.dmg) end)
	end
	save()
end

local jobs, ji
local function start_job()
	ji = ji + 1
	job = jobs[ji]
	if not job then return false end
	cands, succ, ci = {}, {}, 0
	for x = job.lo, job.hi, 2 do cands[#cands + 1] = x end
	return true
end

H.to_match({ p1 = DUMMY, p2 = CHAR, sa1 = 1, sa2 = SA }, function()
	if emu.speedmode then
		if not pcall(emu.speedmode, "maximum") then pcall(emu.speedmode, "turbo") end
	end
	L("char=%s sa=%d nodos=%d extensiones=%d presupuesto=%ds", CHAR, SA, #queue, #TOKS, BUDGET)
	emu.registerbefore(function()
		wb(0x02011377, 99)
		local s = S.read()
		if st.mode == "next" then
			if over() or #queue == 0 then
				save()
				L("FIN %d juggles nuevos/total, %ds, cola %d", #results, os.time() - T0, #queue)
				logf:close()
				os.exit(0)
			end
			node = table.remove(queue, 1)
			st = { mode = "place", f = 0, tries = 0 }
			return
		end
		if st.mode == "place" then
			st.f = st.f + 1
			local me, op = s.p[2], s.p[1]
			local side = (me.x >= op.x) and 1 or -1
			HPF = HPF or { rb(P1B + 0x9F), rb(P2B + 0x9F) }
			wb(P1B + 0x9F, HPF[1]) wb(P2B + 0x9F, HPF[2])
			if st.f <= 30 then
				if CORNER then
					-- pared REAL del escenario para el muñeco (state.world: límite + offset del personaje)
					local wl = math.floor(op.wall_l or 125)
					memory.writeword(P1B + 0x64, wl)
					memory.writeword(P2B + 0x64, wl + node.d)
				else
					memory.writeword(P1B + 0x64, math.floor(512 - side * node.d / 2))
					memory.writeword(P2B + 0x64, math.floor(512 + side * node.d / 2))
				end
			end
			fwd_key = (op.x < me.x) and "P2 Left" or "P2 Right"
			local j = {}
			if st.f <= 25 then j[fwd_key == "P2 Left" and "P2 Right" or "P2 Left"] = true end
			joypad.set(j)
			if st.f >= 50 and math.abs(s.dist - node.d) > 4 and not (node.d < 58 and s.dist < 58) then
				st.f, st.tries = 0, st.tries + 1
				if st.tries > 6 then L("ERROR ubicación %s", node.text) st = { mode = "next" } end
				return
			end
			if st.f >= 50 and me.move and NEUTRAL[me.move] and op.move and NEUTRAL[op.move] then
				SAVE = savestate.create(SLOT)
				savestate.save(SAVE)
				savestate.load(SAVE)
				wb(P2_STOCK, rb(P2_MAXCOUNT))
				joypad.set({})
				node.plan = WC.build(node.steps, #node.steps, node.t)
				st = { mode = "probe", fr = -1, hp0 = rb(P1B + 0x9F), hpmin = 999, peak = 0, snapF = node.snapF }
			end
			return
		end
		if st.mode == "probe" then
			-- corre el prefijo con sus tiempos: daño base, cuándo P2 puede actuar (A), cuándo el rival toca el piso / se
			-- corta el contador (E). Con snapF guarda el savestate de los ensayos en ese frame
			st.fr = st.fr + 1
			local fr = st.fr
			if st.snapF and fr == st.snapF then savestate.save(SAVE) node.snap_hp, node.snap_peak = st.hp0, st.peak end
			joypad.set(to_joy(node.plan[fr], fwd_key))
			local tl = node.t[#node.t]
			local c = rb(P2_COMBO)
			if c > st.peak then st.peak = c end
			local hp = rb(P1B + 0x9F)
			if hp < st.hpmin and hp ~= 255 then st.hpmin, st.hp_at = hp, fr end
			local me, op = s.p[2], s.p[1]
			if fr > tl + 2 and not st.A and me.move and NEUTRAL[me.move] then st.A = fr end
			if fr > tl and op.y > 4 then st.air = true end
			if fr > tl and st.air and op.y <= 0 and not st.land then st.land = fr end
			if fr > tl and st.peak > 0 and c == 0 and not st.drop then st.drop = fr end
			local endf = st.land or st.drop
			-- base = daño TOTAL del prefijo: esperar a que la vida deje de bajar 30f (los golpes del último paso siguen
			-- entrando después de A/E; con la base corta, cualquier paso "sumaba" +2..+12 falsos)
			if (st.A and endf and fr > math.max(st.A, endf) + 2 and fr - (st.hp_at or 0) > 30) or fr > tl + 300 then
				local dmg = st.hp0 - ((st.hpmin == 999) and st.hp0 or st.hpmin)
				if not st.snapF then
					node.dmg = math.max(node.single and 0 or node.dmg, dmg)
					node.base = dmg
					node.A = st.A or (tl + 300)
					node.E = math.min(st.land or 9999, st.drop or 9999)
					if node.E == 9999 then node.E = tl + 120 end
					if dmg <= 0 or st.peak == 0 then
						L("SKIP %-60s no conecta (dmg=%d)", node.text, dmg)
						st = { mode = "next" }
						return
					end
					L("node %-60s dmg=%d A=%d E=%d air=%s jug=%d", node.text, dmg, node.A, node.E, tostring(st.air), node.jug or 0)
					-- fases: cancel (savestate en el último input del prefijo) y link (si el rival sigue en el aire / en
					-- hitstun cuando P2 ya puede actuar)
					node.phases = {}
					node.done_ph = node.done_ph or {}
					local last = node.steps[#node.steps]
					-- cancel: super cancel de un especial, o normal xx especial solo en nodos de juggle (los de la base ya
					-- los cubrió el lab de la wiki)
					local can_c = not last.super and (not last.normal or (node.jug or 0) > 0)
					if can_c and not node.done_ph.cancel then node.phases[#node.phases + 1] = "cancel" end
					if node.E >= node.A - 4 and not node.done_ph.link then node.phases[#node.phases + 1] = "link" end
					st = { mode = "phase" }
				else
					st = { mode = "jobs" }
				end
				return
			end
			return
		end
		if st.mode == "phase" then
			phase = table.remove(node.phases, 1)
			if not phase or over() then st = { mode = "next" } return end
			node.done_ph[phase] = true
			local tl = node.t[#node.t]
			node.F = (phase == "cancel") and math.max(0, tl - 1) or math.max(tl + 1, node.A - 12)
			jobs, ji = make_jobs(), 0
			if #jobs == 0 then return end
			-- segunda corrida del prefijo para guardar el savestate en F
			savestate.load(SAVE)
			wb(P2_STOCK, rb(P2_MAXCOUNT))
			joypad.set({})
			st = { mode = "probe", fr = -1, hp0 = rb(P1B + 0x9F), hpmin = 999, peak = 0, snapF = node.F }
			-- el SAVE ahora se pisa en F: la base se recupera re-ubicando (siguiente nodo)
			return
		end
		if st.mode == "jobs" then
			if over() then save() st = { mode = "next" } return end
			if not start_job() then st = { mode = "phase_end" } return end
			st = { mode = "trial_start" }
		end
		if st.mode == "phase_end" then
			-- la fase siguiente necesita otro savestate: re-ubicar el nodo
			if #node.phases > 0 then table.insert(queue, 1, node) end
			st = { mode = "next" }
			return
		end
		if st.mode == "trial_start" then
			local t = next_cand()
			if not t then finish_job() st = { mode = "jobs" } return end
			savestate.load(SAVE)
			local tt = {}
			for i, x in ipairs(node.t) do tt[i] = x end
			tt[#tt + 1] = t
			local plan = WC.build(job.steps, #job.steps, tt)
			local F = node.F
			joypad.set(to_joy(plan[F], fwd_key))
			st = { mode = "trial", fr = F, t = t, plan = plan, hp0 = nil, hpmin = 999, peak = node.snap_peak or 0,
				cap = t + (job.steps[#job.steps].super and 260 or 120) }
			return
		end
		if st.mode == "trial" then
			st.fr = st.fr + 1
			local fr = st.fr
			joypad.set(to_joy(st.plan[fr], fwd_key))
			local c = rb(P2_COMBO)
			local hp = rb(P1B + 0x9F)
			if hp < st.hpmin and hp ~= 255 then st.hpmin = hp end
			if c > st.peak then st.peak = c end
			local press0 = st.t - (job.steps[#job.steps].press - 1)
			-- el rival ya se recuperó antes del input nuevo: este t y todos los siguientes fallan (link)
			if phase == "link" and fr < press0 and st.peak > 0 and c == 0 then
				ci = #cands + 1
				job.refined = true
				st = { mode = "trial_start" }
				return
			end
			if fr == press0 then st.peak_p, st.hp_p = st.peak, hp end
			if st.peak >= 1 and c == 0 and not st.dropped then st.dropped, st.drop_fr = true, fr end
			if st.dropped and c > 0 then st.broke = true end
			local hp0 = HPF[1]
			local dmg_now = hp0 - ((st.hpmin == 999) and hp0 or st.hpmin)
			local done = st.broke or fr >= st.cap or (st.dropped and fr > st.t + 3 and fr - st.drop_fr > 30)
				or (fr > st.t + 80 and dmg_now <= node.base + 1)
				-- el paso nuevo no pegó nada en 45f (ni golpe ni daño; los agarres de super hacen daño tarde: 260f)
				or (st.peak_p and fr > st.t + 45 and st.peak <= st.peak_p and hp >= st.hp_p and not job.steps[#job.steps].super)
			if not done then return end
			if not st.broke and dmg_now >= node.base + 3 then succ[#succ + 1] = { t = st.t, dmg = dmg_now, peak = st.peak } end
			st = { mode = "trial_start" }
			return
		end
	end)
end)
