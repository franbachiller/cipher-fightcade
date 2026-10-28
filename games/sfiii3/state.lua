-- Sensor SF3 3rd Strike: lee RAM -> snapshot normalizado por frame.
-- Direcciones: effie3rd/3rd_training_lua memory_addresses.lua (GPL-3.0) + validación CIPHER (data/sfiii3/ram-map.md).
local rb, rbs, rw, rws, rd = memory.readbyte, memory.readbytesigned, memory.readword, memory.readwordsigned, memory.readdword
local fdlib = require("games.sfiii3.framedata")

local S = {}

S.CHARS = { [0] = "gill", "alex", "ryu", "yun", "dudley", "necro", "hugo", "ibuki", "elena", "oro", "yang",
	"ken", "sean", "urien", "gouki", "shingouki", "chunli", "makoto", "q", "twelve", "remy" }

local G = {
	match_state = 0x020154A7, menu_state = 0x0201546B, frame = 0x02007F00, timer = 0x02011377,
	p1_locked = 0x020154C6, p2_locked = 0x020154C8,
	obj_index = 0x02068A96, obj_initial = 0x02028990,
}

local P = {
	{ base = 0x02068C6C, gauge = 0x020695B5, meter = 0x020695BF, max_gauge = 0x020695B3, sa_state = 0x020695AD,
	  selected_sa = 0x0201138B, superfreeze = 0x02069520, stun_max = 0x020695F7, combo = 0x020696C5,
	  parry = { fwd = { 0x02026335, 0x02025731, 0x02025733 }, down = { 0x02026337, 0x0202574D, 0x0202574F },
	            air = { 0x02026339, 0x02025769, 0x0202576B }, aa = { 0x02026347, 0x0202582D, 0x0202582F } },
	  sel = { row = 0x020154CF, col = 0x0201566B, sa = 0x020154D3, state = 0x0201553D, color = 0x02015683 } },
	{ base = 0x02069104, gauge = 0x020695E1, meter = 0x020695EB, max_gauge = 0x020695DF, sa_state = 0x020695D9,
	  selected_sa = 0x0201138C, superfreeze = 0x02069088, stun_max = 0x0206960B, combo = 0x0206961D,
	  parry = { fwd = { 0x0202673B, 0x02025D51, 0x02025D53 }, down = { 0x0202673D, 0x02025D6D, 0x02025D6F },
	            air = { 0x0202673F, 0x02025D89, 0x02025D8B }, aa = { 0x0202674D, 0x02025E4D, 0x02025E4F } },
	  sel = { row = 0x020154D1, col = 0x0201566D, sa = 0x020154D5, state = 0x02015545, color = 0x02015684 } },
}
S.P = P

-- offsets del struct de objeto (jugadores y proyectiles comparten layout)
local O = {
	friends = 0x01, emitter = 0x02, alive = 0x27, flip = 0x0A,
	x = 0x64, xm = 0x66, y = 0x68, ym = 0x6A, vx = 0x7C, vxm = 0x7E, vy = 0x80, vym = 0x82,
	ax = 0x84, axm = 0x86, ay = 0x88, aym = 0x8A,
	hp = 0x9F, freeze = 0x45, char = 0x3C0, valid = 0x2A0,
	anim = 0x202, frame_id = 0x21A, countdown = 0x214, id3 = 0x205,
	action = 0xAC, action_type = 0xAD, move2 = 0xAF, posture = 0x20E, posture_ext = 0x209,
	recovery_type = 0x207, recovery_time = 0x187, recovery_flag = 0x3B, standing_state = 0x297,
	being_thrown = 0x3CF, throw_countdown = 0x434, attacking = 0x428, action_count = 0x459,
	blocking_id = 0x3D3, hit_count = 0x189, input_capacity = 0x46C, busy = 0x3D1,
	recv_type = 0x339, recv_strength = 0x34F, recv_total = 0x33E, recv_marker = 0x32E,
	proj_type = 0x91, proj_hits = 0x9E, proj_life = 0x9A,
}
S.O = O

-- punteros a listas de cajas: {offset, cantidad}
local BOXES = {
	vuln = { 0x2A0, 4 }, ext_vuln = { 0x2A8, 4 }, attack = { 0x2C8, 4 }, throw = { 0x2B8, 1 },
	throwable = { 0x2C0, 1 }, push = { 0x2D4, 1 },
}

-- posturas (byte +0x20E)
local AIR = function(p) return p >= 0x14 and p <= 0x1E end
S.POSTURE = { stand = 0x00, fwd = 0x06, back = 0x08, crouch = 0x20, knockdown = 0x26 }

local function read_boxes(base, out)
	for kind, def in pairs(BOXES) do
		local list = out[kind]
		if list then for i = #list, 1, -1 do list[i] = nil end else list = {} out[kind] = list end
		local ptr = rd(base + def[1])
		if ptr ~= 0 then
			for i = 0, def[2] - 1 do
				local a = ptr + i * 8
				local l, w, b, h = rws(a), rws(a + 2), rws(a + 4), rws(a + 6)
				if l ~= 0 or w ~= 0 or b ~= 0 or h ~= 0 then list[#list + 1] = { l = l, w = w, b = b, h = h } end
			end
		end
	end
	return out
end

-- caja relativa -> mundo
function S.world_box(x, y, flip, bx)
	local l = (flip == 0) and (x + bx.l) or (x - bx.l - bx.w)
	local b = y + bx.b
	return l, l + bx.w, b, b + bx.h
end

local function read_object(o, base)
	o.base = base
	o.flip = rb(base + O.flip)
	o.x = rws(base + O.x) + rb(base + O.xm) / 256
	o.y = rws(base + O.y) + rb(base + O.ym) / 256
	o.vx = rws(base + O.vx) + rb(base + O.vxm) / 256
	o.vy = rws(base + O.vy) + rb(base + O.vym) / 256
	o.ax = rws(base + O.ax) + rb(base + O.axm) / 256
	o.ay = rws(base + O.ay) + rb(base + O.aym) / 256
	o.anim = string.format("%04x", rw(base + O.anim))
	o.hash = string.format("%04x%02x%02x", rw(base + O.frame_id), rb(base + O.countdown), rb(base + O.id3))
	o.boxes = read_boxes(base, o.boxes or {})
	return o
end

-- ---------------------------------------------------------------- jugadores
local prev = { {}, {} }
local rprev = { {}, {} }   -- radar de input (S.radar)

local function read_player(id, frame)
	local a, b = P[id], P[id].base
	local pl = prev[id]
	local was = { anim = pl.anim, attacking = pl.attacking, hit_count = pl.hit_count, action_count = pl.action_count,
	              blocking_id = pl.blocking_id, hp = pl.hp, recv_total = pl.recv_total, posture = pl.posture,
	              being_thrown = pl.being_thrown, freeze = pl.freeze, x = pl.x, parrying = pl.parrying }
	read_object(pl, b)
	pl.id = id
	pl.char = rw(b + O.char)
	pl.char_str = S.CHARS[pl.char] or "?"
	pl.hp = rb(b + O.hp)
	local fz = rb(b + O.freeze)
	pl.freeze = (fz >= 128) and (256 - fz) or fz
	pl.posture = rb(b + O.posture)
	pl.posture_ext = rb(b + O.posture_ext)
	pl.action = rd(b + O.action)
	pl.action_type = rb(b + O.action_type)
	pl.recovery_time = rb(b + O.recovery_time)
	pl.recovery_flag = rb(b + O.recovery_flag)
	pl.standing_state = rb(b + O.standing_state)
	pl.being_thrown = rb(b + O.being_thrown) ~= 0
	pl.throw_countdown = rb(b + O.throw_countdown)
	pl.attacking = rb(b + O.attacking) > 0
	pl.action_count = rb(b + O.action_count)
	pl.blocking_id = rb(b + O.blocking_id)
	pl.hit_count = rb(b + O.hit_count)
	pl.input_capacity = rw(b + O.input_capacity)
	pl.busy = rw(b + O.busy)
	pl.recv_total = rw(b + O.recv_total)
	pl.meter = rb(a.meter)
	pl.gauge = rb(a.gauge)
	pl.sa = rb(a.selected_sa) + 1
	pl.superfreeze = rb(a.superfreeze)
	pl.combo = rb(a.combo)
	pl.parry = {}
	for k, t in pairs(a.parry) do pl.parry[k] = { validity = rb(t[1]), cooldown = rb(t[2]), state = rb(t[3]) } end

	-- derivados
	pl.airborne = AIR(pl.posture) or pl.y > 0
	pl.crouching = pl.posture == 0x20 or pl.posture == 0x21
	pl.knocked_down = pl.posture == 0x26
	pl.is_blocking = pl.blocking_id > 0 and pl.blocking_id < 5
	-- blocking_id 5..8 = ventana de parry ABIERTA (también al caminar adelante), no parry exitoso
	pl.parry_window = pl.blocking_id >= 5 and pl.blocking_id <= 8
	-- conexión recibida (effie gamestate.lua): marker +0x32E != 0 en el frame del contacto;
	-- 0xFFF1 sin hit nuevo = parry real; otro marker sin hit = bloqueo; contador +0x33E sube = golpe
	pl.recv_marker = rw(b + O.recv_marker)
	local recv_diff = was.recv_total and ((was.recv_total == 0xFFFF) and 1 or (pl.recv_total - was.recv_total)) or 0
	pl.has_just_parried = pl.recv_marker == 0xFFF1 and recv_diff == 0
	pl.has_just_blocked_conn = pl.recv_marker ~= 0 and pl.recv_marker ~= 0xFFF1 and recv_diff == 0
	pl.has_just_received_hit = recv_diff > 0
	pl.is_parrying = pl.has_just_parried
	pl.has_just_attacked = pl.attacking and not was.attacking
	pl.has_just_hit = was.hit_count ~= nil and pl.hit_count > was.hit_count
	pl.has_just_been_hit = was.hp ~= nil and pl.hp < was.hp and not pl.is_blocking
	pl.has_just_blocked = pl.is_blocking and not (was.blocking_id and was.blocking_id > 0 and was.blocking_id < 5)
	pl.has_just_been_thrown = pl.being_thrown and not was.being_thrown

	-- stun (effie memory_addresses.lua / gamestate.lua): activate = stun_max - 3, timer = stun_max + 2.
	-- El timer baja mientras el rival está mareado (más rápido si machaca); termina con 0/>=250, golpe o agarre.
	local prev_timer = pl.stun_timer or 0
	pl.stun_activate = rb(a.stun_max - 3)
	pl.stun_timer = rb(a.stun_max + 2)
	if pl.stun_activate == 1 or (pl.stun_timer > 0 and pl.stun_timer < 250 and pl.stun_timer < prev_timer) then
		pl.is_stunned = true
	elseif pl.is_stunned and (pl.has_just_received_hit or pl.being_thrown or pl.stun_timer == 0 or pl.stun_timer >= 250) then
		pl.is_stunned = false
	end

	-- animación: frame por sync de hash contra la frame data, fallback a conteo
	if pl.anim ~= was.anim then
		pl.anim_start = frame
		pl.anim_freeze = 0
	end
	if pl.freeze > 0 then pl.anim_freeze = (pl.anim_freeze or 0) + 1 end
	pl.fd = fdlib.anim(pl.char_str, pl.anim)
	local synced = pl.fd and pl.fd.sync[pl.hash:sub(1, 8)]
	pl.anim_frame = synced or (frame - (pl.anim_start or frame) - (pl.anim_freeze or 0))
	pl.anim_synced = synced ~= nil
	pl.move = pl.fd and pl.fd.n or nil
	return pl
end

-- ---------------------------------------------------------------- proyectiles
local projs = {}
local function read_projectiles(frame)
	for k in pairs(projs) do projs[k].seen = false end
	local idx = rws(G.obj_index + 3 * 2)
	local guard = 0
	while idx ~= -1 and guard < 32 do
		guard = guard + 1
		local base = G.obj_initial + idx * 0x800
		if rd(base + O.valid) ~= 0 then
			local o = projs[base] or { first = frame }
			read_object(o, base)
			o.seen = true
			o.emitter = rb(base + O.emitter) + 1
			o.type = string.format("%02x", rb(base + O.proj_type))
			o.hits_left = rb(base + O.proj_hits)
			o.life = frame - o.first
			projs[base] = o
		end
		idx = rws(base + 0x1C)
	end
	local list = {}
	for k, o in pairs(projs) do
		if o.seen then list[#list + 1] = o else projs[k] = nil end
	end
	return list
end

-- ---------------------------------------------------------------- snapshot
function S.read()
	local frame = emu.framecount()
	local s = { frame = frame, game_frame = rd(G.frame), timer = rb(G.timer) }
	local ms = rb(G.match_state)
	s.match_state = ms
	s.in_match = ms == 0x02 and rb(G.menu_state) == 0x04
	s.p = { read_player(1, frame), read_player(2, frame) }
	s.p[1].other, s.p[2].other = s.p[2], s.p[1]
	for i = 1, 2 do
		local me, op = s.p[i], s.p[3 - i]
		me.facing_right = (op.x > me.x) or (op.x == me.x and me.flip == 1)
	end
	s.dist = math.abs(s.p[1].x - s.p[2].x)
	s.proj = read_projectiles(frame)
	S.world(s)
	S.radar(s, frame)
	return s
end

-- ---------------------------------------------------------------- radar: lo que cada jugador tiene APRETADO
-- Palabra de input del juego (P1 0x0206AA8C, P2 0x0206AA90; bits = core/output: 0 arriba, 1 abajo, 2 izq, 3 der,
-- 4 LP, 5 MP, 6 HP, 7 LK, 8 MK, 9 HK; direcciones absolutas). Online es el input que la emulación ya aplicó
-- (con el delay de red): lo sostenido (guardia) es confiable, los toques llegan 1-2 frames tarde.
-- Por jugador: inp = { back, fwd, down, up, lp..hk } relativo a dónde está el otro; guard = "crouch" (abajo-atrás),
-- "stand" (atrás), "down" (abajo sin atrás), "fwd", "neutral"; guard_n = frames seguidos en esa guardia;
-- tap_fwd / tap_down = frame del último toque adelante / abajo (intento de parry); tech_at = último LP+LK
G.input = { 0x0206AA8C, 0x0206AA90 }
function S.radar(s, frame)
	for i = 1, 2 do
		local me, op = s.p[i], s.p[3 - i]
		local w = rw(G.input[i]) % 1024
		local function b(n) return math.floor(w / 2 ^ n) % 2 == 1 end
		local right_side = op.x > me.x or (op.x == me.x and me.flip == 1)   -- el otro a mi derecha: atrás = izquierda
		local inp = { up = b(0), down = b(1), lp = b(4), mp = b(5), hp = b(6), lk = b(7), mk = b(8), hk = b(9) }
		inp.back = right_side and b(2) or b(3)
		inp.fwd = right_side and b(3) or b(2)
		me.inp, me.inp_word = inp, w
		local g = (inp.down and inp.back and "crouch") or (inp.back and "stand") or (inp.down and "down")
			or (inp.fwd and "fwd") or "neutral"
		local pr = rprev[i]
		me.guard = g
		me.guard_n = (pr.guard == g) and ((pr.guard_n or 0) + 1) or 1
		me.tap_fwd = (inp.fwd and not pr.fwd) and frame or pr.tap_fwd
		me.tap_down = (inp.down and not pr.down) and frame or pr.tap_down
		me.tech_at = (inp.lp and inp.lk) and frame or pr.tech_at
		rprev[i] = { guard = g, guard_n = me.guard_n, fwd = inp.fwd, down = inp.down, tap_fwd = me.tap_fwd,
			tap_down = me.tap_down, tech_at = me.tech_at }
	end
end

-- ---------------------------------------------------------------- entorno: escenario, cámara y paredes reales
-- Escenario (0x020154F5) y cámara (0x02026CB0) de la RAM + física por personaje (data/sfiii3/char_physics.lua).
-- Pared de escenario de cada jugador = límite del escenario +/- su offset (Ken en su escenario: 80 + 28 = 108, lo
-- medido online). Además el par tiene que entrar en la pantalla (384 px): con el rival lejos, el borde de pantalla
-- también es pared. Por jugador: wall_l / wall_r (escenario), lim_l / lim_r (efectivos), room_back / room_front
-- (px hasta la pared detrás / delante, mirando al rival), stage_back (hasta la pared de ESCENARIO detrás)
G.stage, G.screen_x = 0x020154F5, 0x02026CB0
local PHYS
do
	local root = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])games[\\/]") or ".\\")
	local ok, t = pcall(dofile, root .. "data\\sfiii3\\char_physics.lua")
	PHYS = ok and type(t) == "table" and t or { chars = {}, stages = {} }
end
S.PHYS = PHYS
local DEF_CH = { fwd = 3.2, back = -2.6, off_l = 28, off_r = 27, push_w = 50, h_stand = 104, h_crouch = 66 }
local DEF_ST = { left = 80, right = 943, screen_left = 272, screen_right = 752 }
function S.phys(char) return PHYS.chars[char] or DEF_CH end
function S.world(s)
	s.stage = rb(G.stage)
	s.screen_x = rws(G.screen_x)
	local stg = PHYS.stages[s.stage] or DEF_ST
	s.stage_info = stg
	local p1, p2 = s.p[1], s.p[2]
	local left, right = (p1.x <= p2.x) and p1 or p2, (p1.x <= p2.x) and p2 or p1
	local sep_max = 383 - S.phys(left.char_str).off_l - S.phys(right.char_str).off_r
	for i = 1, 2 do
		local me, op = s.p[i], s.p[3 - i]
		local ph = S.phys(me.char_str)
		me.phys = ph
		me.wall_l, me.wall_r = stg.left + ph.off_l, stg.right - ph.off_r
		me.lim_l, me.lim_r = me.wall_l, me.wall_r
		if me == left then me.lim_l = math.max(me.wall_l, op.x - sep_max) else me.lim_r = math.min(me.wall_r, op.x + sep_max) end
		local op_right = op.x > me.x or (op.x == me.x and me.flip == 1)
		me.room_back = op_right and (me.x - me.lim_l) or (me.lim_r - me.x)
		me.room_front = op_right and (me.lim_r - me.x) or (me.x - me.lim_l)
		me.stage_back = op_right and (me.x - me.wall_l) or (me.wall_r - me.x)
	end
end

function S.reset()
	prev = { {}, {} }
	rprev = { {}, {} }
	projs = {}
end

return S
