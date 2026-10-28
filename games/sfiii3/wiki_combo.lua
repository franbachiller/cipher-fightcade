-- Combos de la wiki en notación canónica (data/sfiii3/wiki_combos.lua): parser y línea de tiempo de inputs.
-- Lo usan el verificador (tools/wiki_combo_lab.lua) y el brain (games/sfiii3/combos.lua), así el bot ejecuta
-- exactamente los inputs que se verificaron en el emulador.
local W = {}

local NAMES = { lp = true, mp = true, hp = true, lk = true, mk = true, hk = true }
local DIGIT = { ["1"] = { down = true, back = true }, ["2"] = { down = true }, ["3"] = { down = true, fwd = true },
	["4"] = { back = true }, ["6"] = { fwd = true }, ["5"] = {} }

local function copy(f) local o = {} for k, v in pairs(f or {}) do o[k] = v end return o end

local function variant(m, btn)
	local pick = m.variants[1]
	for _, v in ipairs(m.variants) do if v.btn == btn then pick = v end end
	return pick
end

-- token -> { frames = {...} (un frame por elemento), press = frame que dispara, charge, super, ex, normal, anim }
function W.token(tok, moves, sa)
	if tok == "UOH" then return { frames = { { mp = true, mk = true }, { mp = true, mk = true } }, press = 1, anim = "uoh" } end
	if tok == "66" then return { frames = { { fwd = true }, {}, { fwd = true } }, press = 3 } end
	local pre, dig, btn = tok:match("^(%a*%.?%s?)([1-6]?)(%u%u)$")
	if btn and NAMES[btn:lower()] then
		local f = copy(DIGIT[dig ~= "" and dig or "5"])
		f[btn:lower()] = true
		local anim = ((dig == "2" or dig == "1" or dig == "3") and "d_" or (dig == "4" and "b_") or (dig == "6" and "f_")
			or (pre:match("^cl") and "cl_") or "") .. btn
		return { frames = { f, copy(f) }, press = 1, normal = true, anim = anim }
	end
	local sa_btn = tok:match("^SA:?(%u*)$")
	if sa_btn then
		for _, m in ipairs(moves) do
			if m.type == "sa" .. sa then
				local v = variant(m, sa_btn)
				local fr = {} for i, f in ipairs(v.seq) do fr[i] = copy(f) end
				return { frames = fr, press = #fr, super = true }
			end
		end
		return nil
	end
	local name, b = tok:match("^([%w_]+):(%u+)$")
	if name then
		for _, m in ipairs(moves) do
			if m.name == name then
				local v = variant(m, b)
				if v.btn ~= b and b ~= "" then return nil end
				local fr = {} for i, f in ipairs(v.seq) do fr[i] = copy(f) end
				return { frames = fr, press = #fr, charge = v.charge, ex = b:match("^EX") ~= nil, anim = name .. "_" .. b }
			end
		end
	end
	return nil
end

local SEPS = { { " > ", "chain" }, { " xx ", "cancel" }, { ", ", "link" } }

-- texto canónico -> pasos (o nil, token que no se entendió)
function W.parse(s, moves, sa)
	local steps, join, rest = {}, nil, s
	while true do
		local best, bj, bl
		for _, sp in ipairs(SEPS) do
			local i = rest:find(sp[1], 1, true)
			if i and (not best or i < best) then best, bj, bl = i, sp[2], #sp[1] end
		end
		local tok = best and rest:sub(1, best - 1) or rest
		local t = W.token(tok, moves, sa)
		if not t then return nil, tok end
		t.tok, t.join = tok, join
		steps[#steps + 1] = t
		if not best then break end
		join, rest = bj, rest:sub(best + bl)
	end
	return steps
end

-- ventana de búsqueda del frame de disparo de un paso, relativa al disparo del anterior
function W.window(st)
	local motion = #st.frames - 1
	if st.join == "chain" then return 2, 22 end
	if st.join == "cancel" then return math.max(1, motion + 1), 26 + motion end
	return math.max(4, motion + 2), 100 + motion                 -- link / juggle (palm EX de Hugo: el rival cae lento)
end

-- precarga (frames antes del primer paso) si algún paso es de carga
function W.pre(steps)
	for _, s in ipairs(steps) do if s.charge then return 60 end end
	return 0
end

-- plan: offset -> frame de input, con los pasos 1..upto disparando en ts[i]
-- robust (online): cada dirección del motion 2 frames, terminando en el MISMO frame del botón (el timing verificado no
-- cambia). Online un frame de 1 se pierde a veces (SendInput + jitter del fin de frame): perder la 1ª diagonal de
-- 236236+P deja 623+P y salía el SHORYUKEN en vez del super (Gouki: ~10 confirms 2MK xx SA -> Goshoryuken al aire).
-- Nunca pisa los frames del paso anterior: sin lugar, comprime
function W.build(steps, upto, ts, robust, floor)
	local plan = {}
	local function put(at, f)
		local m = plan[at] or {}
		for k, v in pairs(f) do m[k] = v end
		plan[at] = m
	end
	local charge_at
	for i = 1, upto do if steps[i].charge then charge_at = i break end end
	local prev_end = -1
	for i = 1, upto do
		local st, t = steps[i], ts[i]
		local n = #st.frames
		local first = t - (st.press - 1)
		if robust and n >= 3 and st.press == n and not st.charge then
			-- frames disponibles hasta el botón inclusive (floor: el hit-confirm arranca ahí, antes ya pasó)
			local room = t - math.max(prev_end + 1, floor or 0) + 1
			local extra = math.max(0, math.min(n - 1, room - n))  -- cuántas direcciones se duplican
			local at = t - (n - 1) - extra
			for j, f in ipairs(st.frames) do
				put(at, f) at = at + 1
				if j < n and j <= extra then put(at, f) at = at + 1 end
			end
		else
			for j, f in ipairs(st.frames) do put(first + j - 1, f) end
		end
		prev_end = math.max(prev_end, t + (n - st.press))
	end
	-- carga: la dirección se sostiene en los frames libres (sin dirección ni botón) hasta el release
	if charge_at then
		local cd = steps[charge_at].charge == "v" and { down = true } or { back = true, down = true }
		local rel = ts[charge_at] - (steps[charge_at].press - 1)
		for at = 0, rel - 1 do
			local f = plan[at]
			local busy = f and (f.up or f.down or f.fwd or f.back)
			local btn = f and (f.lp or f.mp or f.hp or f.lk or f.mk or f.hk)
			if not busy and not btn then put(at, cd) end
		end
	end
	return plan
end

-- secuencia lista para la cola del brain (un frame por elemento) desde el offset `from`
function W.seq(steps, ts, from, robust, floor)
	local plan = W.build(steps, #steps, ts, robust, floor)
	local last = ts[#ts] + #steps[#steps].frames
	local out = {}
	for i = from or 0, last do out[#out + 1] = plan[i] or {} end
	return out
end

return W
