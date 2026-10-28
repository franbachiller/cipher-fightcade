-- Base de combos verificados (tools/combo_lab.lua, todos los niveles) -> secuencias de input exactas para el brain.
-- Entrada: { starter = "d_LK>d_LK", pt = {0,19}, follow = "shippu", kind = "sa3"|"special"|"link", t = {frames}, dmg, ... }
-- starter = cadena de normales; pt = frame de input de cada normal (desde el primero);
-- t = frame en que entra el último input del seguimiento (desde el primer normal).
local C = { cache = {}, MAX_DIST = 66 }
-- rival contra la pared (lo pone el brain cada frame): habilita los juggles verificados solo en la esquina
C.corner_now = false
local function pos_ok(e) return not e.corner or C.corner_now end

local ROOT = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])games[\\/]") or ".\\")

local function auto_normals(char)
	local ok, auto = pcall(require, "games.sfiii3.chars.auto")
	if not ok then return {} end
	local by = {}
	for _, n in ipairs(auto(char).normals or {}) do by[n.name] = by[n.name] or n end
	return by
end

local function normal_frame(n)
	local f = { [n.btn] = true }
	for k, v in pairs(n.dirs) do f[k] = v end
	return f
end

local function contiguous_mid(ts)
	local ba, bb, a = ts[1], ts[1], ts[1]
	for i = 2, #ts + 1 do
		if i > #ts or ts[i] ~= ts[i - 1] + 1 then
			if ts[i - 1] - a > bb - ba then ba, bb = a, ts[i - 1] end
			a = ts[i]
		end
	end
	return math.floor((ba + bb) / 2), ba, bb
end

function C.load(char)
	if C.cache[char] ~= nil then return C.cache[char] or nil end
	local okm, moves = pcall(dofile, ROOT .. "data\\sfiii3\\moves\\" .. char .. ".lua")
	if not okm then C.cache[char] = false return nil end
	local normals = auto_normals(char)
	local vseq = {}
	for _, m in ipairs(moves) do
		for _, v in ipairs(m.variants) do
			if not v.charge then vseq[m.name .. (v.btn ~= "" and ("_" .. v.btn) or "")] = v.seq end
		end
	end
	local db = { list = {}, by_starter = {} }
	local base = ROOT .. "data\\sfiii3\\combos\\" .. char .. "_d60"
	local files = { base .. ".lua", base .. "_chain.lua" }
	for lv = 2, 6 do
		files[#files + 1] = base .. "_L" .. lv .. ".lua"
		files[#files + 1] = base .. "_L" .. lv .. "_chain.lua"
	end
	for _, path in ipairs(files) do
		local ok, list = pcall(dofile, path)
		if not ok or type(list) ~= "table" then list = {} end   -- archivo ausente: seguir con el resto
		for _, e in ipairs(list) do
			local chain = {}
			for nm in e.starter:gmatch("[^>]+") do chain[#chain + 1] = nm end
			local okc = #chain > 0
			for _, nm in ipairs(chain) do if not normals[nm] then okc = false end end
			local fseq = (e.kind == "link" or e.kind == "chain") and (normals[e.follow] and { normal_frame(normals[e.follow]) }) or vseq[e.follow]
			if okc and fseq and #e.t > 0 then
				table.sort(e.t)
				e.chain = chain
				e.pt = e.pt or { 0 }
				e.hits = #chain + 1
				e.st = normals[chain[1]]
				e.fseq = fseq
				e.meter = (e.kind:match("^sa") or e.follow:match("_EX[PK]$")) and 1 or 0
				-- verificado a 60 px: más lejos los normales "cl_" salen como su versión lejana y el cierre puede quedar corto
				e.reach = math.min(e.st.reach + 26, C.MAX_DIST)
				e.startup = e.st.startup
				e.t_pref, e.t_lo, e.t_hi = contiguous_mid(e.t)
				e.label = table.concat(chain, " > ") .. " > " .. e.follow
				db.list[#db.list + 1] = e
				db.by_starter[chain[1]] = db.by_starter[chain[1]] or {}
				table.insert(db.by_starter[chain[1]], e)
			end
		end
	end
	-- combos de la wiki verificados en emulador (tools/wiki_combo_lab.lua): inputs exactos de la verificación.
	-- Los de carga (precarga de 60f) quedan afuera del castigo: el brain no llega cargado a un castigo de reacción.
	local WC = require("games.sfiii3.wiki_combo")
	for sa = 1, 3 do
		local okw, list = pcall(dofile, ROOT .. "data\\sfiii3\\combos\\wiki\\" .. char .. "_sa" .. sa .. "_ryu.lua")
		-- + los del extractor de rutas de la wiki (tools/extract_wiki_routes.py, lab con CIPHER_WCL_SET=auto)
		-- + los juggles encadenados (tools/juggle_lab.lua: extiende rutas verificadas paso a paso mientras sumen daño)
		for _, suf in ipairs({ "_auto", "_juggle", "_juggle_corner" }) do
			local oka, auto = pcall(dofile, ROOT .. "data\\sfiii3\\combos\\wiki\\" .. char .. "_sa" .. sa .. "_ryu" .. suf .. ".lua")
			if oka and type(auto) == "table" then
				if not (okw and type(list) == "table") then okw, list = true, {} end
				for _, r in ipairs(auto) do
					-- juggle con una ventana enorme (>60f) = no es un link real (el muñeco ya en el piso / ruido): afuera
					local noisy = false
					for _, w in ipairs(r.jug and r.win or {}) do if (tonumber(w) or 0) > 60 then noisy = true end end
					if not noisy then list[#list + 1] = r end
				end
			end
		end
		for _, r in ipairs(okw and type(list) == "table" and list or {}) do
			-- con precarga (Oro, Q, Remy, Urien): valen si el brain YA tiene la carga lista (se arranca desde `pre`)
			local steps = r.ok and WC.parse(r.text, moves, sa)
			if steps then
				local sup, ex, chg = false, false, nil
				-- barra: cada super y cada EX cuenta (los juggles largos pueden llevar 2 supers / EX + super)
				local nsup, nex = 0, 0
				for _, st in ipairs(steps) do
					sup = sup or st.super or false ex = ex or st.ex or false chg = chg or st.charge
					if st.super then nsup = nsup + 1 end
					if st.ex then nex = nex + 1 end
				end
				local n = steps[1].anim and normals[steps[1].anim]
				local e = {
					wiki = true, label = "wiki " .. r.text .. (r.corner and " (esquina)" or ""), dmg = r.dmg, hits = r.hits, follow = r.text,
					corner = r.corner or nil,
					kind = sup and ("sa" .. sa) or "special", meter = math.max((sup and 1 or 0) + (ex and 1 or 0), nsup + nex),
					seq_full = WC.seq(steps, r.t, r.pre or 0, CIPHER_EXT and true or nil), startup = n and n.startup or 9,
					pre = r.pre or 0, charge = (r.pre or 0) > 0 and chg or nil,
					-- distancia verificada: el close/far de los normales depende de ella
					reach = math.max(r.d, 52) + 6, min_d = (r.d >= 58) and (r.d - 14) or nil,
					-- hit-confirm: steps + tiempos + ancho de ventana medido de cada paso
					steps = steps, ts = r.t, win = r.win or {}, starter = steps[1].normal and steps[1].anim or nil,
				}
				db.list[#db.list + 1] = e
				if e.starter then
					db.by_starter[e.starter] = db.by_starter[e.starter] or {}
					table.insert(db.by_starter[e.starter], e)
				end
			end
		end
	end
	if #db.list == 0 then C.cache[char] = false return nil end
	table.sort(db.list, function(x, y) return x.dmg > y.dmg end)
	for _, l in pairs(db.by_starter) do table.sort(l, function(x, y) return x.dmg > y.dmg end) end
	C.cache[char] = db
	return db
end

-- línea de tiempo completa: offset -> frame de input
local function build(e, t, normals_by)
	local tl, last = {}, t + ((e.kind == "link" or e.kind == "chain") and 1 or 0)
	for i, nm in ipairs(e.chain) do
		local f = normal_frame(normals_by[nm])
		tl[e.pt[i]] = f
		tl[e.pt[i] + 1] = f
	end
	local n = #e.fseq
	for i, fr in ipairs(e.fseq) do
		local at = t - (n - i)
		local m = {}
		for k, v in pairs(tl[at] or {}) do m[k] = v end
		for k, v in pairs(fr) do m[k] = v end
		tl[at] = m
	end
	if e.kind == "link" or e.kind == "chain" then tl[t + 1] = e.fseq[1] end
	return tl, last
end

local normals_cache = {}
local function nby(char)
	normals_cache[char] = normals_cache[char] or auto_normals(char)
	return normals_cache[char]
end

-- secuencia completa desde el primer normal
function C.full_seq(e, t, char)
	if e.seq_full then
		local out = {}
		for i, f in ipairs(e.seq_full) do local c = {} for k, v in pairs(f) do c[k] = v end out[i] = c end
		return out
	end
	local tl, last = build(e, t or e.t_pref, nby(char or "ken"))
	local out = {}
	for i = 0, last do out[#out + 1] = tl[i] or {} end
	return out
end

-- continuación para hit-confirm: el primer normal ya salió hace `now` frames; con latencia `lat`.
-- Devuelve la secuencia desde ya, o nil si algún input posterior al primero ya no llega a tiempo.
-- hit-confirm de un combo de la wiki: el primer normal salió hace `now` frames. Si el siguiente input ya tendría que
-- haber salido, se corre el resto del combo más tarde dentro de la ventana medida del 2º paso (los tiempos relativos
-- entre pasos no cambian, así que todo lo verificado sigue valiendo).
local function wiki_follow(e, now, lat)
	local WC = require("games.sfiii3.wiki_combo")
	local start = (e.pre or 0) + now + (lat or 0)            -- con precarga, el primer normal está en el offset `pre`
	if #e.ts < 2 then return nil end
	local ts = {}
	for i, t in ipairs(e.ts) do ts[i] = t end
	local first2 = ts[2] - (e.steps[2].press - 1)                -- primer frame de input del 2º paso
	local shift = math.max(0, start - first2)
	local room = math.floor(((e.win[2] or 1) - 1) / 2)          -- ventana medida alrededor del centro
	if shift > room then return nil end
	-- online: usar la ventana medida para que entre el motion de 2 frames (sin lugar se comprime y vuelve a 1 frame)
	if CIPHER_EXT then shift = math.max(shift, math.min(room - 1, shift + #e.steps[2].frames - 1)) end
	for i = 2, #ts do ts[i] = ts[i] + shift end
	-- online: motions de 2 frames (wiki_combo.build), nunca antes de `start` (lo anterior ya salió)
	local full = WC.seq(e.steps, ts, 0, CIPHER_EXT and true or nil, start)
	local out = {}
	for i = start, #full - 1 do out[#out + 1] = full[i + 1] end
	return out, ts[#ts]
end

function C.follow_seq(e, now, lat, char)
	if e.wiki then return wiki_follow(e, now, lat) end
	local start = now + (lat or 0)
	local first_after = (#e.pt > 1) and e.pt[2] or nil
	if first_after and first_after < start then return nil end
	local t
	for _, x in ipairs(e.t) do
		if x - #e.fseq + 1 >= start then t = x break end
	end
	if not t then return nil end
	local tl, last = build(e, t, nby(char or "ken"))
	-- out[1] se envía ahora y entra en el offset `start`; los frames 0-1 (primer normal) ya salieron
	local out = {}
	for i = start, last do out[#out + 1] = (i > 1) and (tl[i] or {}) or {} end
	return out, t
end

-- el combo usa un super? solo vale si coincide con el SA elegido (leído de RAM)
function C.sa_ok(e, sa)
	local n = e.kind:match("^sa(%d)")
	return not n or not sa or tonumber(n) == sa
end

-- mejor combo para castigar: entra en `adv` frames, alcanza a `d`, barra suficiente
function C.best_punish(char, d, adv, meter, lat)
	local db = C.load(char)
	if not db then return nil end
	for _, e in ipairs(db.list) do
		if not e.charge and pos_ok(e) and e.meter <= meter and d <= e.reach and not (e.min_d and d < e.min_d)
			and e.startup + (lat or 0) + 1 <= adv then return e end
	end
	return nil
end

-- mejor continuación tras conectar `starter` (nombre de animación de la frame data)
-- op_hp: vida del rival. Entre los combos que SEGURO conectan (mismos filtros de distancia / ventana), si alguno lo
-- MATA se elige el que mata gastando menos barra. Antes con MAX hacía un combo que no lo mataba
function C.best_confirm(char, starter, meter, now, lat, d, sa, chg, proj_super, op_hp)
	local db = C.load(char)
	local l = db and db.by_starter[starter]
	if not l then return nil end
	local kill_e, kill_seq, kill_t, best_e, best_seq, best_t
	for _, e in ipairs(l) do
		-- distancia: los del lab viejo valen hasta ~76 px; los de la wiki, en la distancia en que se verificaron
		local d_ok = not d or (e.wiki and d <= e.reach + 10 and not (e.min_d and d < e.min_d))
			or (not e.wiki and d <= C.MAX_DIST + 10)
		-- normal xx super de proyectil (X.N.D.L., Shinkuu Hadouken...): el normal ya conectó y el super viaja, así que
		-- vale a cualquier distancia del normal (Twelve: st.MP xx SA solo se usaba a 46-66 px y st.MP pega a 90-174)
		if proj_super and e.wiki and e.follow and e.follow:match("^%S+ xx SA$") and d and d <= 250 then d_ok = true end
		-- confirm que termina en super cuerpo a cuerpo (Shin Shoryuken): sin la tolerancia de +10 px. Online el super
		-- salía a 103-109 px tras el empuje del golpe y erraba entero (la barra regalada)
		-- (+6: el empuje del golpe que confirma deja apenas más lejos; sin margen Alex nunca confirmaba Boomerang Raid
		-- tras cl.MK y usaba EX Chop. El error de Ryu era a +45 px)
		local kills = op_hp and e.dmg >= op_hp
		-- (online 9 Shin Shoryuken / Goshoryuken al aire tras 2MK a 69-78 px: el empuje del golpe lo saca del alcance.
		-- Ahora hasta la distancia verificada + 4)
		if d and e.wiki and e.kind:match("^sa") and not proj_super and d > e.reach - 2 then d_ok = false end
		local c_ok = not e.charge or (chg and chg[e.charge])
		if d_ok and c_ok and pos_ok(e) and e.meter <= meter and C.sa_ok(e, sa) then
			local seq, t = C.follow_seq(e, now, lat, char)
			if seq then
				if not op_hp then return e, seq, t end
				-- el que mata gastando MENOS barra (la lista va de mayor a menor daño)
				if e.dmg >= op_hp and (not kill_e or e.meter <= kill_e.meter) then kill_e, kill_seq, kill_t = e, seq, t end
				if not kill_e and not best_e then best_e, best_seq, best_t = e, seq, t end
			end
		end
	end
	if kill_e then return kill_e, kill_seq, kill_t end
	if best_e then return best_e, best_seq, best_t end
	return nil
end

-- input de un normal por nombre de animación (2 frames), para tirar solo el starter de un combo y confirmar el resto
function C.normal_frames(char, anim)
	local n = nby(char)[anim]
	if not n then return nil end
	local f = normal_frame(n)
	local g = {} for k, v in pairs(f) do g[k] = v end
	return { f, g }
end

-- ruta para ir a BUSCAR (modo remate): combo verificado que empieza con un normal y con la barra / SA / carga que hay.
-- op_hp = vida del rival: solo los que matan (el que gasta menos barra, después el starter más rápido y largo).
-- op_hp nil: el de más daño. Devuelve la entrada, el input del starter (2 frames) y su alcance verificado
function C.hunt_route(char, meter, sa, op_hp, chg)
	local db = C.load(char)
	if not db then return nil end
	local nb = nby(char)
	local best
	for st, l in pairs(db.by_starter) do
		local n = nb[st]
		if n then
			for _, e in ipairs(l) do
				if e.meter <= meter and pos_ok(e) and C.sa_ok(e, sa) and (not e.charge or (chg and chg[e.charge]))
					and (not op_hp or e.dmg >= op_hp) then
					local better = not best
						or (op_hp and (e.meter < best.e.meter or (e.meter == best.e.meter and (n.startup or 9) < (best.n.startup or 9))))
						or (not op_hp and e.dmg > best.e.dmg)
					if better then best = { e = e, n = n } end
					break                                       -- lista por daño: el primero válido del starter alcanza
				end
			end
		end
	end
	if not best then return nil end
	local f = normal_frame(best.n)
	local g = {} for k, v in pairs(f) do g[k] = v end
	local reach = best.e.reach or C.MAX_DIST
	if not best.e.wiki then reach = math.min(reach, C.MAX_DIST) end
	return best.e, { f, g }, reach, best.n
end

return C
