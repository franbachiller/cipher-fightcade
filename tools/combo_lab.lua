-- Laboratorio de combos v3: fuerza bruta verificada con savestates (slot numerado; el anónimo crashea fcadefbneo).
-- P2 = personaje a estudiar, P1 = muñeco. Starter (normal) x seguimiento (especial/super/normal) x frame t.
-- Optimizaciones:
--   * pool de workers: cada emulador reclama starters con un claim atómico (os.rename) y se cierra al terminar
--   * speedmode máximo, corte temprano por el contador de combo
--   * ventanas de t acotadas con la medición del starter solo (hitstun rival / frame accionable propio)
--   * poda de variantes: por especial se prueban completas la primera y la EX; las intermedias solo cerca de su ventana
-- Env: CIPHER_ROOT, CIPHER_LAB_CHAR, CIPHER_LAB_DIST, CIPHER_LAB_DUMMY, CIPHER_LAB_SA, CIPHER_LAB_WORKER (id)
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
package.path = ROOT .. "?.lua;" .. package.path
input_lib = require("core.input")
local H = dofile(ROOT .. "tools\\harness.lua")
local S = require("games.sfiii3.state")
local auto = require("games.sfiii3.chars.auto")

local CHAR = os.getenv("CIPHER_LAB_CHAR") or "ken"
local DIST = tonumber(os.getenv("CIPHER_LAB_DIST") or "60")
local DUMMY = os.getenv("CIPHER_LAB_DUMMY") or "ryu"
local SA = tonumber(os.getenv("CIPHER_LAB_SA") or "3")
local WORKER = os.getenv("CIPHER_LAB_WORKER") or "0"
local LEVEL = tonumber(os.getenv("CIPHER_LAB_LEVEL") or "1")   -- 1: normales; N: prefijos de N-1 golpes (links verificados)
local SLOT = 9
local LV = (LEVEL > 1) and ("_L" .. LEVEL) or ""
if (os.getenv("CIPHER_LAB_MODE") or "") == "chain" then LV = LV .. "_chain" end
local TAG = string.format("%s_d%d%s_s%s", CHAR, DIST, LV, WORKER)
local CLAIMS = ROOT .. "data\\sfiii3\\combos\\claims\\" .. CHAR .. "_d" .. DIST .. LV .. "\\"
os.execute('mkdir "' .. CLAIMS .. '" 2>nul')
os.execute('mkdir "' .. ROOT .. 'data\\sfiii3\\combos\\parts" 2>nul')
local OUT = ROOT .. "data\\sfiii3\\combos\\parts\\" .. TAG .. ".lua"
local logf = io.open(ROOT .. "logs\\combo_lab_" .. TAG .. ".log", "w")
local function L(...) logf:write(string.format(...) .. "\n") logf:flush() end

local rb, wb = memory.readbyte, memory.writebyte
local P1 = S.P[1]
local P2_COMBO = 0x0206961D
local P2_STOCK, P2_MAXCOUNT, P2_GAUGE = 0x020695EB, 0x020695E9, 0x020695E1
local NEUTRAL = { standing = true, crouching = true, standing_begin = true, crouching_begin = true,
	standing_turn = true, crouching_turn = true, walk_forward = true, walk_back = true, walk_transition = true }
local NAMES = { lp = "Weak Punch", mp = "Medium Punch", hp = "Strong Punch", lk = "Weak Kick", mk = "Medium Kick", hk = "Strong Kick" }

-- ---------------------------------------------------------------- catálogo
local moves = dofile(ROOT .. "data\\sfiii3\\moves\\" .. CHAR .. ".lua")
local normals, by_name, seen = {}, {}, {}
for _, n in ipairs(auto(CHAR).normals) do
	local f = { [n.btn] = true }
	for k, v in pairs(n.dirs) do f[k] = v end
	by_name[n.name] = by_name[n.name] or f
	local key = n.btn .. (n.dirs.down and "d" or "") .. (n.dirs.fwd and "f" or "") .. (n.dirs.back and "b" or "")
	if not seen[key] then
		seen[key] = true
		normals[#normals + 1] = { name = n.name, frame = f }
	end
end

-- starter = cadena de normales con sus offsets de input (pt) relativos al primero
local function make_starter(chain, pt)
	local plan = {}
	for i, nm in ipairs(chain) do plan[pt[i]] = by_name[nm] plan[pt[i] + 1] = by_name[nm] end
	return { name = table.concat(chain, ">"), chain = chain, pt = pt, plan = plan, last = pt[#pt], hits = #chain }
end

-- t preferido de una ventana: mitad del tramo contiguo más largo
local function t_pref(ts)
	table.sort(ts)
	local ba, bb, a = ts[1], ts[1], ts[1]
	for i = 2, #ts + 1 do
		if i > #ts or ts[i] ~= ts[i - 1] + 1 then
			if ts[i - 1] - a > bb - ba then ba, bb = a, ts[i - 1] end
			a = ts[i]
		end
	end
	return math.floor((ba + bb) / 2)
end

local starters = {}
if LEVEL == 1 then
	for _, n in ipairs(normals) do starters[#starters + 1] = make_starter({ n.name }, { 0 }) end
else
	-- prefijos: links verificados del nivel anterior (starter compuesto + normal enlazado)
	local prev = ROOT .. "data\\sfiii3\\combos\\" .. CHAR .. "_d" .. DIST .. ((LEVEL > 2) and ("_L" .. (LEVEL - 1)) or "") .. ".lua"
	-- prefijos desde links y chains del nivel anterior; sin duplicados (mismo botón y misma ventana = mismo golpe)
	local list = {}
	for _, path in ipairs({ prev, (prev:gsub("%.lua$", "_chain.lua")) }) do
		local ok, l = pcall(dofile, path)
		for _, e in ipairs(ok and type(l) == "table" and l or {}) do list[#list + 1] = e end
	end
	local dedup, sig = {}, {}
	for _, e in ipairs(list) do
		local fb = by_name[e.follow]
		local key = fb and (e.starter .. "|" .. (fb.lp and "lp" or fb.mp and "mp" or fb.hp and "hp" or fb.lk and "lk" or fb.mk and "mk" or "hk")
			.. "|" .. table.concat(e.t, ","))
		if key and sig[key] then e.kind = "dup" elseif key then sig[key] = true end
	end
	for _, e in ipairs(list) do
		if (e.kind == "link" or e.kind == "chain") and by_name[e.follow] then
			local chain, pt = {}, {}
			for nm in e.starter:gmatch("[^>]+") do chain[#chain + 1] = nm end
			if e.pt then for i, x in ipairs(e.pt) do pt[i] = x end else pt[1] = 0 end
			chain[#chain + 1] = e.follow
			pt[#pt + 1] = t_pref(e.t)
			local st = make_starter(chain, pt)
			if not dedup[st.name] then dedup[st.name] = true starters[#starters + 1] = st end
		end
	end
end
-- solo algunos starters (re-ensayo dirigido): CIPHER_LAB_ONLY="d_HP,b_MK"
local ONLY = os.getenv("CIPHER_LAB_ONLY")
if ONLY and ONLY ~= "" then
	local keep, want = {}, {}
	for nm in ONLY:gmatch("[^,]+") do want[nm] = true end
	for _, st in ipairs(starters) do if want[st.name] or want[st.chain[1]] then keep[#keep + 1] = st end end
	starters = keep
end
for i, st in ipairs(starters) do st.idx = i end

-- golpes por normal (algunos pegan 2-3 veces): se miden al arrancar; el objetivo de cada ensayo es la suma real
local HC = {}
local function exp_hits(chain) local n = 0 for _, nm in ipairs(chain) do n = n + (HC[nm] or 1) end return n end

-- seguimientos: por especial, primero los representantes (primera y última variante), después las intermedias
local follows = {}
for _, m in ipairs(moves) do
	if m.type == "special" or m.type == "sa" .. SA then
		local nv = #m.variants
		local order = { 1 }
		if nv > 1 then order[#order + 1] = nv end
		for vi = 2, nv - 1 do order[#order + 1] = vi end
		for _, vi in ipairs(order) do
			local v = m.variants[vi]
			if not v.charge then follows[#follows + 1] = { name = m.name .. (v.btn ~= "" and ("_" .. v.btn) or ""), seq = v.seq, kind = m.type,
				group = m.name, rep = (vi == 1 or vi == nv) } end
		end
	end
end
local MODE = os.getenv("CIPHER_LAB_MODE") or ""      -- "chain": solo normal -> normal en la zona de cancel temprana
if MODE == "chain" then follows = {} end
local NOLINKS = os.getenv("CIPHER_LAB_NOLINKS") == "1" -- solo cierres con especial/super
if not NOLINKS then for _, n in ipairs(normals) do
	follows[#follows + 1] = { name = n.name, seq = { n.frame }, kind = (MODE == "chain") and "chain" or "link" }
end end
L("char=%s dist=%d level=%d worker=%s starters=%d follows=%d", CHAR, DIST, LEVEL, WORKER, #starters, #follows)

-- claim atómico: rename de un temporal propio al nombre del starter (os.rename falla si ya existe)
local function claim(st)
	local tmp = CLAIMS .. "tmp_" .. WORKER .. "_" .. st.idx
	local f = io.open(tmp, "w")
	if not f then return false end
	f:write(WORKER) f:close()
	local ok = os.rename(tmp, CLAIMS .. string.format("%03d", st.idx))
	if not ok then os.remove(tmp) end
	return ok and true or false
end

-- ---------------------------------------------------------------- estado
local results, solo = {}, {}
local state, fwd_key, SAVE, SNAP = "position", nil, nil, nil
local cur              -- starter actual
local fi, tlist, ti
local trial
local stats = { trials = 0, frames = 0, starters = 0 }

local function to_joy(fr)
	local j = {}
	if not fr then return j end
	if fr.up then j["P2 Up"] = true end
	if fr.down then j["P2 Down"] = true end
	if fr.fwd then j[fwd_key] = true end
	if fr.back then j[fwd_key == "P2 Left" and "P2 Right" or "P2 Left"] = true end
	for b, n in pairs(NAMES) do if fr[b] then j["P2 " .. n] = true end end
	return j
end

local function begin_trial(follow, tt, need_dmg)
	savestate.load(SAVE)
	wb(P2_STOCK, rb(P2_MAXCOUNT)) wb(P2_GAUGE, 0)
	local plan = {}
	for k, v in pairs(cur.plan) do plan[k] = v end
	if follow then
		local n = #follow.seq
		for i, fr in ipairs(follow.seq) do
			local at = tt - (n - i)
			if at >= 0 then
				-- combinar con lo que ya haya en ese frame (motion encima del último normal del prefijo)
				local m = {} for k, v in pairs(plan[at] or {}) do m[k] = v end for k, v in pairs(fr) do m[k] = v end plan[at] = m
			end
		end
		if follow.kind == "link" or follow.kind == "chain" then plan[tt + 1] = follow.seq[1] end
	end
	local cap = ((follow and follow.kind:match("^sa")) and 170 or 90) + cur.last
	trial = { frame = 0, plan = plan, cap = cap + (tt or 0), peak = 0, hp0 = SNAP.p1hp, hpmin = 999,
		t = tt, need_dmg = need_dmg, reloads = 0, broke = false,
		target = follow and (cur.exp + ((follow.kind == "link" or follow.kind == "chain") and (HC[follow.name] or 1) or 1)) or cur.exp }
	stats.trials = stats.trials + 1
	joypad.set({})   -- el input del ensayo anterior no debe caer en el primer frame de este
end

local function dmg_of(tr) return tr.hp0 - ((tr.hpmin == 255 or tr.hpmin == 999) and 0 or tr.hpmin) end

local function save_results()
	local f = io.open(OUT, "w")
	f:write("return {\n")
	for sname, fl in pairs(results) do
		for fname, r in pairs(fl) do
			if #r.ok > 0 then
				f:write(string.format("  { starter = %q, follow = %q, kind = %q, t = {%s}, dmg = %d, solo = %d, adv = %d, pt = {%s} },\n",
					sname, fname, r.kind, table.concat(r.ok, ","), r.dmg, r.solo or 0, r.adv or 0, table.concat(r.pt or { 0 }, ",")))
			end
		end
	end
	f:write("}\n")
	f:close()
end

local function t_window(fo)
	local so = solo[cur.name]
	local hs = so.hs_end or 30
	local list = {}
	if fo.kind == "chain" then
		-- chain: el siguiente normal se aprieta durante el anterior (búsqueda gruesa + vecinos)
		local lo, hi = cur.last + 2, math.min(hs, cur.last + 16)
		for x = lo, hi, 2 do list[#list + 1] = x end
		list.coarse = { lo = lo, hi = hi }
	elseif fo.kind == "link" then
		for x = math.max(cur.last + 4, (so.act or hs) - 3), hs + 1 do list[#list + 1] = x end
	else
		local lim = math.min(hs, cur.last + 26)
		if fo.rep then
			-- búsqueda gruesa: cada 2 frames; los vecinos de cada éxito se completan dinámicamente (coarse)
			for x = cur.last + 1, lim, 2 do list[#list + 1] = x end
			list.coarse = { lo = cur.last + 1, hi = lim }
		else
			local lo, hi
			for _, f2 in ipairs(follows) do
				if f2.group == fo.group and f2.rep then
					local r2 = results[cur.name][f2.name]
					for _, x in ipairs(r2 and r2.ok or {}) do lo = math.min(lo or x, x) hi = math.max(hi or x, x) end
				end
			end
			if lo then for x = math.max(cur.last + 1, lo - 3), math.min(lim, hi + 3) do list[#list + 1] = x end end
		end
	end
	return list
end

local function finish()
	save_results()
	state = "done"
	local el = os.clock() - stats.t0
	L("DONE starters=%d trials=%d frames=%d reloads=%d en %.0fs (%.0f fps)", stats.starters, stats.trials, stats.frames,
		stats.reloads or 0, el, stats.frames / math.max(0.001, el))
	logf:close()
	os.exit(0)
end

-- reclamar el próximo starter libre y arrancar su ensayo solo
local function next_starter()
	for _, st in ipairs(starters) do
		if not st.tried then
			st.tried = true
			if claim(st) then
				cur = st
				stats.starters = stats.starters + 1
				state = "solo"
				begin_trial(nil, 0, true)
				return true
			end
		end
	end
	finish()
	return false
end

local function next_follow()
	while true do
		fi = fi + 1
		if fi > #follows then
			save_results()
			L("starter %s listo (%.0fs)", cur.name, os.clock() - stats.t0)
			return next_starter() and false
		end
		tlist = t_window(follows[fi])
		if #tlist > 0 then ti = 1 return true end
	end
end

H.to_match({ p1 = DUMMY, p2 = CHAR, sa1 = 1, sa2 = SA }, function()
	if emu.speedmode then
		if not pcall(emu.speedmode, "maximum") then pcall(emu.speedmode, "turbo") end
	end
	stats.t0 = os.clock()
	emu.registerbefore(function()
		if state == "done" then return end
		wb(0x02011377, 99)
		if state == "position" then
			local s = S.read()
			local me, op = s.p[2], s.p[1]
			fwd_key = (op.x < me.x) and "P2 Left" or "P2 Right"
			if s.dist > DIST then joypad.set({ [fwd_key] = true }) return end
			state, trial = "settle", { frame = 0 }
			return
		elseif state == "settle" then
			trial.frame = trial.frame + 1
			if trial.frame >= 25 then
				SAVE = savestate.create(SLOT)
				savestate.save(SAVE)
				SNAP = { p1hp = rb(P1.base + 0x9F), p1x = memory.readwordsigned(P1.base + 0x64),
					p2x = memory.readwordsigned(S.P[2].base + 0x64) }
				-- verificar el guardado: dejar correr unos frames con un input que mueva a P2, cargar y comparar
				state, trial = "verify", { frame = 0 }
			end
			return
		elseif state == "verify" then
			trial.frame = trial.frame + 1
			if trial.frame <= 6 then joypad.set({ [fwd_key == "P2 Left" and "P2 Right" or "P2 Left"] = true }) return end
			if trial.frame == 7 then savestate.load(SAVE) joypad.set({}) return end
			local ok = rb(P2_COMBO) == 0 and rb(P1.base + 0x9F) == SNAP.p1hp
				and math.abs(memory.readwordsigned(P1.base + 0x64) - SNAP.p1x) <= 2
				and math.abs(memory.readwordsigned(S.P[2].base + 0x64) - SNAP.p2x) <= 2
			if not ok then
				SLOT = (SLOT <= 3) and 9 or (SLOT - 1)
				L("guardado inválido: re-guardando en slot %d", SLOT)
				state, trial = "settle", { frame = 0 }
				return
			end
			L("guardado verificado (slot %d)", SLOT)
			do
				state, PROBE_I = "probe", 1
				cur = make_starter({ normals[1].name }, { 0 }) cur.exp = 1
				begin_trial(nil, 0, true)
			end
			return
		end

		-- ---- ensayo en curso
		stats.frames = stats.frames + 1
		if trial.hold == "neutral" then
			trial.hold_n = trial.hold_n + 1
			joypad.set({})
			local sr = S.read()
			local calm = sr.p[1].move and NEUTRAL[sr.p[1].move] and sr.p[2].move and NEUTRAL[sr.p[2].move]
			if (calm and trial.hold_n >= 2) or trial.hold_n > 200 then trial.hold = 1 end
			return
		end
		if trial.hold and trial.hold > 0 then
			trial.hold = trial.hold - 1
			joypad.set({})
			if trial.hold == 0 then
				savestate.load(SAVE)
				wb(P2_STOCK, rb(P2_MAXCOUNT)) wb(P2_GAUGE, 0)
				joypad.set({})
			end
			return
		end
		trial.frame = trial.frame + 1
		-- validación de la carga: el primer frame tiene que ser el estado guardado (sin restos del ensayo anterior,
		-- p.ej. después de un super: "cl_LP solo" con peak=4 y 17 de daño)
		if trial.frame == 1 then
			local bad = rb(P2_COMBO) ~= 0 or rb(P1.base + 0x9F) ~= SNAP.p1hp
				or math.abs(memory.readwordsigned(P1.base + 0x64) - SNAP.p1x) > 2
				or math.abs(memory.readwordsigned(S.P[2].base + 0x64) - SNAP.p2x) > 2
			if bad then
				stats.reloads = (stats.reloads or 0) + 1
				trial.reloads = trial.reloads + 1
				if (stats.reloads or 0) <= 12 or trial.reloads == 60 then
					L("BADLOAD #%d (intento %d) combo=%d hp=%d p1x=%d p2x=%d | snap hp=%d p1x=%d p2x=%d | P2 move=%s fz=%d sf=%d",
						stats.reloads, trial.reloads, rb(P2_COMBO), rb(P1.base + 0x9F), memory.readwordsigned(P1.base + 0x64),
						memory.readwordsigned(S.P[2].base + 0x64), SNAP.p1hp, SNAP.p1x, SNAP.p2x,
						tostring(S.read().p[2].move), rb(S.P[2].base + 0x45), rb(0x02069088))
				end
				-- la carga no "agarra" en ciertos estados (rival derribado/lanzado): en vez de recargar cada frame
				-- (carísimo, workers trabados), dejar correr unos frames baratos y reintentar.
				-- CIPHER_LAB_FASTRELOAD=1: recargar cada frame (Oro solo se recupera así)
				-- cambio automático: si un ensayo ya agotó los reintentos espaciados, el worker pasa a recargar cada frame
				local fast = os.getenv("CIPHER_LAB_FASTRELOAD") == "1" or stats.fast
				if not fast and trial.reloads > 40 then
					stats.fast = true
					trial.reloads = 0
					L("carga: paso a recargar cada frame (estrategia rápida no agarra con %s)", CHAR)
					fast = true
				end
				if trial.reloads > (fast and 240 or 40) then L("ERROR: carga inválida repetida en %s", cur.name) trial.cap = 0
				else
					-- esperar a que ambos estén en neutral (la carga no agarra con el rival derribado/lanzado)
					trial.hold = fast and 1 or "neutral"
					trial.hold_n = 0
					trial.frame = 0
					joypad.set({})
					return
				end
			end
		end
		local fr = trial.frame - 1
		joypad.set(to_joy(trial.plan[fr]))
		local c = rb(P2_COMBO)
		if c > trial.peak then trial.peak = c end
		-- combo estricto: si el contador vuelve a 0 antes de llegar al objetivo, los golpes no formaron un combo
		if trial.peak >= 1 and c == 0 and trial.peak < trial.target then trial.broke = true end
		local hp = rb(P1.base + 0x9F)
		if hp < trial.hpmin then trial.hpmin = hp end

		local finished = trial.frame >= trial.cap
		if state == "solo" or state == "probe" then
			if not trial.act and fr > cur.last + 3 then
				local p2 = S.read().p[2]
				if p2.move and NEUTRAL[p2.move] then trial.act = fr end
			end
			if trial.peak >= cur.exp and c == 0 and not trial.hs_end then trial.hs_end = fr end
			if trial.act and trial.hs_end then finished = true end
		else
			if trial.broke then finished = true
			elseif trial.peak >= trial.target and not trial.need_dmg then finished = true
			elseif trial.peak >= 1 and c == 0 and fr > trial.t then finished = true end
		end
		if not finished then return end

		if state == "probe" then
			HC[cur.chain[1]] = math.max(1, trial.peak)
			PROBE_I = PROBE_I + 1
			if PROBE_I <= #normals then
				cur = make_starter({ normals[PROBE_I].name }, { 0 }) cur.exp = 1
				begin_trial(nil, 0, true)
				return
			end
			for _, st in ipairs(starters) do st.exp = exp_hits(st.chain) end
			local multi = {}
			for nm, h in pairs(HC) do if h > 1 then multi[#multi + 1] = nm .. "=" .. h end end
			L("hitcounts multi: %s", table.concat(multi, " "))
			next_starter()
			return
		end

		if state == "solo" then
			local okp = trial.peak >= cur.exp and not trial.broke
			solo[cur.name] = { hit = okp, dmg = dmg_of(trial), act = trial.act, hs_end = trial.hs_end }
			L("solo %-16s hit=%s peak=%d dmg=%d act=%s hs_end=%s", cur.name, tostring(okp), trial.peak, dmg_of(trial),
				tostring(trial.act), tostring(trial.hs_end))
			if not okp then next_starter() return end
			results[cur.name] = {}
			state, fi = "pairs", 0
			if not next_follow() then return end
			begin_trial(follows[fi], tlist[ti], true)
			return
		end

		-- pairs
		local fo = follows[fi]
		local r = results[cur.name][fo.name]
		if not r then
			local so = solo[cur.name]
			r = { ok = {}, dmg = 0, kind = fo.kind, solo = so.dmg, adv = (so.act and so.hs_end) and (so.hs_end - so.act) or 0, pt = cur.pt }
			results[cur.name][fo.name] = r
		end
		if trial.peak >= trial.target and not trial.broke then
			r.ok[#r.ok + 1] = trial.t
			if trial.need_dmg then r.dmg = math.max(r.dmg, dmg_of(trial)) r.measured = true end
			-- búsqueda gruesa: agregar los vecinos no probados del éxito
			local cz = tlist.coarse
			if cz then
				tlist.done = tlist.done or {}
				for _, x in ipairs(tlist) do tlist.done[x] = true end
				for _, nx in ipairs({ trial.t - 1, trial.t + 1 }) do
					if nx >= cz.lo and nx <= cz.hi and not tlist.done[nx] then tlist[#tlist + 1] = nx tlist.done[nx] = true end
				end
			end
		end
		ti = ti + 1
		if ti > #tlist then
			if #r.ok > 0 then L("COMBO %-16s > %-22s t=[%s] dmg=%d", cur.name, fo.name, table.concat(r.ok, ","), r.dmg) end
			if not next_follow() then return end
			r = results[cur.name][follows[fi].name]
		end
		begin_trial(follows[fi], tlist[ti], not (r and r.measured))
	end)
end)
