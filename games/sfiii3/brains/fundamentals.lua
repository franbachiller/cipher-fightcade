-- Brain "fundamentals": reacción frame-exacta guiada por frame data.
-- Prioridades: throw tech > secuencia comprometida > anti-air > defensa (parry/bloqueo) > castigo
--              > hit-confirm > presión en wakeup > footsies.
-- Inspirado en el orden de PainPekooo/fight-with-daigo y la predicción de effie3rd/3rd_training_lua.
local P  = require("games.sfiii3.predict")
local FD = require("games.sfiii3.framedata")
local log = require("core.log")

local B = { punish_margin = 4 }      -- margen de rollback online (aprendido por sesión)
local CONN_TRACE = os.getenv("CIPHER_CONN_TRACE") == "1"

local NEUTRAL_POSTURES = { [0x00] = true, [0x02] = true, [0x06] = true, [0x08] = true, [0x20] = true, [0x21] = true }

-- tabla a mano (games/sfiii3/chars/<char>.lua) completada con la generada desde frame data (chars/auto.lua)
local function chars_table(name)
	local auto = require("games.sfiii3.chars.auto")(name)
	local ok, t = pcall(require, "games.sfiii3.chars." .. name)
	if not ok or type(t) ~= "table" then return auto end
	for k, v in pairs(auto) do if t[k] == nil then t[k] = v end end
	return t
end

-- aprendizaje persistente: data\learn\parry_stats.lua (key "char:move" -> {ok, fail})
local LEARN_PATH = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])games[\\/]") or ".\\") .. "data\\learn\\parry_stats.lua"

local FRESH = os.getenv("CIPHER_FRESH") == "1"   -- evaluaciones: sin cargar ni guardar aprendizaje
local OKI_TRACE = os.getenv("CIPHER_OKI_TRACE") == "1"
local TECH_TRACE = os.getenv("CIPHER_TECH_TRACE") == "1"
local PRESS_TRACE = os.getenv("CIPHER_PRESS_TRACE") == "1"

local function load_learned()
	if FRESH then return {} end
	local ok, t = pcall(dofile, LEARN_PATH)
	return (ok and type(t) == "table") and t or {}
end

local function save_learned(stats)
	if FRESH then return end
	local f = io.open(LEARN_PATH, "w")
	if not f then
		os.execute('mkdir "' .. LEARN_PATH:match("^(.*)[\\/]") .. '" 2>nul')
		f = io.open(LEARN_PATH, "w")
		if not f then return end
	end
	f:write("return {\n")
	for k, v in pairs(stats) do f:write(string.format("  [%q] = { ok = %d, fail = %d },\n", k, v.ok, v.fail)) end
	f:write("}\n")
	f:close()
end
B.save_learned = save_learned

-- okizeme: frame de la animación "wakeup_ext" en que el rival deja de estar tirado (posture != 0x26),
-- por "char:anim". Medido en vivo y persistido (data\learn\wake_stats.lua). Ojo con los nombres de la frame data:
-- "wakeup" = todavía tirado (Ryu 34f), "wakeup_ext" = levantándose (Ryu: se para en el af 42 de 53).
local WAKE_PATH = LEARN_PATH:gsub("parry_stats", "wake_stats")
local WAKE = (function()
	local ok, t = pcall(dofile, WAKE_PATH)
	return (ok and type(t) == "table") and t or {}
end)()
local WAKE_DEFAULT_EXT = 42                 -- Ryu medido; se reemplaza por lo aprendido de cada personaje

local function save_wake()
	local f = io.open(WAKE_PATH, "w")
	if not f then return end
	f:write("return {\n")
	for k, v in pairs(WAKE) do f:write(string.format("  [%q] = %d,\n", k, v)) end
	f:write("}\n")
	f:close()
end

-- aprende el frame de pararse de cada animación _ext del rival
local function learn_wake(mem, op)
	if op.move == "wakeup_ext" and op.knocked_down then
		mem.wake_anim, mem.wake_af = op.anim, op.anim_frame
	elseif mem.wake_anim and not op.knocked_down then
		local key = op.char_str .. ":" .. tostring(mem.wake_anim)
		local af = mem.wake_af + 1
		if WAKE[key] ~= af then
			WAKE[key] = af
			WAKE[op.char_str] = af
			log.write("wake-learn %s = %d", key, af)
			save_wake()
		end
		mem.wake_anim = nil
	elseif not op.knocked_down then
		mem.wake_anim = nil
	end
end

-- frames hasta que el rival deja de estar tirado (nil si no se sabe)
local function wake_remaining(op)
	if not (op.knocked_down and op.fd and op.move) then return nil end
	local ext = WAKE[op.char_str .. ":" .. tostring(op.anim)] or WAKE[op.char_str] or WAKE_DEFAULT_EXT
	if op.move == "wakeup_ext" then return ext - op.anim_frame end
	if op.move == "wakeup" then return (op.fd.len - op.anim_frame) + (WAKE[op.char_str] or WAKE_DEFAULT_EXT) end
	return nil
end

function B.reset(ctx)
	local learned = ctx.mem and ctx.mem.parry_stats or load_learned()   -- sobrevive a resets y entre sesiones
	ctx.mem = { parry_stats = learned, last_parry = -999, fireball_cd = 0, prev_op_y = 0, aa_cd = 0, label = "idle", wake_plan = nil,
		pp_trace = os.getenv("CIPHER_PP_TRACE") == "1",
		op_atts = {}, op_projs = {}, my_blocks = {}, still = 0, move_cd = 0 }
end

-- historial reciente del rival / mío para leer spam y quietud (ventanas en frames)
local function recent(list, frame, win)
	while list[1] and frame - list[1] > win do table.remove(list, 1) end
	return #list
end

local function track_habits(mem, s, me, op, side)
	if op.attacking and not mem.prev_op_att then table.insert(mem.op_atts, s.frame) end
	mem.prev_op_att = op.attacking
	for _, pr in ipairs(s.proj or {}) do          -- objetos persistentes entre frames: se cuentan una vez
		if pr.emitter ~= side and not pr.cipher_counted then
			pr.cipher_counted = true
			table.insert(mem.op_projs, s.frame)
		end
	end
	if me.has_just_blocked_conn then table.insert(mem.my_blocks, s.frame) end
	-- anti-airs que me comí (me pegaron en el aire): con 2 en 30 s no salto más (vs Gouki online: 26 en un round)
	mem.aa_taken = mem.aa_taken or {}
	if me.airborne and me.has_just_received_hit then table.insert(mem.aa_taken, s.frame) end
	mem.no_jump = recent(mem.aa_taken, s.frame, 1800) >= 2
	-- personajes de carga con anti-air de carga (Remy: Rising Rage Flash, 8 recibidos saltando/acercándose en 3
	-- peleas): sentados abajo-atrás esperando el salto. Desde media distancia no se salta
	local FLASH = { remy = true, hugo = true }     -- hugo: Shootdown Backbreaker agarra el salto
	if FLASH[op.char_str] and s.dist < 220 then mem.no_jump = true end
	-- agarres que me comí (normales y de comando) en 30 s
	mem.thrown_list = mem.thrown_list or {}
	if me.has_just_been_thrown then table.insert(mem.thrown_list, s.frame) end
	mem.thrown_recent = recent(mem.thrown_list, s.frame, 1800)
	-- el golpe actual del rival conectó (lo bloqueé, me pegó o lo parreé): si no, es un golpe al aire (whiff punish)
	-- (no is_blocking: la guardia de proximidad se activa con un golpe que pasa cerca y ERRA: el sweep errado a 150 px
	-- quedaba como "conectado" y no se castigaba)
	if me.has_just_blocked_conn or me.has_just_been_hit or me.has_just_parried then
		if CONN_TRACE and op.move == "d_HK" then
			log.write("conn-trace blk=%s hit=%s par=%s marker=%04x op=%s af=%s d=%d", tostring(me.has_just_blocked_conn),
				tostring(me.has_just_been_hit), tostring(me.has_just_parried), me.recv_marker or 0, tostring(op.move), tostring(op.anim_frame), s.dist)
		end
		mem.op_conn_at = op.anim_start
	end
	-- rival QUIETO (taunt, provocando, esperando): misma X, en el piso, sin atacar ni bloquear
	if not op.airborne and not op.attacking and not op.is_blocking and not op.knocked_down
		and math.abs(op.x - (mem.op_still_x or op.x)) < 2 then
		mem.op_still = (mem.op_still or 0) + 1
	else
		mem.op_still = 0
	end
	mem.op_still_x = op.x
	-- parries del rival a mis golpes en 30 s: un rival que parrea mucho se combate con agarres y timing variado
	mem.op_parry_list = mem.op_parry_list or {}
	if op.has_just_parried then
		mem.op_parry_at = s.frame
		table.insert(mem.op_parry_list, s.frame)
		log.write("op-parry my_move=%s label=%s d=%d", tostring(me.move), tostring(mem.label), s.dist)
		mem.aa_parried = mem.aa_parried or {}
		if tostring(mem.label):find("^anti%-air") then table.insert(mem.aa_parried, s.frame) end
	end
	mem.op_parry_recent = recent(mem.op_parry_list, s.frame, 1800)
	-- fin del bloqueo del rival (mi golpe bloqueado): punto de partida de la presión
	if mem.op_was_blocking and not op.is_blocking then
		mem.op_block_end = s.frame
		if PRESS_TRACE then
			log.write("blk-end d=%d me_post=%02x me_att=%s me_fz=%d me_move=%s op_blk_id=%d", s.dist, me.posture,
				tostring(me.attacking), me.freeze, tostring(me.move), op.blocking_id)
		end
	end
	mem.op_was_blocking = op.is_blocking
	mem.op_spam = recent(mem.op_atts, s.frame, 120)        -- ataques del rival en 2 s
	mem.op_zoning = recent(mem.op_projs, s.frame, 180)     -- proyectiles en 3 s
	mem.pressured = recent(mem.my_blocks, s.frame, 90)     -- golpes bloqueados en 1.5 s
	-- quietud: frames seguidos pudiendo actuar sin moverme ni atacar
	local idle = NEUTRAL_POSTURES[me.posture] and not me.attacking and me.freeze == 0 and not me.is_blocking
		and not op.knocked_down
	if idle and mem.still_x and math.abs(me.x - mem.still_x) < 4 then
		mem.still = mem.still + 1
	else
		mem.still, mem.still_x = 0, me.x
	end
	if mem.move_cd > 0 then mem.move_cd = mem.move_cd - 1 end
end

-- movimientos de neutral (relativos): dash, backdash, salto adelante con patada, salto neutro
local MOVES = {
	-- sin los 10 frames de espera al final: después del dash se actúa YA (ver "4c"); esperando, los agarraban
	-- 2 frames neutrales ANTES del primer toque: si venía caminando adelante / en guardia atrás, la dirección ya estaba
	-- apretada, el 1er toque no era un toque nuevo y el dash no salía (dash-diag: 41% FAIL, backdash "now=standing")
	dash      = function() return { { hold = 2 }, { fwd = true, hold = 2 }, { hold = 2 }, { fwd = true, hold = 2 }, { hold = 2 } } end,
	backdash  = function() return { { hold = 2 }, { back = true, hold = 2 }, { hold = 2 }, { back = true, hold = 2 }, { hold = 10 } } end,
	jump_in   = function(btn) return { { up = true, fwd = true, hold = 3 }, { hold = 15 }, { [btn or "hk"] = true, hold = 3 }, { hold = 16 } } end,
	jump_up   = function() return { { up = true, hold = 3 }, { hold = 30 } } end,
	-- n <= 0 (safe_in: el paso terminaría adentro de su agarre): guardia en el lugar en vez de caminar
	shimmy_in = function(n) if n <= 0 then return { { back = true, down = true, hold = 4 } } end return { { fwd = true, hold = n }, { hold = 2 } } end,
	shimmy_out = function(n) return { { back = true, hold = n }, { hold = 2 } } end,
	crouch    = function(n) return { { down = true, hold = n } } end,
}

-- presión tras un golpe bloqueado (wiki System + estrategias de personaje):
--   tick  = caminar un toque y agarrar: llega después de los 6f de protección de agarre post-bloqueo (agarre 3f startup)
--   trap  = débil y medio con un hueco chico: le gana al botón / al tech del rival (frame trap)
--   low   = dos débiles bajos (plus en bloqueo) para seguir el turno
--   uoh   = overhead universal (pega al que se queda agachado)
--   bait  = guardia un rato: hace fallar el reversal / agarre del rival y se castiga con lo normal
local PRESSURE = {
	-- wiki System: 6 frames de protección contra agarres al salir del bloqueo. Caminar `walk` frames para que el agarre
	-- caiga después (antes: 2 frames -> el agarre caía dentro de la protección y fallaba siempre)
	tick = function(ch, walk) local s = { { fwd = true, hold = walk or 2 } } for _, f in ipairs(ch.throw()) do s[#s + 1] = f end return s end,
	trap = function() return { { down = true, lk = true, hold = 2 }, { down = true, hold = 3 }, { mp = true, hold = 2 }, { hold = 6 } } end,
	low  = function() return { { down = true, lk = true, hold = 2 }, { down = true, hold = 2 }, { down = true, lk = true, hold = 2 }, { down = true, hold = 6 } } end,
	uoh  = function(ch) return ch.overhead and ch.overhead.seq() or { { mp = true, mk = true, hold = 2 }, { hold = 28 } } end,
	bait = function() return { { back = true, down = true, hold = 14 } } end,
}

-- RADAR (input del rival leído de la RAM, state.radar): qué le gana a lo que tiene APRETADO ahora. Devuelve
-- multiplicadores por opción (throw / low / over / hit / trap / bait) y el motivo. Al 75%: un humano a veces se
-- equivoca, y acertar siempre se nota
--   guardia agachada (abajo-atrás)  -> overhead / agarre      guardia parada (atrás) -> bajo / agarre
--   parry (ventana abierta / toque) -> agarre / esperar        tech OS (LP+LK)        -> frame trap / golpe
--   sin guardia (neutral / abajo)   -> cualquier golpe
local function radar(s, op)
	local r = { throw = 1, low = 1, over = 1, hit = 1, trap = 1, bait = 1 }
	if not op.guard or op.attacking or op.airborne or op.knocked_down or math.random() > 0.75 then return r end
	local f = s.frame
	if op.parry_window or (op.tap_fwd and f - op.tap_fwd <= 8 and op.guard ~= "stand" and op.guard ~= "crouch") then
		r.hit, r.low, r.over, r.trap, r.throw, r.bait, r.why = 0.15, 0.15, 0.15, 0.4, 3, 2, "parry"
	elseif op.tech_at and f - op.tech_at <= 10 then
		r.throw, r.trap, r.hit, r.why = 0.15, 3, 1.5, "tech"
	elseif op.guard == "crouch" and (op.guard_n or 0) >= 4 then
		r.over, r.throw, r.low, r.why = 4, 2.5, 0.2, "agachado"
	elseif op.guard == "stand" and (op.guard_n or 0) >= 4 then
		r.low, r.throw, r.over, r.why = 4, 2, 0.3, "parado"
	elseif op.guard == "neutral" or op.guard == "down" or op.guard == "fwd" then
		r.hit, r.low, r.throw, r.why = 2, (op.guard == "down") and 2 or 1.5, 1.5, "sin guardia"
	end
	return r
end
-- golpe bajo: patadas agachado (cr.LK / cr.MK / cr.HK)
local function is_low(anim) return anim and anim:match("^d_%a?K$") ~= nil end
local function rtag(r) return r.why and (" [radar " .. r.why .. "]") or "" end

local function pick(opts)
	local total = 0
	for _, o in ipairs(opts) do total = total + o[1] end
	local r = math.random() * total
	for _, o in ipairs(opts) do
		r = r - o[1]
		if r <= 0 then return o[2] end
	end
	return opts[#opts][2]
end

local function can_act(me)
	-- not airborne: al caer de un goshoryuken la postura ya es neutral con y > 0 y se apretaba agarre en el aire
	-- (5 "throw" en 20 frames, todos JUMPED, vs Ryu online)
	return NEUTRAL_POSTURES[me.posture] and not me.airborne and not me.attacking and me.freeze == 0 and not me.is_blocking
		and not me.being_thrown and me.hp ~= 255      -- hp 0 = última raya, sigue vivo (muerto = 255)
end

local function push(ctx, frames, label)
	ctx.queue:clear()
	ctx.mem.range_guard = nil              -- el guard de rango es del castigo que lo armó
	if label and label:find("dash") and not label:find("backdash") then ctx.mem.after_dash = true end
	-- dash / backdash COMPROMETIDO: es doble toque y cualquier frame del brain (guardia anticipada) o de effie en el medio
	-- se comía el 2º toque -> el dash no salía ("falla muchas veces el paso rápido"). dash-diag verifica en la RAM
	if label and label:find("dash") and not label:find("post%-dash") then
		ctx.mem.committed = true
		ctx.mem.dash_diag = { frame = ctx.mem.now_frame or 0, label = label, back = label:find("backdash") ~= nil }
	end
	ctx.queue:push(frames)
	ctx.mem.label = label
	local cg = ctx.chars and ctx.chars.command_grab
	-- diagnóstico de agarres (comando y normales: neutral, tick, okizeme): GRAB / JUMPED / MISS en el log
	if label and ((cg and label:find(cg.name, 1, true)) or label == "throw" or label == "presión tick" or label == "oki throw") then
		ctx.mem.grab_pending = label
	end
end

local function in_range(r, d) return d >= r[1] and d <= r[2] end

-- super del SA elegido (inputs de la move list, igual que los verificados en el lab) y si es de proyectil
local WCombo = require("games.sfiii3.wiki_combo")
local MOVES_DIR = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])games[\\/]") or ".\\") .. "data\\sfiii3\\moves\\"
local SUPER_CACHE = {}
local function super_frames(char, sa)
	if not char or not sa then return nil end
	local key = char .. sa
	if SUPER_CACHE[key] == nil then
		local ok, mv = pcall(dofile, MOVES_DIR .. char .. ".lua")
		local t = ok and type(mv) == "table" and WCombo.token("SA", mv, sa)
		SUPER_CACHE[key] = t and t.frames or false
	end
	if not SUPER_CACHE[key] then return nil end
	local out = {}
	for i, f in ipairs(SUPER_CACHE[key]) do local c = {} for k, v in pairs(f) do c[k] = v end out[i] = c end
	out[#out + 1] = { hold = 2 }
	return out
end
-- supers de proyectil (chip a distancia): Messatsu Gouhadou, Shinkuu Hadouken, Kikoushou, Hadou Burst, X.N.D.L.,
-- Electric Snake, Yagyoudama, Kasumi Suzaku, Light of Justice, Temporal Thunder
local PROJ_SUPER = { gouki = 1, ryu = 1, chunli = 1, sean = 1, twelve = 1, necro = 3, oro = 2, ibuki = 1, remy = 1, urien = 2 }
local function is_proj_super(me) return PROJ_SUPER[me.char_str] ~= nil and PROJ_SUPER[me.char_str] == me.sa end
-- supers que AVANZAN (Boomerang Raid de Alex, Shippu de Ken, Houyoku-sen de Chun): si el normal conectó, el super llega
-- aunque el empuje lo deje más lejos que la distancia del lab. No es el caso del Shin Shoryuken (en el lugar)
local RUSH_SUPER = { alex = 2, ken = 3, chunli = 2 }
local function is_rush_super(me) return RUSH_SUPER[me.char_str] ~= nil and RUSH_SUPER[me.char_str] == me.sa end

-- especiales de identidad: ch.specials = { { name, role, seq, range = {min,max}, meter, sa, charge, rate, cd, ... } }
-- roles: poke (especial de neutral: rekka, machine gun), zoning (bolas / proyectiles), approach (entrar: Hayate,
-- tackles, demon flip), install (activar Genei-Jin / Aegis / Tengu), taunt (personal action con buff), overhead
local CHARGE_READY = 50
-- motion que arranca en abajo (qcf/hcf: hadouken, kunai...) poco después de caminar adelante: el juego lee adelante,
-- abajo, abajo-adelante + botón = SHORYUKEN. 8 shoryukens al aire a 200+ px tras "walk in" en una pelea (Ken/Ryu).
-- Antes del motion, abajo-atrás hasta que el último adelante salga del buffer (12 frames; ctx.* lo lleva cipher.lua)
local function clean_motion(ctx, seq, frame)
	local f1 = seq[1]
	if not (f1 and f1.down and not f1.fwd) then return seq end
	local since = ctx.prev_fwd and 0 or (ctx.fwd_release and (frame - ctx.fwd_release) or 99)
	if since < 12 then table.insert(seq, 1, { down = true, back = true, hold = 12 - since }) end
	return seq
end

local function try_special(ctx, ch, mem, s, me, op, d, role)
	if not ch.specials then return false end
	mem.sp_cd = mem.sp_cd or {}
	for _, sp in ipairs(ch.specials) do
		if sp.role == role then
			local key = sp.name
			local ready = (mem.sp_cd[key] or 0) <= s.frame
			local in_rng = not sp.range or (d >= sp.range[1] and d <= sp.range[2])
			local meter_ok = (sp.meter or 0) <= me.meter
			local sa_ok = (not sp.sa or sp.sa == me.sa) and not (sp.no_sa and sp.no_sa[me.sa])
			local c = ctx.charge or { h = 0, v = 0 }
			local charge_ok = not sp.charge or (sp.charge == "h" and c.h >= CHARGE_READY) or (sp.charge == "v" and c.v >= CHARGE_READY)
			local cond_ok = not sp.when or sp.when(s, me, op, d, mem)
			if op.airborne and sp.role ~= "antiair" then cond_ok = false end   -- rival saltando: anti-air / guardia, no especiales
			-- especiales aéreos (zanku hadou, kunai, air dash: arrancan con salto; hyakki: voltereta) con el freno de saltos
			-- activo (2 anti-airs recibidos en 30 s): Dudley anti-aireó 8 veces a Gouki en un round
			if mem.no_jump and (sp.name:find("hyakki") or sp.seq()[1].up or (sp.seq()[2] or {}).up) then cond_ok = false end
			if ready and in_rng and meter_ok and sa_ok and charge_ok and cond_ok and math.random() < (sp.rate or 0.1) then
				mem.sp_cd[key] = s.frame + (sp.cd or 60)
				push(ctx, clean_motion(ctx, sp.seq(), s.frame), role .. " " .. sp.name)
				mem.committed = sp.commit ~= false
				if role == "poke" or role == "approach" or role == "overhead" then mem.confirm = { start = s.frame } end
				return true
			end
		end
	end
	return false
end

local CHARGE_FRAMES = 50
-- especial de carga listo: frames seguidos sosteniendo la dirección (contados en cipher.lua)
local function charged(ctx, kind)
	if not kind then return true end
	local c = ctx.charge or { h = 0, v = 0 }
	return (kind == "h" and c.h >= CHARGE_FRAMES) or (kind == "v" and c.v >= CHARGE_FRAMES)
end

local WALK_SPEED = 3.2   -- px/frame aprox. caminando hacia adelante
-- frames de caminata que NO terminan adentro del agarre del rival (+10 px): online el bot caminaba de más y lo
-- agarraban parado / caminando (25 agarres en 2 sesiones: "presiona: entra", "camina", "remate: se acerca")
local function safe_in(d, n, thr)
	return math.max(0, math.min(n, math.floor((d - ((thr or 72) + 10)) / WALK_SPEED)))
end

local function seq_len(seq)
	local n = 0
	for _, f in ipairs(seq) do n = n + (f.hold or 1) end
	return n
end

-- frames desde el inicio de la secuencia hasta el primer botón (el 360 de Hugo aprieta en el 6º frame)
local function button_offset(seq)
	local n = 0
	for _, f in ipairs(seq) do
		if f.lp or f.mp or f.hp or f.lk or f.mk or f.hk then return n end
		n = n + (f.hold or 1)
	end
	return n
end

local Combos = require("games.sfiii3.combos")
local RG = require("games.sfiii3.ranges")
local History = require("core.history")
-- supers invencibles al arrancar (sirven de reversal): Shin Shoryuken, Shoryureppa / Shinryuken, Messatsu Goushoryu,
-- Rocket Upper, Shoryu Cannon, Raishin / Tenshin Senkyuutai, Boomerang Raid, Houyoku-sen, You Hou, Seichusen,
-- Supreme Rising Rage Flash, Yami Shigure
local REV_SUPER = { ryu = { [2] = true }, ken = { [1] = true, [2] = true }, gouki = { [2] = true }, dudley = { [1] = true },
	sean = { [2] = true }, yang = { [1] = true, [2] = true }, alex = { [2] = true }, chunli = { [2] = true },
	yun = { [1] = true }, makoto = { [1] = true }, remy = { [2] = true }, ibuki = { [3] = true } }
-- daño del super suelto, estimado del combo "normal xx SA" verificado de MENOS daño menos el normal (~12)
local RAW_SUPER_DMG = {}
local function raw_super_dmg(char, sa)
	local key = char .. (sa or 0)
	if RAW_SUPER_DMG[key] == nil then
		local db, lo = Combos.load(char), nil
		for _, e in ipairs(db and db.list or {}) do
			if e.wiki and e.kind == ("sa" .. tostring(sa)) and e.follow and e.follow:match("^%S+ xx SA$") then
				lo = math.min(lo or 999, e.dmg)
			end
		end
		RAW_SUPER_DMG[key] = lo and (lo - 12) or false
	end
	return RAW_SUPER_DMG[key] or nil
end
local MARGIN = 3     -- px de margen bajo el alcance máximo calculado
local THROW_FIX = 9  -- corrección del alcance de agarre normal de la tabla (ver grab_reach)

-- alcance real de mi agarre contra ESTE rival y su postura. cmd = agarre de comando (por defecto solo si el personaje
-- es grappler: Hugo agarra con el 360 en neutral; Alex agarra normal en neutral y usa el Power Bomb para castigar)
local function grab_reach(ch, me, op, cmd)
	if cmd == nil then cmd = ch.grappler end
	local cg = cmd and ch.command_grab
	if cg then
		local r = RG.prefix(me.char_str, cg.name, op.char_str, op.crouching)
		return r and (r - MARGIN - (cg.fix or 0)) or cg.range     -- fix: corrección medida (Power Bomb: tabla 104, real 94)
	end
	local r = RG.throw(me.char_str, op.char_str, op.crouching)
	-- la tabla sobreestima el agarre normal ~10 px (medido con tools/test_range.lua: Ryu tabla 83 / real ~72, Chun
	-- ~68): THROW_FIX. Agarres errados online: Chun 34 de 57, Ryu 9 de 11
	return r and (r - MARGIN - THROW_FIX + (ch.kara or 0)) or (ch.grab_range or 50)    -- kara: + px medidos
end

-- rival agarrable YA: no en bloqueo ni en los 6f de protección post-bloqueo, no en el aire, no levantándose.
-- 231 agarres errados en un día (44% de acierto): "rival bloqueando" SUBÍA la tasa de agarre, y en blockstun no
-- se lo puede agarrar
local function throwable(s, mem, op)
	return not op.airborne and not op.is_blocking and not op.knocked_down and not op.being_thrown and op.freeze == 0
		and not (op.move or ""):find("wakeup") and not (mem.op_block_end and s.frame - mem.op_block_end <= 6)
end

-- agarre de comando aprendido: los que erran seguido (Snake Fang post-parry 4/27) no se usan para castigar
local function grab_ok(mem, me, name)
	local st = mem.parry_stats["grab:" .. me.char_str .. ":" .. name]
	return not (st and st.fail >= 3 and st.fail > 2 * st.ok)
end

-- alcance de los pokes del RIVAL contra mí (máximo de sus normales de piso con startup razonable), con caché
local OP_POKES = { "d_MK", "MK", "MP", "d_MP", "HP", "d_HP", "HK", "d_HK", "LK", "d_LK", "b_HP", "f_MP" }
local op_reach_cache = {}
local function op_poke_reach(op, me)
	local key = op.char_str .. ">" .. me.char_str
	if op_reach_cache[key] then return op_reach_cache[key] end
	local best = 0
	for _, n in ipairs(OP_POKES) do
		local r = RG.reach(op.char_str, n, me.char_str, false)
		if r and r > best and r < 200 then best = r end
	end
	op_reach_cache[key] = (best > 0) and best or 140
	return op_reach_cache[key]
end

-- alcance real de un golpe contra este rival (si no hay dato, el rango de la tabla)
local function move_reach(me, op, pk)
	local r = RG.reach(me.char_str, pk.anim or pk.name, op.char_str, op.crouching)
	return r and (r - MARGIN) or pk.range[2]
end

local SB = require("games.sfiii3.state")
-- ¿conecta mi `anim` contra el rival? Cajas de ataque de la frame data (por frame activo) contra las cajas vulnerables
-- REALES del rival en la RAM (vuln + ext_vuln: brazos / piernas estiradas). lead: frames hasta que sale el golpe
-- (startup + delay + caminata); en ese tiempo el cuerpo del rival se corre con su velocidad actual de la RAM.
-- margin: px de solapamiento exigidos (online, el rollback mueve todo un poco). nil = sin datos (decide el alcance)
local function hit_check(me, op, anim, walk_px, lead, margin)
	local a = anim and FD.anim(me.char_str, anim)
	if not (a and a.hit and a.atk) then return nil end
	local rects = {}
	local vxw = (op.vx or 0) * ((op.flip == 1) and 1 or -1)
	for _, kind in ipairs({ "vuln", "ext_vuln" }) do
		for _, bx in ipairs(op.boxes and op.boxes[kind] or {}) do
			local l, r, b, tp = SB.world_box(op.x, op.y, op.flip, bx)
			rects[#rects + 1] = { l, r, b, tp }
		end
	end
	if #rects == 0 then return nil end
	local m = margin or 0
	local mx = me.x + ((op.x > me.x) and 1 or -1) * (walk_px or 0)
	for _, h in ipairs(a.hit) do
		for f = h[1], h[2] do
			-- el rival se sigue moviendo hasta el frame activo f (lead = frames antes de que arranque mi golpe)
			local sh = vxw * math.min(20, (lead or 0) + f)
			for _, bx in ipairs(FD.attack_boxes(a, f) or {}) do
				local l, r, b, tp = SB.world_box(mx, me.y, me.flip, bx)
				for _, q in ipairs(rects) do
					if l + m < q[2] + sh and r - m > q[1] + sh and b < q[4] and tp > q[3] then return true end
				end
			end
		end
	end
	return false
end
local function poke_connects(me, op, anim, walk_px) return hit_check(me, op, anim, walk_px, 0, 0) end
-- online: 3 px de solapamiento y el delay real como anticipo; offline exacto
local function box_ok(me, op, anim, walk_px, lat)
	return hit_check(me, op, anim, walk_px, (lat or 0) + 1, CIPHER_EXT and 8 or 0) ~= false
end

-- mejor castigo que conecta dentro de `adv` frames (caminando hasta el rango si sobra tiempo)
-- 1º combos verificados por el laboratorio (más daño primero), 2º tabla de castigos del personaje
-- stun = true: rival mareado (no se mueve ni se defiende): caminar lo que haga falta y supers cuerpo a cuerpo también
-- caminando (antes se descartaban y el mareo se castigaba con cl.MK > Niouriki en vez del combo con super)
-- castigo propio que el aprendizaje marcó como malo (6+ fallos y más del doble que aciertos; 20% reintenta)
local function bad_punish(ctx, me, name)
	local st = ctx.mem and ctx.mem.parry_stats and ctx.mem.parry_stats["mypunish:" .. me.char_str .. ":" .. name]
	-- (antes fail > 2*ok: Dudley HK 23/38 y Ryu far HP > far HK 4/9 seguían saliendo; ahora < 40% de acierto con 8+)
	return st and ((st.fail >= 6 and st.fail > 2 * st.ok) or (st.ok + st.fail >= 8 and st.ok < 0.4 * (st.ok + st.fail)))
		and math.random() > 0.2
end

local function plan_punish(ctx, ch, me, d, adv, lat, stun)
	-- online (rollback): el movimiento del rival llega tarde a la RAM local, así que la recuperación que vemos es mayor
	-- que la real. Sin este margen los castigos salían tarde y quedaban bloqueados (vs Alex: varios "got=0").
	-- online: margen de rollback ADAPTATIVO (B.punish_margin): el delay medido es solo el de input; la red agrega
	-- frames que no vemos. 170 castigos en 14 sesiones con mediana de daño 0 = la ventana ya se había cerrado
	if CIPHER_EXT then lat = lat + B.punish_margin elseif lat >= 2 then lat = lat + 2 end
	local db = Combos.load(me.char_str)
	local op_hp = ctx.op_hp_now
	local kill
	ctx.pp_best = nil
	if db then
		for _, e in ipairs(db.list) do
			-- online: castigo con barra que se corta en hit-confirm y cuyo 2º paso es un link de ventana < 5f ("far HP, SA":
			-- 1f): el confirm nunca llega a tiempo -> 8 castigos "(confirm)" sin daño en una sesión de Ken
			local tight = CIPHER_EXT and e.wiki and (e.meter or 0) > 0 and e.steps and e.steps[2] and e.steps[2].join == "link"
				and (tonumber(e.win and e.win[2]) or 1) < 5
			if not tight and (not e.corner or Combos.corner_now) and e.meter <= me.meter and Combos.sa_ok(e, me.sa) and not (e.min_d and d < e.min_d) and not bad_punish(ctx, me, e.label)
				and (not e.charge or charged(ctx, e.charge)) then      -- combos de carga: solo con la carga lista
				local gap = math.max(0, d - e.reach)
				local walk = math.ceil(gap / WALK_SPEED)
				-- caminar hasta el rango con lag: solo si sobra tiempo de verdad
				local spare = (lat >= 4 and walk > 0) and 3 or 0
				if CIPHER_EXT and walk > 0 and not stun then spare = 8 end      -- online: caminar para castigar casi nunca llega
				-- nunca más de ~0.25 s caminando hacia el castigo (vs Hugo caminaba 30-36 frames y llegaba tarde)
				-- (el tope escala con la ventaja: con 35 f tras un parry a 124 px Ryu no castigaba nada)
				if not stun and walk > math.max(CIPHER_EXT and 10 or 14, adv - 18) then walk = 999 end
				-- super cuerpo a cuerpo (Shin Shoryuken) solo SIN caminar y dentro del alcance verificado: caminando, el cl.MP
				-- salía como MP lejano a ~100 px y el super erraba entero (post-parry cl.MP xx SA a 101 px)
				local melee_super = e.kind:match("^sa") and not is_proj_super(me) and not is_rush_super(me)
				local kills = op_hp and e.dmg >= op_hp
				if (stun or not (melee_super and (walk > 0 or d > e.reach + 6))) and walk + e.startup + lat + 1 + spare <= adv then
					local seq = Combos.full_seq(e, nil, me.char_str)
					if walk > 0 then table.insert(seq, 1, { fwd = true, hold = walk }) end
					local res = { seq, string.format("%s [%d]%s%s", e.label, e.dmg, walk > 0 and (" (+walk " .. walk .. ")") or "",
						kills and " MATA" or ""), e.dmg, (e.starter or (e.chain and e.chain[1])), e.reach, e, walk }
					-- sin vida del rival: el de más daño (el primero). Con vida: el que mata gastando menos barra; si ninguno mata,
					-- el de más daño
					if not op_hp then return unpack(res) end
					if kills and (not kill or e.meter <= kill.meter) then kill = { e = e, res = res, meter = e.meter } end
					if not kills and not kill and not ctx.pp_best then ctx.pp_best = res end
				end
			end
		end
	end
	if kill then return unpack(kill.res) end
	if ctx.pp_best then local r = ctx.pp_best ctx.pp_best = nil return unpack(r) end
	for _, pn in ipairs(ch.punish) do
		-- ch.punish_exclude: castigos automáticos que el lab de castigos mostró que no sirven (Alex f.HP: 37-58% sin daño)
		if (not pn.meter or me.meter >= pn.meter) and not (ch.punish_exclude and ch.punish_exclude[pn.name]) and not bad_punish(ctx, me, pn.name) then
			local seq = pn.seq()
			local pr2 = pn.range[2]
			if tostring(pn.anim or pn.name):match("^cl_") then pr2 = math.min(pr2, 54) end   -- cl.* solo de cerca
			-- online 10 px adentro: st.HK / far HP de castigo erraban a 101-131 px tras la barrida bloqueada
			if CIPHER_EXT and not tostring(pn.anim or pn.name):match("^cl_") then pr2 = pr2 - 10 end
			local gap = math.max(0, d - pr2)
			local walk = math.ceil(gap / WALK_SPEED)
			if walk > math.max(CIPHER_EXT and 10 or 14, adv - 18) then walk = 999 end      -- tope de caminata (ver arriba)
			-- sin caminar: las cajas reales tienen que conectar (st.HK de castigo al aire a 101-117 px)
			local bok = walk > 0 or not ctx.op_now or box_ok(me, ctx.op_now, pn.anim or pn.name, 0, lat)
			if bok and d >= pn.range[1] and walk + seq_len(seq) + (pn.startup or 5) + lat + 1 <= adv then
				if walk > 0 then table.insert(seq, 1, { fwd = true, hold = walk }) end
				-- el nombre de los castigos automáticos ES la animación (cl_HP, d_MK...): sirve para el guard de rango
				return seq, pn.name .. (walk > 0 and (" (+walk " .. walk .. ")") or ""), nil, pn.anim or pn.name, pn.range[2]
			end
		end
	end
	return nil
end

-- castigo que GASTA barra (super / EX), online: solo el starter (+ caminata) y el resto por HIT-CONFIRM (1b). Online 60
-- de 94 castigos sin daño en una sesión, varios con el super adentro: la secuencia entera salía aunque el primer golpe
-- no pegara (Shin Shoryuken al aire a 113 px marcado "MATA"). El combo se tira cuando es seguro que pega
local function confirm_cut(mem, s, me, e, walk)
	if not (CIPHER_EXT and e and (e.meter or 0) > 0) then return nil end
	local st = e.starter or (e.chain and e.chain[1])
	local seq = st and Combos.normal_frames(me.char_str, st)
	if not seq then return nil end
	if walk and walk > 0 then table.insert(seq, 1, { fwd = true, hold = walk }) end
	return seq, (walk or 0)
end

-- frames que el rival no puede actuar: freeze + lo que le queda de animación (con frame data)
local function op_disadvantage(op)
	if not op.fd then return op.freeze end
	return op.freeze + math.max(0, FD.recovery_end(op.fd) - op.anim_frame)
end

-- rival saltando: frames hasta que baja a la altura de golpe del salto (y <= 60) con la trayectoria real
-- (velocidad + aceleración de la RAM) y distancia horizontal a mí en ese momento
local function air_arrival(me, op, ylim)
	ylim = ylim or 60
	local sg = op.flip == 1 and 1 or -1
	local px, py, vx, vy = op.x, op.y, op.vx * sg, op.vy
	local ax, ay = (op.ax or 0) * sg, op.ay or 0
	for t = 1, 40 do
		px, py, vx, vy = px + vx, py + vy, vx + ax, vy + ay
		if py <= ylim and vy < 0 then return t, math.abs(px - me.x) end
		if py <= 0 then return nil end
	end
	return nil
end

-- cuánto sobresalen hacia mí las cajas vulnerables del rival respecto de su cuerpo en neutral (la pierna de un sweep,
-- el brazo de un HP): el whiff punish le pega a eso, no al cuerpo. Sweep errado a 160 px: contra el cuerpo nada
-- llegaba (32% online en el lab de castigos)
local function limb_gain(mem, me, op)
	local toward = (me.x > op.x) and 1 or -1
	local ext = 0
	for _, kind in ipairs({ "vuln", "ext_vuln" }) do
		for _, bx in ipairs(op.boxes and op.boxes[kind] or {}) do
			local l, r = SB.world_box(op.x, op.y, op.flip, bx)
			local e = (toward == 1) and (r - op.x) or (op.x - l)
			if e > ext then ext = e end
		end
	end
	mem.op_body = mem.op_body or {}
	if op.posture == 0 and not op.attacking and ext > 0 then
		mem.op_body[op.char_str] = math.max(mem.op_body[op.char_str] or 0, ext)
	end
	local base = mem.op_body[op.char_str]
	return base and math.max(0, ext - base) or 0
end

-- ¿el poke `anim` conecta YA contra las cajas vulnerables ACTUALES del rival (caminando walk_px antes)? Simula las cajas
-- de ataque de la frame data en sus frames activos. Para el whiff punish: la tabla de alcances mide contra el rival en
-- guardia y en la recuperación el cuerpo está en otro lado (far MK de Oro "llega a 151-159" y erraba a 118-136 px).
-- nil = sin datos (se usa la tabla)

-- diagnóstico de combos: daño esperado (laboratorio) vs daño real a los 120 frames
local function track_combo(mem, s, op, label)
	mem.cd = { frame = s.frame, label = label, hp = (op.hp == 255) and 0 or op.hp }
end

-- caminata a lazo cerrado: antes del PRIMER botón de un castigo con caminata se mira la distancia real; si el golpe
-- inicial todavía no llega, se sigue caminando (hasta `max` frames) o se aborta. Los castigos tras parry caminaban
-- la cuenta estimada y el cl.HP salía a 96-98 px (0 de 5 con daño vs Gouki); el Shin Shoryuken salía a 103-109 px
-- distancia máxima a la que un normal sale en su versión cercana (cl.*): el lab de combos verifica los cl. a 38-45 px
-- y desde ~58 ya salen lejanos
local CLOSE_MAX = 54
local function set_range_guard(mem, me, op, anim, max, fallback)
	local r = (anim and RG.reach(me.char_str, anim, op.char_str, op.crouching)) or fallback
	-- los cl.* solo salen de cerca (más lejos el juego hace el normal lejano, otro golpe): tope de distancia
	if r and anim and anim:match("^cl_") then r = math.min(r, CLOSE_MAX) end
	mem.range_guard = r and { reach = r + 4, extra = 0, max = max or 8 } or nil
end

-- devuelve un frame de input inmediato (prioritario sobre la cola) o nil
function B.think(ctx, s, me, op)
	local cfg, mem = ctx.cfg, ctx.mem
	local lat = ctx.latency or 0
	ctx.op_hp_now = (op.hp ~= 255) and op.hp or nil     -- para elegir el combo que MATA (plan_punish)
	ctx.op_now = op                                       -- cajas reales del rival para plan_punish
	mem.now_frame = s.frame
	if op.has_just_received_hit then mem.op_hit_at = s.frame end
	if me.has_just_hit then mem.my_hit_at, mem.my_hit_move = s.frame, me.move end
	-- dash-diag: ¿salió la animación de dash en los 14 frames siguientes? (FAIL = qué lo pisó)
	local dd = mem.dash_diag
	if dd and dd.frame > 0 then
		local mv = me.move or ""
		if mv:find("dash") then
			log.write("dash-diag OK %s af=%d", dd.label, s.frame - dd.frame)
			mem.dash_diag = nil
		elseif s.frame - dd.frame > 14 then
			log.write("dash-diag FAIL %s now=%s label=%s fz=%d blk=%s", dd.label, tostring(me.move), tostring(mem.label), me.freeze,
				tostring(me.is_blocking))
			mem.dash_diag = nil
		end
	end
	-- alcance REAL del agarre normal del rival contra mí (ranges.lua, cajas de effie), para no caminar adentro
	mem.thr_op = (RG.throw(op.char_str, me.char_str, me.crouching) or 72) + (CIPHER_EXT and 4 or 0)
	-- entorno leído de la RAM (state.world): una línea por round para verificar escenario / paredes / cámara
	-- verificación de paredes: x mínima / máxima a la que llegó cada uno en el round vs la pared calculada
	if me.wall_l and s.in_match and not (s.timer and s.timer >= 98) then
		local w = mem.wx or { me = { 9999, -9999 }, op = { 9999, -9999 } }
		w.me[1], w.me[2] = math.min(w.me[1], me.x), math.max(w.me[2], me.x)
		w.op[1], w.op[2] = math.min(w.op[1], op.x), math.max(w.op[2], op.x)
		w.wl, w.wr, w.owl, w.owr = me.wall_l, me.wall_r, op.wall_l, op.wall_r
		mem.wx = w
	end
	if s.timer and s.timer >= 98 then
		if mem.world_logged and mem.wx then
			local w = mem.wx
			log.write("world-check me x=%d..%d wall=%d..%d | op x=%d..%d wall=%d..%d", w.me[1], w.me[2], w.wl, w.wr,
				w.op[1], w.op[2], w.owl, w.owr)
		end
		mem.world_logged, mem.wx = false, nil
	end
	if not mem.world_logged and s.timer and s.timer <= 96 and me.wall_l then
		mem.world_logged = true
		log.write("world stage=%s(%s) screen_x=%s | me %s x=%d wall=%d..%d lim=%d..%d back=%d front=%d | op %s x=%d wall=%d..%d back=%d walk=%.2f",
			tostring(s.stage), tostring(s.stage_info and s.stage_info.name), tostring(s.screen_x), me.char_str, me.x,
			me.wall_l, me.wall_r, me.lim_l, me.lim_r, me.room_back, me.room_front, op.char_str, op.x, op.wall_l, op.wall_r,
			op.room_back, (me.phys and me.phys.fwd) or 0)
	end
	-- estado de la PELEA: rounds ganados (core/history, solo online), vidas, reloj. Lo usan el modo remate, el reloj y
	-- los reversals con super
	local hc = History.cur
	if hc and (hc.me ~= me.char_str or hc.op ~= op.char_str) then hc = nil end
	local rs = { w = hc and hc.w or 0, l = hc and hc.l or 0, timer = s.timer or 99,
		my_hp = (me.hp == 255) and 0 or me.hp, op_hp = (op.hp == 255) and 0 or op.hp }
	rs.match_pt_op = rs.l >= 1                               -- perder este round = perder la pelea
	rs.clock_win = rs.timer <= 12 and rs.my_hp > rs.op_hp + 4
	rs.clock_lose = rs.timer <= 20 and rs.my_hp + 4 < rs.op_hp
	ctx.rs = rs
	-- rival contra la pared en la dirección en que lo empujo: juggles de esquina habilitados (paredes ~108 / ~918)
	-- (paredes reales de la RAM: escenario + offset del personaje, state.world)
	Combos.corner_now = (op.stage_back or 999) < 60
	-- caminata real del personaje (Alex 2.5, Hugo 2.1, Dudley 3.75 px/frame): con 3.2 fijo los cálculos de caminata
	-- para castigar / buscar el combo quedaban cortos o largos
	WALK_SPEED = (me.phys and me.phys.fwd) or 3.2
	-- guardia por defecto de cipher.lua (sin decisión del brain) solo dentro del alcance del rival + margen: antes era
	-- a < 160 px siempre y con poca vida el bot vivía agachado tapándose aunque el rival estuviera lejos
	mem.guard_range = op_poke_reach(op, me) + 35
	-- tabla del personaje: se recarga al cambiar de personaje (online, Ken jugó con la tabla de Gouki de la pelea anterior)
	if not ctx.chars or ctx.chars_of ~= me.char_str then
		ctx.chars, ctx.chars_of = chars_table(me.char_str), me.char_str
	end
	local ch = ctx.chars
	local d = s.dist
	local op_dy = op.y - (mem.prev_op_y or op.y)
	mem.prev_op_y = op.y
	if mem.fireball_cd > 0 then mem.fireball_cd = mem.fireball_cd - 1 end
	if mem.aa_cd > 0 then mem.aa_cd = mem.aa_cd - 1 end
	track_habits(mem, s, me, op, ctx.side)
	limb_gain(mem, me, op)                         -- mantiene la medida del cuerpo del rival en neutral
	-- último frame con carga lista (para los confirms de combos de carga)
	if charged(ctx, "h") and ctx.charge then mem.charge_h_at = s.frame end
	if charged(ctx, "v") and ctx.charge then mem.charge_v_at = s.frame end
	learn_wake(mem, op)
	mem.prev_label = mem.label

	-- diagnóstico de agarres de comando: GRAB (agarró) / JUMPED (el 360 no salió y saltó) / MISS
	local gd = mem.grab_diag
	if gd then
		local out = (op.being_thrown and "GRAB") or (me.airborne and "JUMPED") or (s.frame - gd.frame > 30 and "MISS")
		if out then
			log.write("grab-diag %s %s d=%d op=%s", out, gd.label, gd.d, tostring(gd.op))
			local gname = gd.label:gsub(" %(rec %d+%)", ""):gsub("^punish ", ""):gsub("^post%-parry ", "")
			local gkey = "grab:" .. me.char_str .. ":" .. gname
			local gst = mem.parry_stats[gkey] or { ok = 0, fail = 0 }
			if out == "GRAB" then gst.ok = gst.ok + 1 else gst.fail = gst.fail + 1 end
			mem.parry_stats[gkey] = gst
			mem.learn_dirty = (mem.learn_dirty or 0) + 1
			mem.grab_diag = nil
		end
	end
	if mem.grab_pending then
		mem.grab_diag = { frame = s.frame, label = mem.grab_pending, d = d, op = op.move }
		mem.grab_pending = nil
	end

	-- diagnóstico de okizeme (cada frame): frame real en que el rival deja de estar tirado y resultado del meaty
	local od = mem.oki_diag
	if od then
		if not od.wake and not op.knocked_down then od.wake = s.frame end
		local out = (op.has_just_received_hit and "HIT") or (op.has_just_parried and "PARRIED")
			or (op.has_just_blocked_conn and "BLOCK") or (me.has_just_been_hit and "COUNTERED")
			or (s.frame - od.frame > 90 and "WHIFF")
		if out then
			log.write("oki-diag %s %s S=%s rem=%s k=%s press=%s wake=%s (wake-press=%s) hit-press=%s d=%s", out, od.poke,
				tostring(od.S), tostring(od.rem), tostring(od.k), tostring(od.frame), tostring(od.wake),
				od.wake and tostring(od.wake - od.frame) or "?", tostring(s.frame - od.frame), tostring(od.d))
			mem.oki_diag = nil
		end
	end
	if OKI_TRACE and (op.knocked_down or (mem.oki_trace_until and s.frame <= mem.oki_trace_until)) then
		if op.knocked_down then mem.oki_trace_until = s.frame + 6 end
		log.write("oki-trace move=%s af=%s synced=%s len=%s anim=%s posture=%s kd=%s fz=%s", tostring(op.move), tostring(op.anim_frame),
			tostring(op.anim_synced), op.fd and tostring(op.fd.len) or "-", tostring(op.anim), tostring(op.posture),
			tostring(op.knocked_down), tostring(op.freeze))
	end

	-- diagnóstico de golpes recibidos: qué me pegó, qué estaba haciendo yo y qué decidía la defensa (online solo hay
	-- una línea de estado cada 60 frames; sin esto no se puede saber por qué se pierde)
	-- solo golpes REALES: el chip de un especial bloqueado también suma al contador y se registraba como golpe (hoy:
	-- decenas de "golpes bloqueando" que eran chip de bolas / super bloqueados). Golpe real = 4+ de daño en los 3
	-- frames siguientes (el daño puede bajar un frame después del contador)
	local hp_now = (me.hp == 255) and 0 or me.hp
	if me.has_just_been_hit and not me.is_blocking and not mem.hd_pend then mem.hd_pend = { f = s.frame, hp = mem.prev_hp or hp_now } end
	mem.prev_hp = hp_now
	local hdp = mem.hd_pend
	if hdp and s.frame - hdp.f >= 3 then mem.hd_pend = nil end
	if hdp and s.frame - hdp.f >= 3 and hdp.hp - hp_now >= 4 then
		log.write("hit-diag op=%s af=%s d=%d my_move=%s posture=%s label=%s prev=%s effie=%s lat=%d air=%s op_air=%s in=%s",
			tostring(op.move), tostring(op.anim_frame), d, tostring(me.move), tostring(me.posture), tostring(mem.label),
			tostring(mem.prev_label), tostring(ctx.effie), lat, tostring(me.airborne), tostring(op.airborne),
			table.concat(ctx.hist or {}, " "))
	end

	-- diagnóstico de golpes al aire: cada ataque mío que termina sin pegar, sin ser bloqueado/parreado y sin agarrar
	if me.attacking and not mem.att then
		mem.att = { move = me.move, label = mem.label, d = d, conn = false, op = op.move, opp = op.posture, opaf = op.anim_frame }
	end
	if mem.att then
		if op.has_just_received_hit or op.has_just_blocked_conn or op.has_just_parried or op.being_thrown
			or op.is_blocking then mem.att.conn = true end
		-- proyectil propio en pantalla: la bola pega después de que termina la animación (no es golpe al aire)
		for _, pr in ipairs(s.proj or {}) do if pr.emitter == ctx.side then mem.att.conn = true end end
		if not me.attacking then
			if not mem.att.conn then
				log.write("whiff-diag move=%s label=%s d=%d op=%s op_post=%s op_af=%s", tostring(mem.att.move), tostring(mem.att.label),
					mem.att.d, tostring(mem.att.op), tostring(mem.att.opp), tostring(mem.att.opaf))
			end
			mem.att = nil
		end
	end

	if mem.cd and s.frame - mem.cd.frame >= 120 then
		local now = (op.hp == 255) and 0 or op.hp
		local got = math.max(0, mem.cd.hp - now)
		log.write("combo-diag %s got=%d", mem.cd.label, got)
		-- aprender el margen de rollback de esta conexión: castigo que no pegó -> más margen; que pegó -> afinar
		if CIPHER_EXT and mem.cd.label:find("^punish") then
			-- tope 6: los castigos también fallan por otras causas (rango, combo) y el margen subía a 8-10 hasta no
			-- castigar nada
			B.punish_margin = (got == 0) and math.min(6, B.punish_margin + 1) or math.max(2, B.punish_margin - 0.5)
			log.write("punish-margin %.1f", B.punish_margin)
		end
		-- aprendizaje por castigo PROPIO: cuáles de mis castigos pegan de verdad (online: cr.HP de castigo 62-74% sin
		-- daño, whiff cr.MK 5-7%). Clave mypunish:<char>:<castigo sin anotaciones>
		local lbl = mem.cd.label or ""
		if lbl:find("^punish ") or lbl:find("^post%-parry ") then
			local nm = lbl:gsub("^punish ", ""):gsub("^post%-parry ", ""):gsub(" %[%d+%].*", ""):gsub(" %(.*", "")
			local mk = "mypunish:" .. me.char_str .. ":" .. nm
			local ms = mem.parry_stats[mk] or { ok = 0, fail = 0 }
			if got == 0 then ms.fail = ms.fail + 1 else ms.ok = ms.ok + 1 end
			mem.parry_stats[mk] = ms
		end
		-- aprendizaje por golpe del rival: castigos que no pegan contra ese movimiento (cancelable / seguro de verdad)
		if mem.cd.pkey then
			local st = mem.parry_stats[mem.cd.pkey] or { ok = 0, fail = 0 }
			if got == 0 then st.fail = st.fail + 1 else st.ok = st.ok + 1 end
			mem.parry_stats[mem.cd.pkey] = st
			mem.learn_dirty = (mem.learn_dirty or 0) + 1
			if mem.learn_dirty >= 10 then save_learned(mem.parry_stats) mem.learn_dirty = 0 end
		end
		mem.cd = nil
	end

	-- diagnóstico de parry: resultado de cada intento
	local pp = mem.pending_parry
	if pp then
		local outcome
		if me.is_parrying then outcome = "PARRIED"
		elseif me.has_just_been_hit then outcome = "HIT"
		elseif me.is_blocking then outcome = "BLOCKED"
		elseif s.frame - pp.frame > 15 then outcome = "NO-HIT" end
		if outcome then
			log.write("parry-diag %s k=%d move=%s dt=%d op_af=%d", outcome, pp.k, tostring(pp.move), s.frame - pp.frame, pp.af)
			-- aprendizaje por golpe: tasa de éxito del parry contra cada animación del rival
			local key = op.char_str .. ":" .. tostring(pp.move)
			local st = mem.parry_stats[key] or { ok = 0, fail = 0 }
			if outcome == "PARRIED" then st.ok = st.ok + 1 elseif outcome == "HIT" then st.fail = st.fail + 1 end
			mem.parry_stats[key] = st
			mem.learn_dirty = (mem.learn_dirty or 0) + 1
			if mem.learn_dirty >= 10 then save_learned(mem.parry_stats) mem.learn_dirty = 0 end
			mem.pending_parry = nil
		end
	end

	-- resultado del tech: si a los 90 frames perdí vida, el agarre entró (FAILED); si no, TECHED
	local td = mem.tech_diag
	if TECH_TRACE and td and s.frame - td.frame <= 6 then
		local q = ctx.queue.q[1]
		log.write("tech-trace +%d being_thrown=%s q1=%s lp=%s lk=%s qlen=%d label=%s", s.frame - td.frame, tostring(me.being_thrown),
			q and "frame" or "-", q and tostring(q.lp) or "-", q and tostring(q.lk) or "-", #ctx.queue.q, tostring(mem.label))
	end
	-- 240 f: el agarre adelante de Urien hace el daño a los ~200 frames (con 90 lo marcaba TECHED y entraba)
	if td and s.frame - td.frame >= 240 then
		local hp = (me.hp == 255) and 0 or me.hp
		log.write("tech-result %s op=%s dmg=%d cd=%d", (hp < td.hp) and "FAILED" or "TECHED", tostring(td.op), td.hp - hp, td.cd)
		mem.tech_diag = nil
	end
	-- 0') TECH POR RADAR: el rival APRETÓ LP+LK a distancia de agarre (input de la RAM, state.radar). El agarre normal
	--     arranca en 3f y conecta ~2-3f después del botón; el tech vale si LP+LK se aprieta en los 5f desde que conecta
	--     (wiki System). 2 frames neutrales (pulsación nueva) + LP+LK 3f: cae en la ventana aunque el input del rival
	--     llegue hasta 2f tarde por el rollback. Antes se esperaba a "me agarró" + 2 neutrales: online 2 TECHED de 18
	if op.tech_at == s.frame and d <= (mem.thr_op or 72) + 8 and not op.airborne and not me.airborne
		and not me.attacking and not me.knocked_down and (mem.rtech_at or -99) < s.frame - 10 then
		mem.rtech_at = s.frame
		push(ctx, { { hold = 2 }, { lp = true, lk = true, hold = 3 }, { hold = 1 } }, "throw tech (radar)")
		mem.committed = true
		return nil
	end
	-- 0) me agarraron: tech inmediato
	if me.has_just_been_thrown then
		-- pulsación NUEVA de LP+LK en la ventana de 5 frames. Ya la apretó el tech por radar: no repetir. Si NO vengo
		-- apretando LP/LK, ya mismo (antes 2 frames neutrales siempre: llegaba tarde online); si sí, 1 neutral
		local holding = me.inp and (me.inp.lp or me.inp.lk)
		if (mem.rtech_at or -99) >= s.frame - 6 then
			mem.committed = true
		else
			push(ctx, holding and { { hold = 1 }, { lp = true, lk = true, hold = 3 }, { hold = 1 } }
				or { { lp = true, lk = true, hold = 3 }, { hold = 1 } }, "throw tech")
		end
		mem.committed = true
		log.write("tech-diag thrown: throw_countdown=%d op=%s my_post=%02x my_att=%s my_move=%s blk=%s prev=%s",
			me.throw_countdown, tostring(op.move), me.posture, tostring(me.attacking), tostring(me.move),
			tostring(me.is_blocking), tostring(mem.prev_label))
		mem.tech_diag = { frame = s.frame, hp = (me.hp == 255) and 0 or me.hp, op = op.move, cd = me.throw_countdown }
		return nil
	end
	if me.has_just_been_hit then ctx.queue:clear() mem.label = "hit" end

	-- 0b) estoy mareado: machacar diagonales (+ botones mientras falte) para bajar el timer de stun
	--     (effie: diagonal -3 por input, todos los botones -4 más). Cerca del final solo direcciones.
	if me.is_stunned then
		-- MACHACAR COMO UN HUMANO: antes cambiaba de diagonal cada frame y apretaba los 6 botones cada 2 frames (30 por
		-- segundo, ritmo perfecto) -> Fightcade lo marcaba como TURBO a los rivales. Ahora ~10-12 por segundo, con
		-- intervalos irregulares (4-7 frames botones, 3-6 frames cada diagonal) y no siempre los 6 botones
		ctx.queue:clear()
		mem.label = "mash (stun " .. me.stun_timer .. ")"
		if not mem.mash_dir_t or s.frame >= mem.mash_dir_t then
			mem.mash_dir = ((mem.mash_dir or 0) % 4) + 1
			mem.mash_dir_t = s.frame + math.random(3, 6)
		end
		local i = mem.mash_dir
		local f = (i == 1 and { up = true, fwd = true }) or (i == 2 and { down = true, back = true })
			or (i == 3 and { up = true, back = true }) or { down = true, fwd = true }
		if me.stun_timer > 20 then
			if not mem.mash_btn_t or s.frame >= mem.mash_btn_t then
				mem.mash_btn_t = s.frame + math.random(4, 7)
				mem.mash_btn_on = s.frame + 1                         -- botones apretados 2 frames
				mem.mash_btns = { lp = math.random() < 0.8, mp = math.random() < 0.7, hp = math.random() < 0.8,
					lk = math.random() < 0.8, mk = math.random() < 0.7, hk = math.random() < 0.8 }
			end
			if s.frame <= (mem.mash_btn_on or -1) then
				for k, v in pairs(mem.mash_btns) do f[k] = v end
			end
		end
		return f
	end

	-- tech anticipado ("option select"): reaccionar al agarre online llega tarde (rollback: throw_countdown=0 al
	-- detectarlo, 15 agarres de Alex). En los momentos típicos de agarre apretar LP+LK: si agarra, techea; si no,
	-- pegado al rival es MI agarre. a) al salir del bloqueo (tick throw) b) al levantarme con el rival encima.
	local GRAPPLERS = { alex = true, hugo = true }
	local throw_risk = GRAPPLERS[op.char_str] or (mem.thrown_recent or 0) >= 1
	-- wiki System: 6 frames de protección de agarre al salir del bloqueo / al levantarse; el tech vale 5 frames desde
	-- que conecta. Apretar al +9 cubre los agarres que conectan del +5 al +9 (el tick throw más rápido). Mientras
	-- espera sostiene guardia atrás (de pie: agachado LP+LK no es agarre y no techea).
	-- crouch tech (wiki Chun-Li): abajo-atrás + LP+LK = cr.LP si no te agarran, tech si te agarran. Más seguro que el
	-- agarre de pie (si no conecta, 24f de recuperación).
	local function tech_os_seq(wait)
		return { { back = true, down = true, hold = math.max(1, wait - lat) }, { back = true, down = true, lp = true, lk = true, hold = 2 },
			{ back = true, down = true, hold = 2 } }
	end
	if mem.was_blocking and not me.is_blocking and d < 58 and not op.airborne and throw_risk
		and not ctx.queue:busy() and math.random() < 0.6 then
		push(ctx, tech_os_seq(9), "tech OS (fin de bloqueo)")
		mem.committed = true
		mem.was_blocking = me.is_blocking
		return nil
	end
	mem.was_blocking = me.is_blocking
	-- c) rival entrando caminando / con dash al rango de agarre y ya me agarró antes: tech por adelantado. Online
	--    el agarre se ve con la ventana de tech ya vencida (throw_countdown=0 SIEMPRE): de reacción no se escapa
	--    ninguno (Oro vs Urien: todos los agarres entraron caminando a 46-62 px)
	local walking_in = op.move == "walk_forward" or op.move == "dash_forward"
	local nthrow_op = RG.throw(op.char_str, me.char_str, me.crouching) or 80
	-- rival que agarra mucho (2+ en 30 s, Urien: 6 agarres adelante = su combo clásico): tech anticipado también con
	-- el rival quieto pegado, no solo entrando
	local close_still = (mem.thrown_recent or 0) >= 2 and d < nthrow_op and not op.attacking and not op.airborne
	-- vs rival que parrea (2+): el cr.LP del tech OS se lo parrean y castigan (Urien: 3 de 10 parries fueron al tech
	-- OS) -> solo si además agarra seguido
	local parry_happy = (mem.op_parry_recent or 0) >= 2
	if (walking_in or close_still) and d < nthrow_op + 10 and (mem.thrown_recent or 0) >= (parry_happy and 2 or 1) and can_act(me)
		and not ctx.queue:busy() and (mem.tech_walk_cd or 0) <= s.frame
		and math.random() < (walking_in and 0.6 or (((mem.thrown_recent or 0) >= 3) and 0.6 or 0.35)) then
		-- agarrador serial (Urien: 7 agarres adelante en una pelea): más seguido y con menos espera entre techs
		mem.tech_walk_cd = s.frame + (((mem.thrown_recent or 0) >= 3) and 25 or 45)
		push(ctx, tech_os_seq(1), "tech OS (entra caminando)")
		mem.committed = true
		return nil
	end
	-- reversal EX al levantarse (EX DP / EX Kazekiri / EX Jet Upper...: invulnerables): con barra y el rival encima,
	-- a veces en lugar de bloquear. El input se completa justo al pararse (buffer de reversal).
	-- reversal con SUPER invencible al levantarse cuando el super suelto MATA (antes el bot perdía rounds tirado con
	-- la barra llena y el rival a 30 de vida). Más seguido si me queda poca vida (el siguiente golpe me mata igual)
	local rsup = REV_SUPER[me.char_str] and REV_SUPER[me.char_str][me.sa]
	if me.knocked_down and rsup and me.meter >= 1 and d < 100 and not mem.wake_rev_done and rs.op_hp > 0 then
		local est = raw_super_dmg(me.char_str, me.sa)
		local sq = (est and rs.op_hp <= est) and super_frames(me.char_str, me.sa) or nil
		local rem_me = wake_remaining(me)
		if sq and rem_me and rem_me <= seq_len(sq) + lat then
			mem.wake_rev_done = true
			if math.random() < ((rs.my_hp <= 35 or rs.match_pt_op) and 0.7 or 0.45) then
				push(ctx, sq, string.format("wakeup: super que MATA (rival %d, super ~%d)", rs.op_hp, est))
				track_combo(mem, s, op, "wakeup super")
				mem.committed = true
				return nil
			end
		end
	end
	local rv = ch.reversal
	if me.knocked_down and rv and not rv.charge and me.meter >= 1 and d < 110 and not mem.wake_rev_done then
		local rem_me = wake_remaining(me)
		local n = seq_len(rv.seq())
		if rem_me and rem_me <= n + lat then
			mem.wake_rev_done = true
			if math.random() < 0.3 then
				push(ctx, rv.seq(), "reversal " .. rv.name)
				mem.committed = true
				return nil
			end
		end
	end
	if not me.knocked_down then mem.wake_rev_done = false end
	-- vs grappler el tech OS al levantarse va siempre y con más distancia (el agarre de Hugo llega lejos)
	if me.knocked_down and d < (GRAPPLERS[op.char_str] and 110 or 70) and throw_risk and not mem.wake_os then
		local rem_me = wake_remaining(me)
		if rem_me and rem_me <= 1 + lat then
			mem.wake_os = true
			-- vs grappler el agarre de comando al levantarse (Power Bomb / 360) no se techea: mezclar tech (agarre normal),
			-- salto atrás (le gana a cualquier agarre) y reversal con barra
			local rvw = ch.reversal
			local wv = GRAPPLERS[op.char_str] and pick({ { 4, "tech" }, { mem.sbb_at and 0 or 3, "jump" },
				{ (rvw and not rvw.charge and me.meter >= 1) and 3 or 0, "rev" } }) or "tech"
			if wv == "jump" then
				push(ctx, { { back = true, down = true, hold = math.max(1, rem_me - lat) }, { up = true, back = true, hold = 3 }, { hold = 30 } }, "wakeup: salto atrás")
			elseif wv == "rev" then
				push(ctx, rvw.seq(), "wakeup: reversal " .. rvw.name)
			else
				push(ctx, tech_os_seq(rem_me + 9), "tech OS (wakeup)")
			end
			mem.committed = true
			return nil
		end
	end
	-- quick stand (wiki System): tocar abajo apenas toco el piso -> me paro antes y rompo el okizeme del rival.
	-- Mezclado (75%) para no ser predecible. No funciona tras supers ni algunos golpes (no pasa nada si falla).
	if me.knocked_down and not mem.kd_seen then
		mem.kd_seen = true
		-- online 40%: el quick stand predecible abrió 27 combos (el humano lo espera con un meaty)
		-- nunca vs grappler: el quick stand le regala el timing exacto del agarre al levantarse (Hugo: 5 agarres justo
		-- después del quick stand). Levantándose normal, el tech OS de wakeup lo cubre
		if not GRAPPLERS[op.char_str] and math.random() < (CIPHER_EXT and 0.4 or 0.75) then
			push(ctx, { { down = true, hold = 3 } }, "quick stand")
			mem.committed = true
			return nil
		end
	end
	if not me.knocked_down then mem.kd_seen = false end
	if not me.knocked_down then mem.wake_os = false end

	-- throw tech anticipado: el rival arranca una animación de agarre cerca mío
	-- DESACTIVADO: apretar LP+LK al ver la animación de agarre del rival salía como Shoryuken (el buffer tenía
	-- adelante/abajo/abajo-adelante de caminar y agacharse) y el agarre entraba igual. Ahora: tech limpio a +3.
	if false and op.move and op.move:find("throw") and op.anim_frame <= 3 and s.dist < 90
		and not mem.teching and (can_act(me) or me.is_blocking) then
		mem.teching = true
		push(ctx, ch.tech(), "tech (anticipado) vs " .. op.move)
		mem.committed = true
		return nil
	end
	if not (op.move and op.move:find("throw")) then mem.teching = false end

	-- 1) secuencia comprometida (special/combo en curso): no la rompas
	local rgd = mem.range_guard
	if rgd and ctx.queue:busy() then
		local f = ctx.queue.q[1]
		if f.lp or f.mp or f.hp or f.lk or f.mk or f.hk then
			if s.dist <= rgd.reach then
				mem.range_guard = nil                 -- en rango: sigue el combo
			elseif rgd.extra < rgd.max and not op.airborne then
				rgd.extra = rgd.extra + 1
				table.insert(ctx.queue.q, 1, { fwd = true })
			else
				log.write("range-guard ABORT %s d=%d reach=%d", tostring(mem.label), s.dist, rgd.reach)
				ctx.queue:clear()
				mem.range_guard, mem.committed = nil, false
				mem.cd = nil          -- abortado sin pegar: no cuenta como castigo fallido (apagaba castigos por aprendizaje)
			end
		end
	elseif rgd and not ctx.queue:busy() then
		mem.range_guard = nil
	end
	if ctx.queue:busy() and mem.committed then return nil end
	mem.committed = false

	-- 1b) hit-confirm real: mi poke conectó (RAM) y la ventana medida por el laboratorio todavía alcanza
	if mem.confirm then
		-- el starter sale cuando arranca de verdad el ataque (la caminata a lazo cerrado del range guard lo atrasa: el
		-- confirm contaba desde el plan y llegaba con now=24-28, fuera de la ventana)
		if me.has_just_attacked and not mem.confirm.synced and s.frame >= mem.confirm.start - 2 then
			mem.confirm.start, mem.confirm.synced = s.frame, true
		end
		local now = s.frame - mem.confirm.start
		-- poke BLOQUEADO con cancel seguro del personaje (Ryu: cr.MK/st.MP/cr.MP xx EX Hadouken, seguro en bloqueo y parry)
		local bc = ch.block_cancel
		if bc and op.has_just_blocked_conn and me.move and bc.from[me.move] and me.meter >= (bc.meter or 0)
			and not (bc.no_sa and bc.no_sa[me.sa])
			and math.random() < (bc.rate or 0.4) then
			mem.confirm = nil
			push(ctx, bc.seq(), "block cancel " .. bc.name)
			mem.committed = true
			return nil
		end
		if now > 45 then
			mem.confirm = nil
		-- golpe PARREADO no es golpe: confirmar al super después de un parry es regalarle el castigo (Urien parreó el
		-- cr.MP y el bot siguió con 2MP xx SA)
		-- golpe REAL (el contador de golpes recibidos del rival sube), no bloqueado: has_just_hit sube también con un golpe
		-- bloqueado y el super salía contra la guardia (cl.MP xx SA got=1, 2MK xx SA got=0: Shippu bloqueado, barra tirada)
		elseif (mem.my_hit_at or -99) >= s.frame - 2 and (mem.my_hit_at or -99) >= mem.confirm.start and me.move
			and (mem.op_hit_at or -99) >= s.frame - 2 and not op.has_just_parried and not ((mem.op_parry_at or -99) >= s.frame - 2)
			and not op.is_blocking and not op.has_just_blocked_conn then
			-- carga lista justo antes del golpe que conectó (Oro agachado cargando -> cl.MK xx Oniyanma)
			local st0 = mem.confirm.start
			local chg = { h = mem.charge_h_at and st0 - mem.charge_h_at <= 6, v = mem.charge_v_at and st0 - mem.charge_v_at <= 6 }
			local e, seq = Combos.best_confirm(me.char_str, mem.my_hit_move or me.move, me.meter, now, lat, s.dist, me.sa, chg,
				is_proj_super(me) or (is_rush_super(me) and s.dist <= 125), (op.hp == 255) and nil or op.hp)
			mem.confirm = nil
			if not e then
				-- golpe que conectó sin continuación verificada (para ver qué rutas faltan)
				log.write("confirm-miss move=%s d=%d meter=%d op_hp=%d now=%d label=%s", tostring(me.move), s.dist, me.meter,
					rs.op_hp, now, tostring(mem.label))
			end
			if e then
				push(ctx, seq, string.format("confirm %s [%d]", e.label, e.dmg))
				track_combo(mem, s, op, mem.label)
				mem.committed = true
				mem.busy_until = s.frame + #seq + 25
				return nil
			end
		end
	end

	-- 2) anti-air
	local approaching = (op.x - me.x) * (op.vx * (op.flip == 1 and 1 or -1)) < 0 or d < 60
	-- solo SALTOS (jump_*, sjump_*, u*/uf*/ub* = golpes de salto, *_air): los especiales en el aire (tatsumaki, hyakki,
	-- kunai...) no son jump-ins. Vs el tatsu HK de Ken (9 golpes, medio) el bot tiraba Jet Upper entre golpe y golpe
	-- y se comía el resto: 6 anti-airs al aire y ~20 golpes recibidos en un round
	local mvj = op.move or ""
	local jumping = mvj == "" or mvj:find("jump") or mvj:match("^u[fb]?_") or mvj:find("_air") or mvj:find("air_")
		or mvj:find("recovery")
	-- el tatsu aéreo (tatsumaki_air de Gouki / Ken) es especial, no salto; el super salto cae más lejos de lo que
	-- predice el arco normal: anti-air solo si ya está encima (Oro: 6 anti-airs al aire contra sjump a 68-93 px)
	if mvj:find("tatsumaki") or (mvj:find("sjump") and d > 60) then jumping = false end
	local aa_zone = op.airborne and jumping and op.y > 15 and d < 125 and approaching
	-- ataque aéreo predicho que conecta pronto (los u_HP/u_HK de Gill entraban antes de que empiece a bajar)
	local air_th = aa_zone and P.melee(me, op)
	-- online el rollback muestra el ataque de salto cuando ya pega (117 jump-ins entraron con "block high" y 3 de Ryu
	-- sin intentar anti-air): decidir por la TRAYECTORIA (vel + acel de la RAM), antes de que apriete el botón
	local arr, arr_dx = nil, nil
	if aa_zone then arr, arr_dx = air_arrival(me, op) end
	local aa_need = 0
	if CIPHER_EXT and arr then
		local a1 = ch.antiair[1]
		aa_need = (a1 and (seq_len(a1.seq()) + (a1.startup or 4)) or 8) + lat + math.floor(B.punish_margin / 2)
	end
	-- llegada a < 70 px (antes 90) y el rival YA cerca (d < 110): Gouki tiraba goshoryuken a Hugo a 94-161 px
	local early = CIPHER_EXT and arr and arr_dx < 70 and d < 110 and arr <= aa_need + 1 and arr >= aa_need - 4
	if aa_zone and mem.aa_cd == 0 and can_act(me) and not mem.parry_until
		and (early or (op_dy <= 0 and d < 115 and op.y < 120) or (air_th and air_th.frames <= 10 and air_th.frames >= 3))
		and math.random() < (cfg.antiair_rate or 0.9) then
		-- anti-air por geometría: cada entrada puede traer dx = {min, max} (distancia horizontal al llegar). Ryu: cr.HP
		-- con el rival casi encima, st.LP/cl.LP en el resto (wiki Ryu/Strategy). El primero elegible al 70%
		local adx = arr_dx or d
		local elig = {}
		for _, x in ipairs(ch.antiair) do
			if not x.dx or (adx >= x.dx[1] and adx <= x.dx[2]) then elig[#elig + 1] = x end
		end
		local aa = (#elig > 0) and ((math.random() < 0.7 or #elig == 1) and elig[1] or elig[math.random(2, #elig)]) or nil
		-- el rival me parrea el anti-air: humanos buenos parrean el DP/Jet Upper que repetimos (10 parreados en 12
		-- peleas, la mayoría por trayectoria = timing fijo). Con 1 parreado en 90 s el especial sale al 40%, con 2+ al 10%;
		-- si no, un anti-air NORMAL (un solo botón) o nada este salto: parry aéreo propio / guardia / salir caminando
		local par = recent(mem.aa_parried or {}, s.frame, 5400)
		local function is_normal(x) return #x.seq() == 1 end
		if par >= 1 and aa and not is_normal(aa) and math.random() > ((par >= 2) and 0.1 or 0.4) then
			local alt = nil
			for _, x in ipairs(ch.antiair) do if is_normal(x) then alt = x end end
			aa = alt
			if not aa then
				mem.aa_cd = 40                        -- este salto no: lo resuelve el parry aéreo / la guardia
				mem.air_parry_boost = s.frame + 40
			end
		end
		local sp = ch.antiair_special
		if sp and charged(ctx, sp.charge) and par == 0 and (math.random() < 0.8 or not aa) then aa = sp end
		if aa then                                   -- sin anti-air: lo resuelve la defensa (parry/bloqueo alto)
			push(ctx, aa.seq(), "anti-air " .. aa.name .. (early and " (trayectoria)" or ""))
			mem.committed, mem.aa_cd = true, 30
			-- anti-air normal que pega: confirm (Ryu cl.LP, SA2 de la wiki)
			if #aa.seq() == 1 then mem.confirm = { start = s.frame } end
			return nil
		end
	end
	-- 2a) guardia aérea anticipada (online): el rival cae sobre mí y no hubo anti-air -> parado bloqueando YA, sin
	--     esperar a ver el botón (que llega tarde). Atrás según la posición lo resuelve cipher.lua (crossups).
	-- el ataque de salto conecta alto (y ~90 -> 50); la ventana del parry anti-aéreo es de solo 5f (wiki System):
	-- tocar cuando llega a y 90 (1 HIT con dt=1 apuntando a y 60)
	local parr = aa_zone and air_arrival(me, op, 90) or nil
	-- parry aéreo anticipado por trayectoria: el toque adelante abre ~10 frames de parry; tocarlo ~5 frames antes de
	-- que llegue a la altura de golpe cubre el botón aunque el rollback lo muestre tarde (0 intentos de parry vs los
	-- saltos de Alex: la guardia aérea iba antes y el parry de reacción nunca llegaba)
	if CIPHER_EXT and arr and arr_dx < 100 and not me.airborne and can_act(me) and (s.frame - mem.last_parry) > 24
		and not mem.parry_until
		and parr and parr >= 1 + lat and parr <= 3 + lat and not (ctx.queue:busy() and mem.committed)
		and math.random() < (((mem.air_parry_boost or 0) > s.frame) and 0.9 or (cfg.air_parry_rate or 0.6)) then
		local st = mem.parry_stats[op.char_str .. ":air_pre"]
		if not (st and st.fail >= 3 and st.fail > 2 * st.ok) then
			mem.last_parry = s.frame
			mem.pending_parry = { frame = s.frame, k = parr, move = "air_pre", af = op.anim_frame }
			mem.parry_tap_frame = s.frame + 1
			mem.parry_dir = "high"
			mem.parry_until = s.frame + 1 + (cfg.parry_window or 9)
			ctx.queue:clear()
			mem.label = "parry aéreo (trayectoria)"
			return {}
		end
	end
	if CIPHER_EXT and arr and arr_dx < 100 and arr <= 18 and not me.airborne and (can_act(me) or me.is_blocking)
		and not mem.parry_until
		and not (ctx.queue:busy() and mem.committed) then
		ctx.queue:clear()
		mem.label = "guardia aérea"
		return { back = true }
	end

	-- 2a'') JUGGLE: el rival quedó en el aire por un golpe MÍO (no saltó él): mientras cae, volver a pegarle con el
	--       anti-air normal más rápido que llegue, sin dejarlo tocar el piso. Los humanos buenos lo hacen; el bot
	--       terminaba el combo y lo dejaba caer
	if op.has_just_received_hit and op.airborne then mem.juggle_until = s.frame + 45 end
	if mem.juggle_until and s.frame < mem.juggle_until and op.airborne and not op.knocked_down and op.y > 8 and op.y < 90 and op_dy <= 0
		and can_act(me) and not op.has_just_parried and (mem.juggle_cd or 0) <= s.frame then
		local jn
		for _, x in ipairs(ch.antiair or {}) do
			if #x.seq() == 1 and (not x.dx or (d >= x.dx[1] and d <= x.dx[2] + 10)) and d < 95
				and (not jn or (x.startup or 9) < (jn.startup or 9)) then jn = x end
		end
		if jn then
			mem.juggle_cd = s.frame + 20
			push(ctx, jn.seq(), "juggle " .. jn.name)
			mem.committed = true
			mem.confirm = { start = s.frame }
			return nil
		end
	end

	-- 2a') Aegis Reflector de Urien (SA3, la pantalla eléctrica): encierra contra la pared y deja al bot entre la
	--      pantalla y Urien (no se puede bloquear de los dos lados). Mientras dura (~2.5 s) y estoy cerca de la pared o
	--      de Urien: SALIR por encima (salto adelante) o pasando por adelante, nunca quedarse bloqueando adentro
	if (op.move or ""):find("^aegis") then mem.aegis_until = s.frame + 150 end
	if mem.aegis_until and s.frame < mem.aegis_until and can_act(me) and not me.airborne
		and (mem.aegis_cd or 0) <= s.frame then
		local wall_room = me.room_back or ((op.x > me.x) and (me.x - 108) or (918 - me.x))
		if wall_room < 140 or d < 90 then
			mem.aegis_cd = s.frame + 40
			if math.random() < 0.7 then
				push(ctx, { { up = true, fwd = true, hold = 3 }, { hold = 30 } }, "escapa del aegis (salto)")
			else
				push(ctx, MOVES.dash(), "escapa del aegis (dash)")
			end
			mem.committed = true
			return nil
		end
	end

	-- 2b) agarre de comando (Karakusa, Moonsault...): interrumpir con el normal más rápido o saltar atrás
	local cg = P.command_grab(op)
	if cg and d < 120 and can_act(me) and not mem.cg_done then
		mem.cg_done = true
		local jab
		for _, n in ipairs(ch.normals or {}) do
			if n.reach + 26 >= d and (not jab or n.startup < jab.startup) then jab = n end
		end
		-- el jab llegaba a tiempo y aun así entraban los Karakusa (3/3): prioridad al salto atrás,
		-- jab solo si no hay tiempo de despegar
		if cg >= (cfg.grab_jump_min or 5) then
			push(ctx, { { up = true, back = true, hold = 4 } }, "anti-grab jump vs " .. op.move)
		elseif jab and jab.startup + lat + 1 < cg then
			local dirs = {}
			for k2, v in pairs(jab.dirs) do dirs[k2] = v end
			push(ctx, input_lib.motion.press(jab.btn, dirs, 2), "anti-grab " .. jab.name .. " vs " .. op.move)
		else
			push(ctx, { { up = true, back = true, hold = 4 } }, "anti-grab jump vs " .. op.move)
		end
		mem.committed = true
		log.write("grab-diag %s k=%d d=%d -> %s", op.move, cg, d, mem.label)
		return nil
	end
	if not cg then mem.cg_done = false end

	-- 3) defensa: parry / bloqueo
	local th = P.threat(s, me, op)
	-- para cipher.lua: no forzar la guardia de effie agachada si lo que viene es un overhead (f.HP de Urien entraba)
	mem.th_over = (th and th.overhead and not th.air) and s.frame or mem.th_over
	-- ventana de parry abierta: palanca neutral hasta que el parry salga o la amenaza pase
	-- (volver a "atrás" convierte el parry en bloqueo: 72/102 intentos en la primera eval)
	-- el parry exige una pulsación NUEVA: 1 frame neutral y luego el toque (si venía agachado o caminando,
	-- la dirección ya estaba sostenida y no había flanco: 49 golpes recibidos / 3 parries en la eval 2)
	if mem.parry_until then
		if me.is_parrying or s.frame > mem.parry_until then
			if me.is_parrying then mem.last_parry = -999 end   -- parry exitoso: se puede volver a parrear ya (multi-hit)
			mem.parry_until = nil
		-- toque de 2 frames: con SendInput (online) un toque de 1 frame puede caer entre dos lecturas del emulador y
		-- perderse (parries "HIT" con el golpe dentro de la ventana). Sigue contando como "soltado rápido" (10f)
		elseif s.frame >= mem.parry_tap_frame and s.frame <= mem.parry_tap_frame + 1 then
			return mem.parry_dir == "low" and { down = true } or { fwd = true }
		else
			return {}
		end
	end
	-- castigo post-parry: al terminar el hitstop del parry, mejor castigo en rango
	-- (sin esto, vs Makoto: 48 parries y 0 castigos en la eval arcade)
	if me.has_just_parried then
		mem.pp_frame, mem.pp_air, mem.pp_move = s.frame, op.airborne, op.move
		ctx.queue:clear()
		log.write("pp-start myfz=%d opfz=%d op=%s af=%d rec_end=%s dist=%d", me.freeze, op.freeze, tostring(op.move),
			op.anim_frame, op.fd and tostring(FD.recovery_end(op.fd)) or "?", d)
	end
	if mem.pp_frame and mem.pp_trace and s.frame - mem.pp_frame <= 24 then
		log.write("pp-trace +%d myfz=%d opfz=%d op_af=%d op_att=%s me_att=%s post=%02x",
			s.frame - mem.pp_frame, me.freeze, op.freeze, op.anim_frame, tostring(op.attacking), tostring(me.attacking), me.posture)
	end
	-- el golpe parreado tiene más golpes por delante (overhead f.MP de Gouki: 2 golpes): no castigar todavía, la
	-- defensa sigue (Ibuki parreaba el 1º, salía a castigar y se comía el 2º: 4 post-parry con 0 de daño)
	local more_hits = false
	if op.fd and op.fd.hit then
		for _, h in ipairs(op.fd.hit) do if h[1] > op.anim_frame then more_hits = true end end
	end
	if mem.pp_frame then
		if s.frame - mem.pp_frame > 45 then
			log.write("pp-skip op=%s d=%d fz=%d att=%s th=%s (se pasó la ventana)", tostring(mem.pp_move), d, me.freeze,
				tostring(me.attacking), th and tostring(th.move) or "-")
			mem.pp_frame = nil
		elseif more_hits then
			-- esperar: el parry del siguiente golpe (o el bloqueo) vuelve a armar mem.pp_frame
		-- la "amenaza" que ve el predictor suele ser el MISMO golpe parreado (sus cajas siguen activas unos frames): no
		-- frena el castigo. Antes 12 de 90 parries online se castigaban; esperaba hasta que se pasaba la ventana
		elseif me.freeze == 0 and not me.attacking and me.hp ~= 255
			and (not th or th.frames - lat > 6 or (th.move == mem.pp_move and th.kind ~= "proj")) then
			local seq, name, st_anim, st_reach
			-- solo si de verdad está en el aire (la ráfaga de Q contaba como "en el aire": st.LP al aire 3 veces)
			if (mem.pp_air or op.airborne) and op.y > 20 then
				-- solo si está al alcance (post-parry Dragon Smash a 146 px de una bola aérea pegaba al aire)
				local aa = ch.antiair_special or ch.antiair[2]
				if aa and d < 90 then seq, name = aa.seq(), aa.name end
			elseif ch.command_grab and d <= grab_reach(ch, me, op, true) and grab_ok(mem, me, ch.command_grab.name) then
				seq, name = ch.command_grab.seq(), ch.command_grab.name    -- grappler: agarre de comando tras parry
			else
				local adv = op_disadvantage(op)
				local pe, pw
				seq, name, _, st_anim, st_reach, pe, pw = plan_punish(ctx, ch, me, d, adv, lat)
				-- online: caminar 10-15 frames tras el parry nunca llegó (0 de daño): solo castigos que casi no caminan,
				-- salvo que sobre recuperación de verdad (sweep parreado: 14+ frames libres después de caminar)
				local walk = name and tonumber(name:match("%+walk (%d+)"))
				if CIPHER_EXT and walk and walk > 4 and adv - walk < 14 then seq, name = nil, nil end
				if seq then
					local cut, cw = confirm_cut(mem, s, me, pe, pw)
					if cut then seq, name, mem.pp_confirm = cut, name .. " (confirm)", cw end
				end
			end
			mem.pp_frame = nil
			if not seq then log.write("pp-skip op=%s d=%d adv=%d (sin castigo que llegue)", tostring(mem.pp_move), d, op_disadvantage(op)) end
			if seq then
				push(ctx, seq, "post-parry " .. name)
				if mem.pp_confirm then mem.confirm = { start = s.frame + mem.pp_confirm } mem.pp_confirm = nil end
				if st_anim or st_reach then set_range_guard(mem, me, op, st_anim, math.max(0, op_disadvantage(op) - 12), st_reach) end
				track_combo(mem, s, op, mem.label)
				mem.committed = true
				mem.busy_until = s.frame + seq_len(seq) + 25
				mem.pp_diag = { frame = s.frame, name = name, hp = op.hp }
				return nil
			end
		end
	end
	if mem.pp_diag and s.frame - mem.pp_diag.frame >= 120 then   -- 120f: el superfreeze retrasa el daño
		log.write("pp-diag %s dmg=%d", mem.pp_diag.name, math.max(0, mem.pp_diag.hp - (op.hp == 255 and 0 or op.hp)))
		mem.pp_diag = nil
	end

	if th and (can_act(me) or me.is_blocking or not me.attacking) then
		local k = th.frames - lat
		local lead = cfg.parry_lead or 3
		-- bajo presión (spam que estoy bloqueando): parry más seguido y sin dado; un humano empieza a parrear el patrón
		local pressured = (mem.pressured or 0) >= 3
		-- wiki System: tras un intento de parry hay 23 frames de cooldown (no sale otro parry). Reintentar antes
		-- dejaba al bot sin parry y sin bloqueo (los "parry HIT" vs Yang). Sin dado bajo presión, pero con cooldown.
		local parry_ok = (s.frame - mem.last_parry) > 24 and not me.airborne
		-- offline el parry lo hace effie (timing exacto con la validez real del parry en RAM). Online effie solo bloquea
		-- (rollback) y quedábamos SIN parries: parry propio solo a lo que el rollback no esconde = proyectiles (posición y
		-- velocidad reales) y ataques aéreos (el arco del salto se ve con muchos frames de anticipación)
		if ctx.effie and not CIPHER_EXT then parry_ok = false end
		-- online: el rollback solo esconde el ARRANQUE de un golpe; una vez visible su timing es exacto (la animación es
		-- determinística). Parry de piso a lo que ya se ve hace >= 3 frames (golpes lentos) y al 2º+ golpe de multi-hits
		-- y cadenas (red parry desde el bloqueo). Antes: 0 parries de piso online (esta regla los apagaba todos, y effie
		-- pisaba la ventana del parry y lo volvía bloqueo: 181 "BLOCKED")
		if CIPHER_EXT and th.kind ~= "proj" and not th.air then
			if (op.anim_frame or 0) < 3 and not me.is_blocking then parry_ok = false end
			-- con input delay 2+ (ping alto) el timing del parry de piso se corre: solo red parry desde el bloqueo
			-- (vs Dudley con delay 2-3: 4 parries HIT contra el f.HP, 3 combos abiertos así)
			if lat >= 2 and not me.is_blocking then parry_ok = false end
			-- una tirada por golpe (no por frame): mezcla parry / bloqueo para no ser predecible
			if mem.gp_key == nil or math.abs((mem.gp_at or 0) - (s.frame - th.frames)) > 2 or mem.gp_key ~= tostring(th.move) then
				mem.gp_key, mem.gp_at = tostring(th.move), s.frame - th.frames
				mem.gp_ok = math.random() < ((pressured or (rs.my_hp > 0 and rs.my_hp <= 45)) and 0.75 or (cfg.ground_parry_rate or 0.6))
			end
			if not mem.gp_ok then parry_ok = false end
		end
		-- tampoco parrear pegado a un grappler: un agarre que entra con parry activo no se puede techear
		if (op.char_str == "alex" or op.char_str == "hugo") and d < 60 and not th.low then parry_ok = false end
		local st = mem.parry_stats[op.char_str .. ":" .. tostring(th.move)]
		if st and st.fail >= 2 and st.fail > st.ok then parry_ok = false end   -- aprendido: contra este golpe, bloquear
		-- bajos muy rápidos: el parry bajo exige soltar y volver a apretar abajo; no llega -> bloquear
		if th.low and k < 3 then parry_ok = false end
		-- online con input delay alto (rollback): los golpes del rival aparecen tarde y el parry de reacción llega tarde
		-- (Sean vs Gouki con delay 4-5: parries HIT dt=1). Ahí solo parry a lo predecible: proyectiles y golpes lentos.
		if lat >= 3 and th.kind ~= "proj" and not th.air and th.frames < lat + 10 then parry_ok = false end
		-- ventana real del parry (wiki System): 10f tras tocar (suelo), 5f contra ataques aéreos. El toque sale al frame
		-- siguiente: vale si el golpe llega entre 1 y 10 frames después. Antes solo con k = 2..4 y 15% al azar sin parry:
		-- si el golpe aparecía tarde (rollback) se pasaba de largo.
		-- timing de effie (dummy_control.lua): el parry se ingresa 1-2 frames ANTES del golpe (delta <= 2), y durante el
		-- bloqueo (red parry: ventana de 3f en normales, 2f en especiales) exactamente 1 frame antes. Nuestro toque sale
		-- al frame siguiente de decidir (1 frame neutral): k = 2..3 normal, k = 2 en bloqueo. Tocar antes soltaba la guardia
		-- en las cadenas y nos comíamos el segundo golpe (fallos con dt = k+1).
		local kmin, kmax = 2, (me.is_blocking and 2) or 3
		-- parry mezclado, no automático: quieto parreando todo (48 parries de Oro a los kunais de Ibuki, uno tras otro) se
		-- ve robótico y es leíble. Bolas al 50%, bajo presión 70%; el resto bloquea
		local prate = (th.kind == "proj") and 0.5 or (cfg.parry_rate or 0.95)
		-- rival zoneando (Remy: booms y se aleja): el parry no empuja para atrás como el bloqueo -> se gana terreno
		if th.kind == "proj" and (mem.op_zoning or 0) >= 2 then prate = 0.85 end
		if pressured then prate = math.max(prate, 0.7) end
		-- poca vida: el chip de bolas / especiales / supers bloqueados me mata -> parry casi siempre
		if rs.my_hp > 0 and rs.my_hp <= 20 then prate = math.max(prate, 0.9) elseif rs.my_hp <= 45 then prate = math.max(prate, 0.75) end
		if mem.pp_roll_key ~= tostring(th.move) .. (s.frame - th.frames) then          -- una tirada por golpe
			mem.pp_roll_key, mem.pp_roll = tostring(th.move) .. (s.frame - th.frames), math.random() < prate
		end
		if parry_ok and k <= kmax and k >= kmin and mem.pp_roll then
			mem.last_parry = s.frame
			mem.pending_parry = { frame = s.frame, k = k, move = th.move, af = op.anim_frame }
			mem.parry_tap_frame = s.frame + 1
			mem.parry_dir = th.low and "low" or "high"
			mem.parry_until = s.frame + 1 + (cfg.parry_window or 9)
			ctx.queue:clear()
			mem.label = "parry " .. mem.parry_dir .. " vs " .. tostring(th.move)
			return {}                                   -- frame neutral previo al toque
		end
		if k <= (cfg.block_lead or 14) then
			ctx.queue:clear()
			-- con effie: stick neutral ante la amenaza; effie parrea (necesita neutral previo) o bloquea en el frame justo
			-- solo sin lag: online (lat 2) effie no llegaba y 10 de 37 golpes recibidos fueron con el stick neutral
			if ctx.effie and not me.is_blocking and lat < 2 and not CIPHER_EXT then
				mem.label = "neutral para parry (effie) vs " .. tostring(th.move)
				return {}
			end
			mem.label = "block " .. ((th.low and "low") or (th.overhead and "high") or "crouch") .. " vs " .. tostring(th.move)
			-- bajos y medios: agachado; overheads/aéreos: parado
			if th.overhead then return { back = true } end
			return { back = true, down = true }
		end
	end
	-- 3b) guardia con lag alto (online, input delay >= 3): el golpe del rival aparece tarde y el predictor no llega.
	--     Si ataca cerca y no está en recuperación (no hay castigo), bloquear ya (vs Gouki: 0 bloqueos en 3 rounds).
	-- online siempre (no solo lat >= 3): con delay 2 + rollback el cr.LK de Gouki (4f) tampoco se bloquea de reacción
	if (lat >= 3 or CIPHER_EXT) and not th and op.attacking and not op.knocked_down and d < 170 and (can_act(me) or me.is_blocking) then
		local rec0 = P.recovery_left(op)
		if not rec0 or rec0 <= 0 then
			ctx.queue:clear()
			mem.label = "guardia (lag " .. lat .. ")"
			-- parado solo contra ataques de salto (u_*, *_air): un especial en el aire (tatsu) es mid -> agachado
			local mv = op.move or ""
			if op.airborne and (mv:match("^u") or mv:find("_air")) then return { back = true } end
			return { back = true, down = true }
		end
	end
	-- 3c') respeto a la bola: proyectil del rival entre los dos y viniendo -> cortar caminata/dash y bloquear (de pie
	--      si viene por el aire). Oro caminaba directo a los hadouken de Gouki y se los comía uno tras otro.
	if not me.airborne and (can_act(me) or me.is_blocking) then
		for _, pr in ipairs(s.proj or {}) do
			local dpr = math.abs(pr.x - me.x)
			local coming = pr.cipher_prev_d and dpr < pr.cipher_prev_d     -- se acerca (objeto persistente entre frames)
			pr.cipher_prev_d = dpr
			local ahead = (pr.x - me.x) * (op.x - me.x) > 0 or dpr < 30
			if pr.emitter ~= ctx.side and ahead and coming and dpr < 210 then
				local key = pr.base
				if mem.proj_jump_key ~= key and dpr > 110 and dpr < 170 and not mem.no_jump and lat < 3
					and math.random() < 0.35 and can_act(me) and d < 260 then
					mem.proj_jump_key = key                         -- saltarla (una decisión por bola)
					push(ctx, MOVES.jump_in("hk"), "salta la bola")
					mem.committed = true
					return nil
				end
				mem.proj_jump_key = key
				-- bloquear recién con la bola CERCA (< 80 px): antes desde 210 px, y bloquear parado es caminar atrás -> ~100 px
				-- perdidos por bola contra los zoners. Agachado (no se mueve) salvo bola aérea
				if dpr < 80 then
					ctx.queue:clear()
					mem.label = "bloquea la bola"
					if pr.y > 40 then return { back = true } end
					return { back = true, down = true }
				end
			end
		end
	end
	-- salto que conectó: se registra en el aire (antes de exigir poder actuar)
	if me.airborne and op.has_just_received_hit and not op.is_blocking then mem.jump_hit = s.frame end
	if not can_act(me) then return nil end
	if ctx.queue:busy() then return nil end
	if mem.busy_until and s.frame < mem.busy_until and not me.has_just_hit then return nil end   -- combo en curso

	-- 3b') salto que conectó: al caer, combo (antes saltaba, pegaba y no seguía con nada)
	if mem.jump_hit and not me.airborne and s.frame - mem.jump_hit < 25 and not op.airborne and not op.knocked_down then
		mem.jump_hit = nil
		local seq, name = plan_punish(ctx, ch, me, d, 16, lat)
		if seq then
			push(ctx, seq, "combo tras salto " .. name)
			track_combo(mem, s, op, "salto " .. name)
			mem.committed = true
			mem.busy_until = s.frame + seq_len(seq) + 25
			return nil
		end
	end
	if mem.jump_hit and s.frame - mem.jump_hit >= 25 then mem.jump_hit = nil end

	-- 3c) rival mareado (stun): castigo máximo. Antes no había regla y el bot quedaba mirando hasta que se recuperaba.
	--     Combo verificado de más daño (con super si hay barra y coincide el SA), caminando hasta el rango.
	if op.is_stunned and not op.airborne and not op.knocked_down and not op.being_thrown then
		local window = math.max(30, op.stun_timer)          -- sin machacar baja ~1/frame: casi siempre sobra tiempo
		local seq, name, _, s_anim, s_reach = plan_punish(ctx, ch, me, d, window, lat, true)
		if seq then
			push(ctx, seq, "STUN punish " .. name)
			-- caminata a lazo cerrado hasta el alcance real del primer golpe (el mareado no se mueve)
			if s_anim or s_reach then set_range_guard(mem, me, op, s_anim, 40, s_reach) end
			track_combo(mem, s, op, "stun " .. name)
			mem.committed = true
			mem.busy_until = s.frame + seq_len(seq) + 25
			log.write("stun-diag timer=%d d=%d -> %s", op.stun_timer, d, name)
			return nil
		end
		push(ctx, MOVES.shimmy_in(6), "se acerca al mareado")
		return nil
	end

	-- 4) castigo con frame data (recuperación del rival)
	local rec = P.recovery_left(op)
	local rec_raw = rec
	-- normal de piso del rival: puede cancelarlo en especial (cr.MK xx tatsu de Gouki se comió 3 castigos con caminata).
	-- Solo castigar si sobra recuperación de verdad: 6 frames de margen
	-- online: 36 de los golpes recibidos mientras "castigaba" fueron el cr.MK del rival (cancelado o ya recuperado por
	-- el rollback) y los castigos fallaban el 56%: 10 frames de margen en normales
	-- (con 10 casi no castigaba: 3 castigos en 3 rounds vs Hugo; el aprendizaje por golpe cubre los que no pegan)
	local op_whiff = mem.op_conn_at ~= op.anim_start
	-- un normal que ERRÓ no se cancela (en 3S el cancel es al conectar): sin ese margen
	-- solo los normales que se CANCELAN: débiles/medios, cl.HP y cr.HP. Los pesados lejanos y los barridos (d_HK, HK,
	-- HP de lejos) no: el lab de castigos mostró sweeps bloqueados (rec 13) que no se castigaban por este margen
	local mvn = op.move or ""
	local cancelable = mvn:match("^%a?%a?_?[LM][PK]$") or mvn == "cl_HP" or mvn == "d_HP"
	if rec and not op_whiff and cancelable then rec = rec - (CIPHER_EXT and 8 or 6) end
	-- aprendido por movimiento del rival: contra los que el castigo no pega (2+ fallos y el doble que aciertos), no
	-- castigar (10% reintenta para seguir aprendiendo)
	local pkey = "punish:" .. op.char_str .. ":" .. tostring(op.move)
	local pst = mem.parry_stats[pkey]
	-- (antes 2 fallos bastaban y apagaba castigos que funcionan: en el lab de Oro "aprendido" frenó 117 de 147
	-- whiff punishes; un fallo suelto también pasa por rango o timing, no porque el golpe sea seguro)
	if rec and pst and pst.fail >= 4 and pst.fail > 3 * pst.ok and math.random() > 0.25 then rec = nil end
	-- bola del rival en pantalla viniendo hacia mí: "castigar" la recuperación del hadouken = caminar hacia la bola
	local ball = false
	for _, pr in ipairs(s.proj or {}) do
		if pr.emitter ~= ctx.side and (pr.x - me.x) * (op.x - me.x) > 0 then ball = true end
	end
	if rec and rec > 0 and not op.airborne and not ball then
		local seq, name
		local cg = ch.command_grab
		-- el combo verificado más dañino que entra (con super si hay barra) contra el agarre de comando: antes el agarre
		-- ganaba SIEMPRE en su rango y Alex nunca tiraba el Boomerang Raid (Power Bomb ~30 vs cl.MK xx SA 60)
		local cseq, cname, cdmg, canim, creach, ce, cwalk = plan_punish(ctx, ch, me, d, rec, lat)
		-- castigo que es un super suelto ("shippu (SA3)" de la lista del personaje) contra un normal: no (ver abajo)
		if cname and cname:find("%(SA%d") and (op.move or ""):match("^%a?%a?_?[LMH][PK]$") then cseq, cname = nil, nil end
		local CG_DMG = { hugo = 45, alex = 32 }
		if cg and d <= grab_reach(ch, me, op, true) and rec >= button_offset(cg.seq()) + lat + 2 and grab_ok(mem, me, cg.name)
			and not (cdmg and cdmg > (CG_DMG[me.char_str] or 35)) then
			seq, name = cg.seq(), cg.name                 -- grappler: castigar con el agarre de comando
		else
			seq, name = cseq, cname
		end
		-- castigo crudo con super: hay barra, la recuperación es larga y ningún combo verificado entra
		-- online con margen de rollback (57% de supers crudos sin daño = barra regalada)
		-- nunca contra un NORMAL del rival (Ken tiró 2 Shippu al cr.MK de Ryu y los 2 erraron: la recuperación real de un
		-- normal es corta y el rival vuelve a pegar): solo especiales / supers
		local op_normal = (op.move or ""):match("^%a?%a?_?[LMH][PK]$") ~= nil
		-- excepción: el super suelto MATA y el normal erró con recuperación larga de verdad (pesado / barrida al aire)
		local rsd = raw_super_dmg(me.char_str, me.sa)
		local raw_kill = rsd and rs.op_hp > 0 and rs.op_hp <= rsd and op_whiff and rec >= 20 + lat + (CIPHER_EXT and B.punish_margin or 0)
		if not seq and (not op_normal or raw_kill) and me.meter >= 1 and rec >= 14 + lat + (CIPHER_EXT and B.punish_margin or 0) and (d < 90 or is_proj_super(me)) then
			seq = super_frames(me.char_str, me.sa)
			name = seq and ("super crudo " .. tostring(me.sa))
		end
		-- whiff punish: el rival erró un poke de lejos (104 de 104 castigos dejados pasar en el health check, a 107-188
		-- px). Ningún combo llega caminando: el poke más largo que alcanza y sale a tiempo; si conecta, confirm
		local wp = nil
		if not seq and op_whiff then
			local m = lat + (CIPHER_EXT and B.punish_margin or 0) + 1
			local wwalk = 0
			local gain = limb_gain(mem, me, op)
			for _, pk in ipairs(ch.pokes or {}) do
				-- caminando hasta el alcance si sobra recuperación (st.HK errado a 165 px: "ningún poke llega" 15 de 27)
				-- en la recuperación el cuerpo del rival no está donde mide la tabla (Ryu tras st.HK: far MK de Oro "llega a
				-- 159" y erraba a 120) y la pierna estirada ya volvió cuando pega el poke: -20 px y sin contar la pierna
				-- salvo pokes de 4f o menos
				local reach = move_reach(me, op, pk) - 20 + (((pk.startup or 8) <= 4) and gain or 0)
				local walk = math.max(0, math.ceil((d - reach) / WALK_SPEED))
				local cost = walk + (pk.startup or 8) + m
				-- cajas reales: si la simulación dice que no llega (ni caminando), descartado
				local ok_box = poke_connects(me, op, pk.anim, walk * WALK_SPEED)
				if d >= pk.range[1] and walk <= 12 and cost <= rec and ok_box ~= false
					and (not wp or cost < wwalk + (wp.startup or 8) + m) then wp, wwalk = pk, walk end
			end
			if wp then
				seq, name = wp.seq(), "whiff " .. wp.name .. ((gain > 0) and (" (pierna +" .. math.floor(gain) .. ")") or "")
				if wwalk > 0 then table.insert(seq, 1, { fwd = true, hold = wwalk }) name = name .. " (+walk " .. wwalk .. ")" end
			end
		end
		if not seq then mem.ps_reason = op_whiff and "whiff: ningún poke llega" or "sin castigo que llegue" end
		if seq then
			local is_c = seq == cseq
			local cut, cw = nil, 0
			if is_c then cut, cw = confirm_cut(mem, s, me, ce, cwalk) end
			if cut then seq, name = cut, name .. " (confirm)" end
			push(ctx, seq, "punish " .. name .. " (rec " .. rec .. ")")
			local ganim = is_c and canim or (wp and wp.anim) or nil
			if ganim or (is_c and creach) then set_range_guard(mem, me, op, ganim, math.max(0, rec - 10), is_c and creach or nil) end
			track_combo(mem, s, op, "punish " .. name)
			mem.cd.pkey = pkey
			if wp then mem.confirm = { start = s.frame } end
			if cut then mem.confirm = { start = s.frame + cw } end
			mem.committed = true
			mem.busy_until = s.frame + seq_len(seq) + 25
			return nil
		end
	end

	-- diagnóstico: oportunidad de castigo (10+ frames de recuperación real vista) que se dejó pasar, una vez por golpe
	if rec_raw and rec_raw >= 10 and not op.airborne then
		local key = tostring(op.move) .. ":" .. tostring(op.anim_start)
		if mem.ps_key ~= key then
			mem.ps_key = key
			local why = (ball and "bola") or (not rec and "aprendido") or (rec <= 0 and "margen normal") or mem.ps_reason or "?"
			log.write("punish-skip op=%s rec=%d adj=%s d=%d why=%s synced=%s meter=%d margin=%.1f whiff=%s gain=%d", tostring(op.move), rec_raw,
				tostring(rec), d, why, tostring(op.anim_synced), me.meter, B.punish_margin, tostring(op_whiff), limb_gain(mem, me, op))
		end
	end
	mem.ps_reason = nil

	-- 4b) remate con super: rival con poca vida y barra disponible. Un super de proyectil lo mata aunque lo bloquee
	--     (chip); de cerca, con muy poca vida, cualquier super. Gouki perdió 2 rounds con Remy a 5 y 12 de vida y
	--     la barra llena porque el super solo salía como final de combo
	if me.meter >= 1 and op.hp ~= 255 and not op.knocked_down and not op.airborne and (mem.super_cd or 0) <= s.frame then
		local proj = is_proj_super(me)
		-- online el remate falló el 69% (53 intentos: bloqueado sin matar o castigado): solo super de proyectil con la
		-- vida que mata el chip
		local kill = (proj and op.hp <= 25 and d > 70) or (op.hp <= 12 and d < 90)
		if CIPHER_EXT then kill = proj and op.hp <= 10 and d > 70 end
		-- aprendido: el humano salta / parrea el super de remate (Gouki 5 de 6 sin daño): 2+ fallos y más que aciertos -> no
		local rst = mem.parry_stats["remate:" .. me.char_str .. ":" .. op.char_str]
		if rst and rst.fail >= 2 and rst.fail > rst.ok then kill = false end
		if kill then
			local seq = super_frames(me.char_str, me.sa)
			if seq then
				mem.super_cd = s.frame + 120
				push(ctx, seq, "remate con super (rival " .. op.hp .. ")")
				track_combo(mem, s, op, "remate con super")
				mem.cd.pkey = "remate:" .. me.char_str .. ":" .. op.char_str
				mem.committed = true
				return nil
			end
		end
	end

	-- 4d) rival con ARMADURA (Hammer Mountain de Hugo): los golpes no lo frenan y pega a través de ellos (Oro le tiró
	--     pokes y no le sacó vida). La armadura no protege de agarres: agarre si está en rango; si no, alejarse
	if (op.move or ""):find("hammer_mountain") and not op.airborne then
		if d < grab_reach(ch, me, op) and throwable(s, mem, op) then
			push(ctx, ch.throw(), "agarre vs armadura")
			mem.committed = true
			return nil
		elseif mem.move_cd == 0 then
			mem.move_cd = 12
			push(ctx, (math.random() < 0.5) and MOVES.backdash() or { { back = true, hold = 12 } }, "se aleja de la armadura")
			return nil
		end
	end

	-- 4c) recién termina un dash adelante: actuar YA. Antes el dash terminaba con 10 frames de espera y el rival
	--     agarraba (todos los personajes). Cerca: agarre / bajo; más lejos: el poke que llegue; si nada llega, guardia
	if mem.after_dash then
		mem.after_dash = nil
		if not op.airborne and not op.knocked_down then
			local grap = (op.char_str == "hugo" or op.char_str == "alex") and not ch.grappler
			local r = math.random()
			local ph = (mem.op_parry_recent or 0) >= 2     -- vs rival que parrea: después del dash, agarre o nada
			local rdd = radar(s, op)
			if not grap and d < grab_reach(ch, me, op) and throwable(s, mem, op) and (r < math.min(0.9, 0.45 * rdd.throw) or ph) then
				push(ctx, ch.throw(), (ch.grappler and ch.command_grab) and ch.command_grab.name or "throw")
				mem.committed = true
				return nil
			end
			local best
			for _, pk in ipairs((not ph) and ch.pokes or {}) do
				if d >= pk.range[1] and d <= move_reach(me, op, pk) and box_ok(me, op, pk.anim, 0, lat)
					and (not best or (pk.startup or 8) < (best.startup or 8)) then best = pk end
			end
			if not best and not ph and ch.meaty and d <= move_reach(me, op, ch.meaty) then best = ch.meaty end
			if best then
				push(ctx, best.seq(), "post-dash " .. best.name)
				mem.confirm = { start = s.frame }
				return nil
			end
			-- nada llega: caminar lo que falta y pegar con el poke más largo, sin quedarse parado ("doble step y se
			-- queda 1 s sin hacer nada")
			local far, fr
			for _, pk in ipairs((not ph) and ch.pokes or {}) do
				local r = move_reach(me, op, pk)
				if d >= pk.range[1] and (not fr or r > fr) then far, fr = pk, r end
			end
			if far then
				-- caminar hasta BIEN adentro del alcance (20 px), no a la punta: en la punta erraba (77 golpes al aire en el
				-- health check). Si el rival se aleja, no perseguir con un poke
				local away = (op.vx or 0) * ((op.flip == 1) and 1 or -1) * ((op.x > me.x) and 1 or -1) > 0.5
				local walk = math.ceil((d - fr + 20) / WALK_SPEED)
				if walk > 0 and walk <= 14 and not away then
					local seq = far.seq()
					table.insert(seq, 1, { fwd = true, hold = walk })
					push(ctx, seq, "post-dash camina + " .. far.name)
					mem.confirm = { start = s.frame + walk }
					return nil
				end
			end
		end
	end

	-- 5) hit-confirm: mi normal cancelable conectó
	if me.has_just_hit and me.move and (me.move == "d_MK" or me.move == "d_LK")
		and (op.has_just_received_hit or (mem.op_hit_at or -99) >= s.frame - 2) and not op.is_blocking then   -- golpe real
		for _, c in ipairs(ch.confirm) do
			if not c.meter or me.meter >= c.meter then
				push(ctx, c.seq(), "confirm " .. c.name)
				mem.committed = true
				return nil
			end
		end
	end

	-- 6) okizeme: rival en el piso. Plan al azar por derribo (meaty / throw / bait / space), timing con la frame data
	--    de las animaciones de levantarse, y micro-movimientos mientras espera (antes: caminaba y quedaba quieto = "bot")
	if op.knocked_down then
		-- rival en el piso: activar el super de estado (Genei-Jin / Aegis / Tengu) o el taunt con buff si hay distancia
		local rem_k = wake_remaining(op)
		if (not rem_k or rem_k > 25) and try_special(ctx, ch, mem, s, me, op, d, "install") then return nil end
		-- taunt: solo con el levantarse CONOCIDO y de sobra (dura ~40f), lejos, y ganando en vida. Antes con rem_k
		-- desconocido tauntaba igual y vs Q humano era castigo seguro (dash punch / super) con la vida en juego
		local my_hp, op_hp = (me.hp == 255) and -1 or me.hp, (op.hp == 255) and -1 or op.hp
		if rem_k and rem_k > 75 and d > 170 and my_hp > op_hp + 20
			and try_special(ctx, ch, mem, s, me, op, d, "taunt") then return nil end
		if not mem.oki then
			local r = math.random()
			-- más presión en el levantarse (online: 39 meaties en 40 peleas; bait/space = dejarlo pararse gratis)
			-- online: casi sin "esperar" (bait/space): el bot entraba con dash y se quedaba quieto hasta que el rival se paraba
			local plan = (r < 0.55 and "meaty") or (r < (CIPHER_EXT and 0.95 or 0.85) and "throw") or (r < (CIPHER_EXT and 0.98 or 0.95) and "bait") or "space"
			if ch.grappler then plan = (r < 0.6 and "throw") or (r < 0.8 and "meaty") or "bait" end
			-- rival que parrea (2+ parries en 30 s): el meaty es lo que parrea; agarre (no se parrea) y bait
			if (mem.op_parry_recent or 0) >= 2 and not ch.grappler then
				plan = (r < 0.2 and "meaty") or (r < 0.7 and "throw") or "bait"
			end
			plan = os.getenv("CIPHER_OKI_PLAN") or plan
			if plan == "space" and not ch.fireball then plan = "bait" end
			-- meaty corto (cr.LK) la mayoría de las veces: queda encima para la presión; a veces el poke largo
			local meaty = (ch.meaty and math.random() < 0.75) and ch.meaty or ch.pokes[1]
			mem.oki = { plan = plan, poke = meaty, done = false }
			mem.oki.target = (plan == "throw" and 38) or (plan == "meaty" and meaty and (meaty.range[2] - 18))
				or (plan == "space" and 185) or ((ch.ideal_range or 115) - 10)
		end
		local oki = mem.oki
		-- frames hasta que el rival deja de estar tirado: "wakeup" (tirado) + "wakeup_ext" (levantándose, aprendido).
		-- Antes se usaba solo "wakeup" y el meaty salía ~45 frames antes: siempre erraba.
		local rem = wake_remaining(op)
		-- RADAR en el levantarse: el rival ya aprieta su defensa estando en el piso (guardia abajo-atrás, toque de parry,
		-- LP+LK de tech). A ~14 frames de pararse se re-elige el plan: guardia -> agarre; parry / reversal -> bait;
		-- tech -> meaty. Al 75% (radar)
		if rem and rem <= 14 and rem > 4 and not oki.done and not oki.radar then
			oki.radar = true
			local rd = radar(s, { guard = op.guard, guard_n = op.guard_n, tap_fwd = op.tap_fwd, tech_at = op.tech_at,
				parry_window = false })
			if rd.why then
				local np = pick({ { 3 * rd.hit, "meaty" }, { 3 * rd.throw, "throw" }, { 1.5 * rd.bait, "bait" } })
				if np ~= oki.plan then
					log.write("radar oki %s -> %s (%s, guard=%s)", oki.plan, np, rd.why, tostring(op.guard))
					oki.plan = np
					oki.target = (np == "throw" and 38) or (np == "meaty" and oki.poke and (oki.poke.range[2] - 18)) or oki.target
				end
			end
		end
		if rem and not oki.done then
			local K = tonumber(os.getenv("CIPHER_OKI_K") or "") or (cfg.oki_k or 1)
			if oki.plan == "meaty" and oki.poke and rem <= (oki.poke.startup or 5) + lat + K and d <= move_reach(me, op, oki.poke) then
				oki.done = true
				push(ctx, oki.poke.seq(), "oki meaty " .. oki.poke.name)
				mem.confirm = { start = s.frame }
				mem.oki_diag = { frame = s.frame, S = oki.poke.startup or 5, rem = rem, k = K, poke = oki.poke.name, d = d }
				return nil
			elseif oki.plan == "throw" and d <= grab_reach(ch, me, op)
				and rem <= button_offset(ch.throw()) + lat + 1 then
				-- wiki System: 6 frames de protección contra agarres al levantarse. Antes el botón caía justo al pararse
				-- (dentro de la protección): el agarre de okizeme no podía entrar nunca. Ahora cae 7 frames después.
				-- el botón del agarre llega al juego 8 frames después de pararse (protección de 6 + 2 de margen): antes el
				-- hold fijo de 7 lo dejaba en el frame 5-6, todavía protegido (20 MISS de 54 online)
				oki.done = true
				-- frame del LP+LK (en el kara throw va después del normal que se cancela)
				local toff = 0
				for _, f in ipairs(ch.throw()) do
					if f.lp and f.lk then break end
					toff = toff + (f.hold or 1)
				end
				local seq = { { hold = math.max(1, rem + 8 - toff - lat - 1) } }
				for _, f in ipairs(ch.throw()) do seq[#seq + 1] = f end
				push(ctx, seq, "oki " .. ((ch.grappler and ch.command_grab) and ch.command_grab.name or "throw"))
				mem.committed = true
				return nil
			elseif oki.plan == "space" and ch.fireball and rem <= 18 and charged(ctx, ch.fireball.charge) then
				oki.done = true
				push(ctx, clean_motion(ctx, ch.fireball.seq(), s.frame), "oki fireball")
				mem.committed = true
				return nil
			elseif oki.plan == "bait" and rem <= 4 then
				oki.done = true
				push(ctx, { { back = true, down = true, hold = 12 } }, "oki bait (bloqueo)")
				return nil
			end
		end
		-- posicionarse en la distancia del plan, con pasos cortos
		local diff = d - oki.target
		-- lejos (tras DP / barrida larga) y con tiempo: dash para llegar antes de que se pare (con pasitos llegaba tarde)
		if diff > 70 and rem and rem > 22 and mem.move_cd == 0 then
			mem.move_cd = 18
			push(ctx, MOVES.dash(), "oki: dash (" .. oki.plan .. ")")
			return nil
		end
		if diff > 10 then
			push(ctx, { { fwd = true, hold = math.min(6, math.ceil(diff / 3.2)) } }, "oki: acercarse (" .. oki.plan .. ")")
			return nil
		elseif diff < -14 then
			push(ctx, { { back = true, hold = 4 } }, "oki: alejarse (" .. oki.plan .. ")")
			return nil
		end
		-- en posición: micro-movimientos humanos en vez de quedarse quieto
		local r = math.random()
		if r < 0.18 then push(ctx, { { fwd = true, hold = 2 }, { hold = 2 } }, "oki: tantear")
		elseif r < 0.34 then push(ctx, { { back = true, hold = 2 }, { hold = 2 } }, "oki: tantear")
		elseif r < 0.52 then push(ctx, { { down = true, hold = 5 } }, "oki: agacharse")
		else push(ctx, { { hold = 3 } }, "oki: esperar " .. oki.plan) end
		return nil
	end
	mem.oki = nil

	-- 6b) presión: el rival acaba de salir del bloqueo de mi golpe, estoy cerca y ya puedo actuar (si mi golpe era
	--     muy negativo no llego dentro de la ventana y no presiono: correcto). Pesos por personaje en ch.pressure.
	if mem.op_block_end and s.frame - mem.op_block_end <= 4 and mem.press_for ~= mem.op_block_end
		and d < 75 and not op.airborne then
		mem.press_for = mem.op_block_end
		local w = ch.pressure or {}
		local rd = radar(s, op)                     -- lo que el rival tiene apretado al salir del bloqueo
		local mv = pick({ { (w.tick or 3) * rd.throw, "tick" }, { (w.trap or 3) * rd.trap, "trap" }, { (w.low or 2) * rd.low, "low" },
			{ (w.uoh or 1) * rd.over, "uoh" }, { (w.bait or 2) * rd.bait, "bait" } })
		-- agarre >= 7 frames después del fin del bloqueo (protección de 6f): ya pasaron k frames y el input llega lat tarde
		local walk = math.max(2, 8 - (s.frame - mem.op_block_end) - lat)
		if mv == "tick" and d > grab_reach(ch, me, op) + 6 + walk * 2 then mv = "trap" end   -- caminando ~2-3 px/frame
		push(ctx, PRESSURE[mv](ch, walk), "presión " .. mv .. rtag(rd))
		if mv ~= "bait" then mem.confirm = { start = s.frame } end
		mem.committed = true
		return nil
	end

	-- 6d) rival quieto ~0.6 s (taunt / esperando): ir a buscarlo. Online un Ibuki se quedó provocando y Oro siguió
	--     agachado cargando (neutral de personaje de carga). Dash de lejos, caminar de cerca; los pokes con el rival
	--     quieto ya salen solos (op_idle) al entrar en rango
	-- Restringido: un humano en neutral también está "quieto" esperando en guardia; con 36 frames el bot entraba con
	-- dash una y otra vez sin hacer nada y comía golpes (Ryu online). Solo quieto 1.5 s, fuera de su alcance, UNA
	-- vez por quietud y caminando (sin dash): al llegar, los pokes con el rival quieto (op_idle) hacen el resto
	if (mem.op_still or 0) < 30 then mem.still_done = false end
	if (mem.op_still or 0) >= 90 and not mem.still_done and d > op_poke_reach(op, me) + 20 and mem.move_cd == 0
		and not th then
		mem.still_done, mem.move_cd = true, 20
		push(ctx, { { fwd = true, hold = math.max(4, math.min(30, math.ceil((d - (ch.ideal_range or 115)) / WALK_SPEED))) } }, "va a buscarlo")
		return nil
	end
	-- 6e) arrinconado y presionado: no quedarse parreando / bloqueando contra la pared (se ve robótico y el humano
	--     lo abre). Entre golpes del rival: salto adelante / neutro, jab que corta, reversal con barra o salir caminando.
	--     Paredes medidas online: x ~108 y ~918
	local cornered = (me.room_back or 999) < 32
	-- espacio atrás hasta la pared (paredes medidas ~108 / ~918): con poco espacio NO se retrocede más. Antes varias
	-- reglas (salir del rango, walk back, backdash anti-quietud, escapes de agarre) lo encerraban en la esquina
	local back_room = me.room_back or ((op.x > me.x) and (me.x - 108) or (918 - me.x))
	local near_wall = back_room < 110
	-- AGRESIVIDAD según la pelea (vida de los dos + mapa): rival con poca vida, rival contra la pared o ventaja de vida
	-- = presión total (más pokes / agarres, avanzar, no escapar). Pedido del usuario: "que sea LETAL, que no escape"
	local my_hp = (me.hp == 255) and 0 or me.hp
	local op_hp = (op.hp == 255) and 0 or op.hp
	local op_room = op.room_back or ((me.x > op.x) and (op.x - 108) or (918 - op.x))
	-- base 1.0: con 1.3 los pokes salían 30% más y un humano los esperaba y contraatacaba en la recuperación (Oro vs
	-- Ryu: casi todos los golpes recibidos fueron justo después de un poke propio). La presión sube por contexto
	local aggr = 1.0
	if op_hp <= 50 then aggr = aggr + 0.6 end           -- rematar
	if op_hp > 0 and op_hp <= 14 then aggr = aggr + 0.6 end   -- cualquier golpe lo mata
	if op_room < 90 then aggr = aggr + 0.5 end          -- rival en la esquina: no dejarlo salir
	if my_hp > op_hp + 30 then aggr = aggr + 0.3 end    -- ventaja de vida: seguir presionando
	-- poca vida y perdiendo: tortuguear no da vuelta el round (el chip / el agarre lo terminan). Pelear
	if my_hp > 0 and my_hp <= 45 and op_hp > my_hp then aggr = aggr + 0.4 end
	if rs.clock_lose then aggr = aggr + 0.8 end         -- perdiendo por reloj: hay que pegar
	if rs.clock_win then aggr = math.min(aggr, 0.6) end -- ganando por reloj: no regalar nada
	mem.aggr = aggr
	-- (también con poca vida en cualquier lado: bloqueando todo agachado se moría igual)
	if (cornered or (my_hp > 0 and my_hp <= 45)) and d < 110 and (mem.pressured or 0) >= 1 and mem.move_cd == 0 and not th and not op.attacking
		and math.random() < 0.35 then
		mem.move_cd = 40
		local rv = ch.reversal
		local cj = not mem.no_jump and lat < 3
		local ph = (mem.op_parry_recent or 0) >= 2      -- vs rival que parrea: el jab y el reversal se los parrea
		local mv = pick({ { cj and 3 or 0, "jump_fwd" }, { cj and 1 or 0, "jump_up" }, { ph and 0 or 2, "jab" },
			{ (rv and not rv.charge and me.meter >= 1 and not ph) and 2 or 0, "reversal" }, { 2, "walk_out" } })
		if mv == "jump_fwd" then push(ctx, { { up = true, fwd = true, hold = 3 }, { hold = 30 } }, "esquina: salta afuera")
		elseif mv == "jump_up" then push(ctx, MOVES.jump_up(), "esquina: salto neutro")
		elseif mv == "reversal" then push(ctx, rv.seq(), "esquina: reversal " .. rv.name)
		elseif mv == "jab" then push(ctx, input_lib.motion.press("lp", { down = true }, 2), "esquina: cr.LP")
		else push(ctx, { { fwd = true, hold = 8 } }, "esquina: sale caminando") end
		mem.committed = mv ~= "walk_out"
		return nil
	end
	-- 7) footsies
	local ideal = ch.ideal_range or 115
	-- vs grappler: el neutral se juega afuera del rango de su agarre de comando (360 de Hugo 111 px, Power Bomb 104)
	-- cg_zone: adentro no se pokea, no se tira overhead ni se camina hacia él (Ryu vs Hugo online: Moonsault durante
	-- un cr.MK de cerca, agarres durante un overhead y caminando con "se acerca vs spam")
	local cg_zone = 0
	if op.char_str == "hugo" or op.char_str == "alex" then
		local cg = RG.prefix(op.char_str, op.char_str == "hugo" and "moonsault_press" or "power_bomb", me.char_str, false)
		-- vs Hugo: +35 y +25 más con barra (Gigas Breaker agarra de más lejos: 38 agarres de super online)
		local hugo_meter = op.char_str == "hugo" and (op.meter or 0) >= 1
		ideal = math.max(ideal, (cg or 105) + ((op.char_str == "hugo") and 35 or 20) + (hugo_meter and 25 or 0))
		if not ch.grappler then cg_zone = (cg or 105) + 10 end
	end
	-- saltar solo si no me están anti-aireando y el lag permite reaccionar en el aire
	local can_jump = not mem.no_jump and lat < 3

	-- 6f) RELOJ: ganando en vida con <= 12 s, no arriesgar nada (los castigos ya se decidieron arriba): distancia y
	--     guardia. Contra la pared o afuera de su agarre, guardia agachado en el lugar
	if rs.clock_win and not th and d < op_poke_reach(op, me) + 40 and mem.move_cd == 0 and not op.airborne then
		mem.move_cd = 8
		if near_wall or (cg_zone > 0 and d >= cg_zone) then
			push(ctx, { { back = true, down = true, hold = 8 } }, "reloj: guardia")
		else
			push(ctx, MOVES.shimmy_out(6), "reloj: se aleja")
		end
		return nil
	end
	-- 6g) MODO REMATE: hay un combo verificado que lo MATA con la barra que tengo -> ir a BUSCARLO: el starter de esa
	--     ruta a su distancia verificada; al conectar, el confirm (best_confirm con la vida del rival) tira el que mata.
	--     Online el 51% de los rounds perdidos terminaron con el rival a <= 60 de vida y el bot tanteando con barra.
	--     Perdiendo por reloj: la ruta de más daño aunque no mate
	local he, hseq, hreach, hn
	-- con 14 o menos cualquier poke / agarre lo mata: eso lo resuelve el neutral normal (agresividad alta)
	if rs.op_hp > 14 and (mem.hunt_cd or 0) <= s.frame then
		local chg_now = { h = charged(ctx, "h"), v = charged(ctx, "v") }
		he, hseq, hreach, hn = Combos.hunt_route(me.char_str, me.meter, me.sa, rs.op_hp, chg_now)
		if not he and rs.clock_lose then he, hseq, hreach, hn = Combos.hunt_route(me.char_str, me.meter, me.sa, nil, chg_now) end
	end
	if he and he ~= mem.hunt_e then
		log.write("kill-window op_hp=%d meter=%d route=%s dmg=%d reach=%d clock=%s", rs.op_hp, me.meter, he.label, he.dmg, hreach,
			tostring(rs.clock_lose))
	end
	mem.hunt_e = he or ((mem.hunt_cd or 0) > s.frame and mem.hunt_e) or nil
	-- vs grappler adentro de su agarre solo si aguanto un 360 (vida > 50)
	if he and not th and not op.airborne and not op.knocked_down and not op.attacking and can_act(me)
		and not (cg_zone > 0 and rs.my_hp <= 50) then
		local lim = hreach - (CIPHER_EXT and 8 or 4)
		if d > lim then
			-- acercarse a la distancia de la ruta mezclando guardia (en línea recta se come un poke)
			if mem.move_cd == 0 and d < lim + 160 then
				mem.move_cd = 6
				-- guardia solo si el rival está tirando cosas (con 30% el bot se quedaba "remate: guardia" frente al rival)
				if CIPHER_EXT and d < op_poke_reach(op, me) + 10 and (mem.op_spam or 0) >= 1 and math.random() < 0.12 then
					push(ctx, { { back = true, down = true, hold = 5 } }, "remate: guardia")
				else
					-- la ruta pide estar ADENTRO de su agarre (cl.LP a 50 px, agarre ~72): caminar hasta afuera del agarre y el
					-- último tramo caminata + starter de una, sin quedarse parado adentro (lo agarraban "se acerca")
					local safe_stop = (mem.thr_op or 72) + 10
					local w_in = math.max(1, math.ceil((d - lim) / WALK_SPEED))
					if lim < safe_stop and d <= safe_stop + 8 and w_in <= 10 then
						local seq = { { fwd = true, hold = w_in } }
						for _, f in ipairs(hseq) do seq[#seq + 1] = f end
						mem.move_cd, mem.hunt_cd = w_in + 2, s.frame + 24 + w_in
						push(ctx, seq, string.format("remate: entra + %s -> %s [%d] (rival %d)", tostring(hn.name), he.label, he.dmg, rs.op_hp))
						mem.confirm = { start = s.frame + w_in }
						return nil
					end
					-- adelante DE CORRIDO (pasos cortados los comía el filtro anti-dash), frenando afuera de su agarre
					local target = (lim < safe_stop) and safe_stop or lim
					local hold = math.min(24, math.ceil((d - target) / WALK_SPEED))
					if hold < 1 then hold = 1 end
					mem.move_cd = hold
					push(ctx, { { fwd = true, hold = hold } }, "remate: se acerca (" .. he.label .. ")")
				end
				return nil
			end
		elseif d >= (he.min_d or 0) and not box_ok(me, op, hn.name, 0, lat) then
			-- por distancia "llega" pero las cajas reales dicen que no: un paso más
			if mem.move_cd == 0 then mem.move_cd = 4 push(ctx, { { fwd = true, hold = 2 } }, "remate: ajusta") return nil end
		elseif d >= (he.min_d or 0) then
			local rdh = radar(s, op)
			local rate = (op.crouching and 0.55 or 0.45) * math.min(1.5, rdh.hit * (is_low(hn.name) and rdh.low or 1))
			if (mem.op_parry_recent or 0) >= 2 then rate = rate * 0.3 end   -- el starter se lo parrea: agarre / esperar
			if math.random() < rate then
				mem.hunt_cd = s.frame + 24
				push(ctx, hseq, string.format("remate: %s -> %s [%d] (rival %d)", tostring(hn.name), he.label, he.dmg, rs.op_hp))
				mem.confirm = { start = s.frame }
				return nil
			end
		end
	end

	-- 6c) especiales de identidad del personaje (ch.specials, por rol): poke especial, zoning, approach
	if try_special(ctx, ch, mem, s, me, op, d, "poke") then return nil end
	if try_special(ctx, ch, mem, s, me, op, d, "zoning") then return nil end
	if d > ideal + 10 and try_special(ctx, ch, mem, s, me, op, d, "approach") then return nil end

	-- 7a) anti-zoning: fireball en camino que todavía no obliga a bloquear (k > block_lead) -> saltarlo,
	--     o tirar uno de vuelta; la decisión se toma una vez por proyectil
	if th and th.kind == "proj" and th.frames >= 15 and th.frames <= 28 and not me.airborne then
		local key = s.frame - th.frames                 -- aprox. estable por proyectil
		if not mem.proj_key or math.abs(mem.proj_key - key) > 6 then
			mem.proj_key = key
			local r = math.random()
			-- saltarlo solo de lejos (cerca, el rival anti-airea al caer: Gouki 26 anti-airs en un round)
			if can_jump and d >= 170 and d < 260 and r < 0.4 then
				push(ctx, MOVES.jump_in("hk"), "salta el fireball")
				mem.committed = true
				return nil
			elseif ch.fireball and charged(ctx, ch.fireball.charge) and r < 0.65 then
				push(ctx, clean_motion(ctx, ch.fireball.seq(), s.frame), "fireball de vuelta")
				mem.fireball_cd, mem.committed = ch.fireball.cooldown, true
				return nil
			end
		end
	end
	-- 7b) me están zoneando y no hay proyectil cerca: entrar rápido (dash / caminar), no esperar parado
	local op_proj_on_screen = false
	for _, pr in ipairs(s.proj or {}) do if pr.emitter ~= ctx.side then op_proj_on_screen = true end end
	if (mem.op_zoning or 0) >= 2 and d > ideal + 10 and not th and not op_proj_on_screen and mem.move_cd == 0 then
		mem.move_cd = 20
		if math.random() < 0.5 then push(ctx, MOVES.dash(), "dash entre fireballs")
		else push(ctx, MOVES.shimmy_in(10), "avanza entre fireballs") end
		return nil
	end
	-- 7c) spam de golpes que no me llegan: no quedarse mirando. Entrar (dash / salto) o acercarse a castigar
	if (mem.op_spam or 0) >= 3 and not th and d < ideal + 60 and mem.move_cd == 0 and cg_zone == 0 then
		mem.move_cd = 30
		local mv = pick({ { 3, "dash" }, { 2, "jump_in" }, { 3, "walk" }, { 1, "backdash" } })
		if mv == "dash" and d > 70 then push(ctx, MOVES.dash(), "dash vs spam")
		elseif mv == "jump_in" and can_jump and d > 80 and d < 170 then push(ctx, MOVES.jump_in("hk"), "salto vs spam") mem.committed = true
		elseif mv == "backdash" then push(ctx, MOVES.backdash(), "backdash vs spam")
		else push(ctx, MOVES.shimmy_in(safe_in(d, 6, mem.thr_op)), "se acerca vs spam") end
		return nil
	end
	-- 7d) anti-quietud: ~0.7 s sin moverme pudiendo actuar -> acción variada (nada de quedarse duro)
	if mem.still >= 42 and not th then
		mem.still, mem.move_cd = 0, 15
		-- online, dentro del alcance del rival (+30): nada de entrar caminando / dash / salto, que abrían combos gratis;
		-- moverse igual (no quedarse duro) pero hacia atrás o agachado en guardia. Afuera del alcance, como siempre
		local inside = CIPHER_EXT and d < math.max(op_poke_reach(op, me) + 30, cg_zone > 0 and cg_zone + 80 or 0)
		local press = (mem.aggr or 1) >= 1.5
		-- adentro: agacharse o entrar; nunca irse para atrás (era la fuente principal del "cagón")
		-- vs grappler adentro de su agarre SÍ salir (el anti-cagón lo dejaba pegado a Alex y lo agarraban)
		local in_cg = cg_zone > 0 and d < cg_zone and not near_wall
		local mv = inside and pick({ { in_cg and 1 or 4, "crouch" }, { in_cg and 0 or 3, "in" }, { in_cg and 4 or 0, "out" } })
			or pick({ { 3, "in" }, { 2, "out" }, { 2, "dash" }, { CIPHER_EXT and 0.2 or 1, "jump" }, { 2, "crouch" }, { 1, "backdash" } })
		if mv == "in" then push(ctx, MOVES.shimmy_in(safe_in(d, math.random(4, 10), mem.thr_op)), "camina")
		elseif mv == "out" then push(ctx, MOVES.shimmy_out(math.random(3, 7)), "retrocede")
		elseif mv == "dash" and d > 80 then push(ctx, MOVES.dash(), "dash")
		elseif mv == "jump" and can_jump and d > 90 and d < 170 then push(ctx, MOVES.jump_in("hk"), "salto") mem.committed = true
		elseif mv == "backdash" and d < 130 then push(ctx, MOVES.backdash(), "backdash")
		elseif inside then push(ctx, { { back = true, down = true, hold = math.random(8, 16) } }, "guardia agachado")
		else push(ctx, MOVES.crouch(math.random(6, 14)), "agachado") end
		return nil
	end
	if ch.fireball and not op.airborne and d >= ch.fireball.min_dist and mem.fireball_cd == 0 and charged(ctx, ch.fireball.charge)
		and math.random() < 0.05 then
		push(ctx, clean_motion(ctx, ch.fireball.seq(), s.frame), "fireball")
		mem.fireball_cd, mem.committed = ch.fireball.cooldown, true
		return nil
	end
	local op_idle = not op.attacking and not op.airborne and op.freeze == 0
	-- overhead universal MP+MK (wiki System: pega a quien bloquea agachado, activo al f16, los bajos no le pegan).
	-- Mezcla contra el rival que se queda agachado cerca; poco frecuente para que no se lo lea.
	-- overhead contra el que se queda agachado, también vs grappler (antes prohibido adentro de su rango); más seguido
	-- si el rival vive agachado
	local rdn = radar(s, op)                          -- radar del neutral (pokes / agarre / overhead)
	if op.crouching and op_idle and d < 75 and mem.move_cd == 0 and math.random() < ((cg_zone > 0) and 0.08 or 0.035) * rdn.over then
		mem.move_cd = 30
		push(ctx, PRESSURE.uoh(ch), ch.overhead and ch.overhead.name or "overhead universal")
		mem.confirm = { start = s.frame }
		mem.committed = true
		return nil
	end
	for _, pk in ipairs(ch.pokes) do
		local edge = d >= pk.range[2] - 25
		local rate = (cfg.poke_rate or 0.12) * (op_idle and 1.5 or 1)
		-- rival que parrea: menos pokes (cada poke parreado es un combo gratis para él)
		-- rival que parrea los pokes (Urien: parry al cr.MK y combo mientras el bot está trabado en la recuperación del
		-- golpe parreado, una y otra vez): con 1 parry en 30 s pokes al 30%, con 2+ al 10% -> agarres y esperar
		local opr = mem.op_parry_recent or 0
		if opr >= 2 then rate = rate * 0.1 elseif opr >= 1 then rate = rate * 0.3 end
		rate = rate * (mem.aggr or 1) * rdn.hit * (is_low(pk.anim) and rdn.low or 1)
		-- adentro del alcance de SUS pokes y él no está quieto: el poke cambia golpes o lo contraatacan -> la mitad
		if CIPHER_EXT and d <= op_poke_reach(op, me) and not op_idle then rate = rate * 0.5 end
		-- vs grappler (Hugo / Alex) el plan ES pokearlo justo afuera de su agarre: grande y lento. Antes Oro le hizo 23 de
		-- daño en un round (2 pokes): x3 y sin exigir la punta del alcance
		local vs_grap = cg_zone > 0 and d >= cg_zone and d <= cg_zone + 50
		if vs_grap then rate = rate * 3 end
		local reach = move_reach(me, op, pk)
		edge = d >= reach - 25
		-- online: 6 px adentro del alcance. En el borde exacto el rival se mueve, el poke erra y lo castigan
		-- (~90 combos recibidos tras un poke en una tarde)
		-- (6 -> 12 px: 41 cr.MK al aire en 11 peleas online; el rival se mueve entre que decido y que pega)
		local lim = CIPHER_EXT and (reach - 12) or reach
		-- cajas REALES (mi golpe vs su cuerpo en la RAM, con su movimiento): si conecta, vale hasta el alcance entero
		-- (los -12 px eran a ciegas y dejaban al bot sin pokear); si no conecta, no se tira
		-- (con "conecta -> alcance entero" el cr.MK de Ken erraba a 97 px contra Dudley que se agachaba y comía st.HK:
		-- online 6 px adentro y 8 px de solapamiento; las cajas solo DESCARTAN, no estiran)
		local bx = hit_check(me, op, pk.anim, 0, lat + 1, CIPHER_EXT and 8 or 0)
		if bx == true then lim = CIPHER_EXT and (reach - 6) or reach elseif bx == false then lim = -1 end
		-- nunca con el rival en el aire: el poke bajo pasaba por debajo del salto y nos comíamos el ataque aéreo
		if d >= pk.range[1] and d >= cg_zone and d <= lim and (edge or op_idle or vs_grap) and not op.airborne
			and math.random() < rate then
			push(ctx, pk.seq(), "poke " .. pk.name)
			mem.confirm = { start = s.frame }
			return nil
		end
	end
	-- agarre (grapplers: agarre de comando, más rango y mucho más seguido: es su plan de juego)
	local grab_d = grab_reach(ch, me, op)
	-- rival bloqueando / agachado quieto = lo que el agarre castiga (antes 12% fijo: agarrábamos 6 veces en 8 peleas)
	local turtle = op.crouching and not op.attacking
	local trate = ch.grappler and (turtle and 0.5 or 0.35) or (turtle and 0.3 or 0.12)
	if (mem.op_parry_recent or 0) >= 2 then trate = trate * 2.5 end   -- el agarre le gana al que parrea
	trate = math.min(0.9, trate * (mem.aggr or 1) * rdn.throw)
	-- vs grappler no: un agarre que erra (o que el rollback ve tarde) es un 360 gratis (Dudley vs Hugo online)
	-- online: 6 px de margen (posición del rival vieja por el rollback; los errados eran a 50-80 px)
	-- vs grappler AGACHADO bloqueando (Hugo tortuga: "bloqueaba todo, siempre agachado") el agarre es la respuesta: se
	-- habilita aunque sea grappler
	if d < grab_d - (CIPHER_EXT and 6 or 0) and (cg_zone == 0 or turtle) and throwable(s, mem, op) and math.random() < trate then
		push(ctx, ch.throw(), (ch.grappler and ch.command_grab) and ch.command_grab.name or "throw")
		mem.committed = true
		return nil
	end
	-- aproximación (antes: "walk in" en línea recta siempre -> caminaba directo a los pokes del rival). Fuera del alcance
	-- del rival camina; en el borde de su alcance mezcla como un jugador: paso, retroceso, guardia, dash o salto.
	if d > ideal + 10 then
		local op_reach = op_poke_reach(op, me)
		if d > op_reach + 25 then
			push(ctx, { { fwd = true, hold = 4 } }, "walk in")
			return nil
		end
		if mem.move_cd == 0 then
			mem.move_cd = 10
			-- en el borde del alcance del rival. Online: más guardia y retroceso, casi sin salto ni dash (entrar
			-- caminando / con dash / saltando abrió ~180 combos recibidos en una tarde)
			local on = CIPHER_EXT
			-- contra un zoner (2+ bolas recientes) la guardia lejos no sirve: hay que ganar terreno
			local zon = (mem.op_zoning or 0) >= 2 or cg_zone > 0 or (mem.aggr or 1) >= 1.5   -- presión: avanzar, no guardia lejos
			-- (online step 2 / guardia 6 -> 4 / 3: con 6 la guardia lejos dominaba y el bot no avanzaba)
			local mv = pick({ { (on and not zon) and 4 or 5, "step" }, { (zon or near_wall) and 0 or (on and 0.5 or 2), "back" }, { zon and 1 or (on and 3 or 3), "guard" },
				{ can_jump and cg_zone == 0 and d > 100 and d < 175 and (on and 0.3 or 2) or 0, "jump" },
				-- vs grappler el dash termina adentro del 360 (Moonsault durante un dash online)
				{ d > 90 and d < 200 and cg_zone == 0 and ((zon and 3) or (on and 0.4) or 1) or 0, "dash" } })
			if mv == "step" then push(ctx, MOVES.shimmy_in(safe_in(d, math.random(2, 4), mem.thr_op)), "tantea el rango")
			elseif mv == "back" then push(ctx, MOVES.shimmy_out(math.random(3, 5)), "sale del rango")
			elseif mv == "guard" then push(ctx, { { back = true, down = true, hold = math.random(8, 16) } }, "guardia en rango")
			elseif mv == "jump" then push(ctx, MOVES.jump_in("hk"), "salto") mem.committed = true
			else push(ctx, MOVES.dash(), "dash") end
			return nil
		end
		return { back = true, down = true }       -- entre decisiones: guardia
	end
	if not CIPHER_EXT and d < ideal - 45 and not near_wall and math.random() < (cfg.walk_back_rate or 0.2) then push(ctx, { { back = true, hold = 4 } }, "walk back") return nil end
	-- anti-grappler: pegado a Alex/Hugo (o después de comerme agarres) NO quedarse agachado bloqueando:
	-- un humano grappler vive de eso (vs Alex online: 2 agarres + 2 Power Bomb en un round -> stun)
	-- zona de peligro = alcance REAL del agarre de comando del rival contra mí (ranges.lua) + margen. Antes era d < 72
	-- fijo y al 30%: el 360 de Hugo llega a 111 px vs Chun, el Power Bomb de Alex a 104 -> 8 agarres en 2 rounds
	local GRAPPLERS = { alex = true, hugo = true }
	local danger, nthrow = 72, RG.throw(op.char_str, me.char_str, me.crouching) or 72
	if GRAPPLERS[op.char_str] then
		local cg = RG.prefix(op.char_str, op.char_str == "hugo" and "moonsault_press" or "power_bomb", me.char_str, me.crouching)
		danger = math.max(nthrow, cg or 100) + 8 + ((op.char_str == "hugo" and (op.meter or 0) >= 1) and 25 or 0)
	end
	-- adentro del alcance REAL del agarre de comando (deep) no hay escape de reacción (el 360 sale a 0-2 frames de
	-- verse) y bloquear / cr.LK / caminar pierden contra él (Chun vs Hugo: 9 agarros así). Adentro: salir YA (backdash,
	-- salto atrás si no me cazan con Shootdown); en el borde del rango: caminar atrás / guardia
	local cg_r = GRAPPLERS[op.char_str] and (danger - 8) or nthrow
	local deep = GRAPPLERS[op.char_str] and d < cg_r
	if me.has_just_been_thrown and op.move and op.move:find("shootdown") then mem.sbb_at = s.frame end
	local sbb = mem.sbb_at and s.frame - mem.sbb_at < 1800       -- me cazó saltando hace < 30 s
	if d < danger and not op.attacking and not op.airborne and op.freeze == 0
		and (GRAPPLERS[op.char_str] or ((mem.thrown_recent or 0) >= 1 and d < nthrow + 8))
		-- vs Alex 0.35 (antes 0.7): su agarre NORMAL lo resuelve el tech por radar; las escapadas constantes (salto atrás,
		-- caminar atrás, tech OS) se veían toscas y lo agarraban igual (19 agarres en una sesión). Hugo sigue en 0.9 (360)
		and mem.move_cd == 0 and math.random() < (deep and ((op.char_str == "hugo") and 0.9 or 0.35) or 0.15) / math.max(1, (mem.aggr or 1) - 0.3) then
		mem.move_cd = 10
		local in_throw = d < nthrow + 4
		local hugo = op.char_str == "hugo"
		local gr = GRAPPLERS[op.char_str]
		local mv = pick({
			-- vs agarre normal: el crouch tech primero (agarra -> techea; no agarra -> cr.LP); el jab solo pierde contra el
			-- agarre en su arranque (Dudley agarró a Oro en pleno cr.LK "anti-agarre")
			{ (not gr and in_throw) and 1 or 0, "jab" },
			-- contra la pared no hay para dónde retroceder (se encerraba en la esquina): salto adelante por encima
			{ (gr and not near_wall) and (deep and (hugo and 4 or 1) or 1) or 0, "backdash" },   -- vs Alex lo agarraban en el backdash
			-- vs Alex (agarre normal + Boomerang Raid): salir caminando del rango también desde adentro; el tech OS fallaba
			-- (lo agarraban durante el tech) y quedarse cerca es lo que el grappler quiere
			{ (gr and not near_wall and (not deep or not hugo)) and (hugo and 3 or 5) or 0, "walk_back" },
			-- afuera del 360 la guardia vale; vs Alex también adentro (agarre normal = tech por radar)
			{ (gr and not deep and 2) or (gr and not hugo and 4) or ((not gr) and 1) or 0, "guard" },
			-- vs Hugo NUNCA saltar para escapar: el Shootdown Backbreaker agarra en el aire (29 online)
			-- adentro del agarre normal no: los frames antes de despegar se agarran (vs Alex: 5 agarres "salto atrás")
			{ (can_jump and gr and not sbb and not near_wall and not hugo and not in_throw) and (deep and 3 or 1) or 0, "jump_back" },
			{ (gr and near_wall and deep) and (hugo and 1 or 3) or 0, "jump_fwd" },
			-- contra la pared vs Hugo: cortar su caminata con el golpe más rápido (no hay para dónde irse)
			{ (hugo and near_wall and deep) and 3 or 0, "jab" },
			{ (in_throw and not hugo) and (gr and 2 or 5) or 0, "tech" } })
		if mv == "walk_back" then
			push(ctx, { { back = true, hold = 10 } }, "anti-agarre sale del rango")
			return nil
		end
		if mv == "guard" then
			push(ctx, { { back = true, down = true, hold = 12 } }, "anti-agarre guardia")
			return nil
		end
		if mv == "jab" then push(ctx, input_lib.motion.press("lk", { down = true }, 2), "anti-agarre cr.LK")
		elseif mv == "backdash" then push(ctx, MOVES.backdash(), "anti-agarre backdash")
		elseif mv == "jump_back" then push(ctx, { { up = true, back = true, hold = 3 }, { hold = 30 } }, "anti-agarre salto atrás")
		elseif mv == "jump_fwd" then push(ctx, { { up = true, fwd = true, hold = 3 }, { hold = 30 } }, "anti-agarre salta afuera")
		-- crouch tech con el toque de 2 frames (el ch.tech() de 1 frame se podía perder online)
		else push(ctx, tech_os_seq(1), "anti-agarre tech") end
		mem.committed = true
		return nil
	end
	-- personajes de carga: en neutral, agachado atrás (bloquea bajos y acumula carga); a veces tantea adelante
	if ch.charge_moves then
		if mem.move_cd == 0 and math.random() < 0.03 then
			mem.move_cd = 25
			push(ctx, MOVES.shimmy_in(safe_in(d, math.random(3, 6), mem.thr_op)), "tantea (carga)")
			return nil
		end
		mem.label = "neutral (carga)"
		return { back = true, down = true }
	end
	-- con lag alto y el rival cerca: guardia agachada por defecto (como un humano con delay), no parado
	if lat >= 3 and d < 150 then
		mem.label = "guardia (lag " .. lat .. ")"
		return { back = true, down = true }
	end
	-- online (rollback): el golpe del rival aparece tarde y el bloqueo de reacción llega después del impacto
	-- (vs Makoto: "block crouch vs HP" con posture=0 = parado). Dentro del alcance de sus pokes: guardia ya puesta
	local threat = op_poke_reach(op, me) + 25
	if CIPHER_EXT and d < threat and not op.knocked_down then
		-- antes: guardia agachada SIEMPRE adentro de su alcance y todo lo demás al azar por frame -> el bot vivía agachado
		-- ("demasiado conservador, se la pasa agachado": 13% del tiempo solo en esta guardia). Guardia fija solo si el
		-- rival ataca / tira cosas; con el rival quieto, cada 8-14 frames una acción (entrar, poke, agarre, tantear) y
		-- guardia entre acciones
		local op_busy = op.attacking or th or (mem.op_spam or 0) >= 2
		if not op_busy and mem.move_cd == 0 and not op.airborne then
			mem.move_cd = math.random(8, 14)
			local a = mem.aggr or 1
			local inr
			for _, pk in ipairs(ch.pokes or {}) do
				-- cajas reales: si conecta vale todo el alcance; sin datos de cajas, 12 px adentro
				local bx = hit_check(me, op, pk.anim, 0, lat + 1, 8)
				local rr = move_reach(me, op, pk)
				if d >= pk.range[1] and d >= cg_zone and ((bx == true and d <= rr - 6) or (bx == nil and d <= rr - 12)) then
					inr = pk break
				end
			end
			local can_t = d < grab_reach(ch, me, op) - 6 and throwable(s, mem, op) and (cg_zone == 0 or op.crouching)
			local ph = (mem.op_parry_recent or 0) >= 2                  -- rival que parrea: menos pokes, más agarre
			local in_cg = cg_zone > 0 and d < cg_zone + 10              -- vs grappler: no entrar a su 360
			local rd = radar(s, op)
			local pmul = inr and (rd.hit * (is_low(inr.anim) and rd.low or 1)) or 0
			local mv = pick({ { (in_cg or safe_in(d, 3, mem.thr_op) == 0) and 0 or 3 * a, "step" }, { inr and (ph and 0.6 or 2) * a * pmul or 0, "poke" },
				{ can_t and (ph and 3 or 2) * a * rd.throw or 0, "throw" }, { 3 * rd.bait, "guard" }, { (near_wall or a >= 1.5) and 0 or 1, "back" },
				-- overhead contra la guardia agachada que muestra el radar
				{ (d < 75 and rd.over > 1) and 2 * rd.over or 0, "uoh" } })
			if mv == "uoh" then
				push(ctx, PRESSURE.uoh(ch), "presiona: overhead" .. rtag(rd))
				mem.confirm, mem.committed = { start = s.frame }, true
				return nil
			end
			if mv == "step" then push(ctx, MOVES.shimmy_in(safe_in(d, math.random(3, 6), mem.thr_op)), "presiona: entra") return nil
			elseif mv == "poke" then push(ctx, inr.seq(), "presiona: poke " .. inr.name .. rtag(rd)) mem.confirm = { start = s.frame } return nil
			elseif mv == "throw" then push(ctx, ch.throw(), ((ch.grappler and ch.command_grab) and ch.command_grab.name or "throw") .. rtag(rd)) mem.committed = true return nil
			elseif mv == "back" then push(ctx, MOVES.shimmy_out(3), "presiona: retrocede") return nil end
			push(ctx, { { back = true, down = true, hold = math.random(6, 10) } }, "guardia anticipada")
			return nil
		end
		mem.label = "guardia anticipada"
		return { back = true, down = true }
	end
	-- micro-movimientos humanos en el rango ideal (antes: nil = parado mirando); online solo fuera de su alcance
	if mem.move_cd == 0 and math.random() < 0.12 then
		mem.move_cd = 8
		local r = math.random()
		if r < 0.45 then push(ctx, MOVES.shimmy_in(safe_in(d, math.random(2, 5), mem.thr_op)), "tantea")
		elseif r < 0.8 then push(ctx, MOVES.shimmy_out(math.random(2, 4)), "tantea")
		else push(ctx, MOVES.crouch(math.random(4, 10)), "agachado") end
		return nil
	end
	mem.label = "neutral"
	return nil
end

function B.label(ctx) return ctx.mem and ctx.mem.label or "" end

return B
