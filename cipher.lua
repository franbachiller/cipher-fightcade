-- CIPHER-Fightcade · entrypoint. Cargar desde fcadefbneo: Game > Lua Scripting > New Lua Script Window > cipher.lua
local ROOT = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])") or ".\\"
package.path = ROOT .. "?.lua;" .. ROOT .. "?\\init.lua;" .. package.path

local cfg     = dofile(ROOT .. "config.lua")
-- overrides para pruebas automáticas
if os.getenv("CIPHER_AUTOSTART") == "1" then cfg.enabled, cfg.debug = true, true end
-- health check / pruebas offline: recorrer las ramas del modo online (rollback) sin el runtime externo
if os.getenv("CIPHER_FORCE_EXT") == "1" then CIPHER_EXT = true end
if tonumber(os.getenv("CIPHER_SIDE") or "") then cfg.side = tonumber(os.getenv("CIPHER_SIDE")) end
if os.getenv("CIPHER_OUTPUT") then cfg.output = os.getenv("CIPHER_OUTPUT") end
if os.getenv("CIPHER_BRAIN") then cfg.brain = os.getenv("CIPHER_BRAIN") end
if tonumber(os.getenv("CIPHER_SEED") or "") then math.randomseed(tonumber(os.getenv("CIPHER_SEED"))) end
local SPAR = os.getenv("CIPHER_SPAR")             -- brain de sparring para el otro lado (solo backend lua)
if SPAR == "" then SPAR = nil end
local log     = require("core.log")
local hotkeys = require("core.hotkeys")
input_lib     = require("core.input")             -- global para brains/chars
local overlay = require("core.overlay")
local output  = require("core.output")
local metrics = require("core.metrics")
local history = require("core.history")
-- defensa de effie: necesita la librería bit (LuaJIT en el runtime externo; la Lua de FBNeo ya la trae)
EFFIE = nil
if os.getenv("CIPHER_NO_EFFIE") ~= "1" then
	local okb = pcall(function() return bit or require("bit") end)
	if okb then
		EFFIE = require("core.effie_bridge")
		EFFIE.init()
		-- IA de neutral de effie (footsies) para el bot: se inicializa en el primer frame de pelea
		if os.getenv("CIPHER_EFFIE_FOOTSIES") ~= "0" then EFFIE.footsies_on = true end      -- por defecto: activo
		log_effie_status = EFFIE.ok and "effie: defensa activa" or ("effie: no disponible (" .. tostring(EFFIE.err) .. ")")
	end
end

-- romname -> carpeta de adapter
local ALIASES = { sfiii3nr1 = "sfiii3", sfiii3 = "sfiii3", sfiii3n = "sfiii3", sfiii3an = "sfiii3" }

local function resolve_game()
	for _, name in ipairs({ emu.romname(), emu.parentname and emu.parentname() or nil }) do
		if name and name ~= "" then
			local id = ALIASES[name] or name
			local ok, mod = pcall(require, "games." .. id .. ".game")
			if ok then return mod end
		end
	end
	return nil
end

log.init(ROOT, cfg.log)
if log_effie_status then log.write(log_effie_status) end
output.init(cfg.output)
local game = resolve_game()
if not game then
	log.write("juego no soportado: %s", tostring(emu.romname()))
	error("CIPHER: juego no soportado: " .. tostring(emu.romname()))
end

local function new_ctrl(brain_name, side)
	local c = { cfg = cfg, side = side, queue = input_lib.new(), cooldown = 0, brain_name = brain_name }
	c.brain = require("games." .. game.name .. ".brains." .. brain_name)
	c.brain.reset(c)
	return c
end

local app = { cfg = cfg, game = game, output = output, state = nil }
app.bot = new_ctrl(cfg.brain, cfg.side)
app.spar = SPAR and new_ctrl(SPAR, 3 - cfg.side) or nil

local function set_enabled(v)
	cfg.enabled = v
	app.bot.queue:clear()
	app.bot.brain.reset(app.bot)
	if not v then output.release() end
	log.write("bot %s (P%d) brain=%s backend=%s", v and "ON" or "OFF", cfg.side, cfg.brain, output.backend())
end

local actions = {
	toggle  = function() set_enabled(not cfg.enabled) end,
	side    = function()
		cfg.side = 3 - cfg.side
		app.bot.side = cfg.side
		app.bot.queue:clear()
		if app.spar then app.spar.side = 3 - cfg.side end
		log.write("side -> P%d", cfg.side)
	end,
	overlay = function() cfg.overlay = not cfg.overlay end,
	debug   = function() cfg.debug = not cfg.debug end,
}
for name, key in pairs(cfg.keys) do hotkeys.bind(key, actions[name]) end
for name, n in pairs(cfg.luahotkeys) do hotkeys.bindlua(n, actions[name]) end

log.write("CIPHER start rom=%s parent=%s output=%s brain=%s spar=%s root=%s",
	tostring(emu.romname()), tostring(emu.parentname and emu.parentname()), cfg.output, cfg.brain, tostring(SPAR), ROOT)

-- ANTI-TURBO: Fightcade marca "Turbo" a los rivales cuando un botón se aprieta y suelta con ritmo de autofire. Ningún
-- botón puede volver a apretarse antes de 4-5 frames (variable) desde su apretada anterior: máximo ~13 por segundo
-- e irregular, como un humano machacando. Aplica a todo lo que sale (brain, effie, combos, especiales de machacar)
local BTN_NAMES = { "Weak Punch", "Medium Punch", "Strong Punch", "Weak Kick", "Medium Kick", "Strong Kick" }
local function anti_turbo(c, j, side, frame)
	if not j then return j end
	-- el tech de agarre (LP+LK en una ventana de 5f) nunca se frena: perderlo es comerse el agarre
	local lbl = c.mem and c.mem.label
	if lbl and lbl:find("tech") then
		c.btn_prev = c.btn_prev or {}
		local pre = "P" .. side .. " "
		for _, b in ipairs(BTN_NAMES) do c.btn_prev[pre .. b] = j[pre .. b] and true or false end
		return j
	end
	c.btn_prev = c.btn_prev or {}
	c.btn_next = c.btn_next or {}
	local pre = "P" .. side .. " "
	for _, b in ipairs(BTN_NAMES) do
		local k = pre .. b
		local down = j[k] and true or false
		if down and not c.btn_prev[k] then                       -- apretada nueva
			if frame < (c.btn_next[k] or 0) then
				j[k] = false                                     -- demasiado pronto: queda suelto este frame
				down = false
			else
				c.btn_next[k] = frame + math.random(4, 5)
			end
		end
		c.btn_prev[k] = down
	end
	return j
end

-- historial de los últimos 12 inputs reales del bot (para el hit-diag: qué apretaba antes de que le peguen)
local function remember(c, j, side)
	if not j then return end
	local pre = "P" .. side .. " "
	local s = (j[pre .. "Left"] and "<" or "") .. (j[pre .. "Right"] and ">" or "") .. (j[pre .. "Down"] and "v" or "")
		.. (j[pre .. "Up"] and "^" or "")
	for _, b in ipairs({ "Weak Punch", "Medium Punch", "Strong Punch", "Weak Kick", "Medium Kick", "Strong Kick" }) do
		if j[pre .. b] then s = s .. "*" break end
	end
	c.hist = c.hist or {}
	table.insert(c.hist, (s == "" and "." or s))
	if #c.hist > 12 then table.remove(c.hist, 1) end
end

-- corre un controlador y devuelve su tabla joypad resuelta (o nil si no hay que tocar nada)
local function run_ctrl(c, s)
	local me, op = s.p[c.side], s.p[3 - c.side]
	-- keys desde el hook "before": la tecla entra 1 frame tarde. Externo: se decide al terminar el frame N
	-- y la tecla se lee al empezar N+1, igual que joypad.set (0).
	c.latency = (output.backend() == "keys" and c == app.bot) and (CIPHER_EXT and (app.input_delay or EXT_LATENCY) or 1) or 0
	-- defensa de effie (bloqueo / parry / red parry / tech / stun / quick stand) con nuestro personaje como dummy
	if c == app.bot and EFFIE and EFFIE.ok and EFFIE.footsies_on and not EFFIE.footsies_wanted then EFFIE.want_footsies(c.side) end
	CIPHER_EFFIE_LAG = c.latency or 0      -- effie anticipa el bloqueo/parry por el input delay real (online)
	local eff = (c == app.bot and EFFIE and EFFIE.ok) and EFFIE.frame(c.side) or nil
	c.effie = EFFIE and EFFIE.ok and c == app.bot
	local ok, res = pcall(c.brain.think, c, s, me, op)
	if not ok then
		log.write("brain %s error: %s", c.brain_name, tostring(res))
		c.queue:clear()
		return nil
	end
	-- effie manda en defensa, salvo que estemos ejecutando una secuencia comprometida (combo / especial propio)
	-- el brain está entrando un parry (frame neutral + toque): effie no lo pisa con su bloqueo
	-- y durante la ventana del parry (volver a "atrás" lo convierte en bloqueo)
	local parrying = c.mem and ((c.mem.parry_tap_frame and s.frame <= c.mem.parry_tap_frame)
		or (c.mem.parry_until and s.frame <= c.mem.parry_until))
	if eff and not parrying and not (c.mem and c.mem.committed and c.queue:busy()) then
		c.mem.label = "effie defensa"
		-- online: guardia de effie SIEMPRE agachada si el rival está en el piso. Con delay 1-2 effie ve el cr.MK tarde
		-- y bloqueaba parado (Ryu vs Ken: 10 de 11 combos recibidos entraron "bloqueando" parado, 5 con cr.MK).
		-- Los overheads son mucho menos frecuentes que los bajos; vs saltos sigue parado
		local pre = "P" .. c.side .. " "
		local holding_back = (op.x > me.x and eff[pre .. "Left"]) or (op.x < me.x and eff[pre .. "Right"])
		-- ...salvo overhead previsto por el brain (f.HP de Urien: 4 golpes con la guardia forzada agachada)
		local over = c.mem and c.mem.th_over and s.frame - c.mem.th_over <= 2
		if CIPHER_EXT and holding_back and not op.airborne and not eff[pre .. "Up"] and not over then
			eff[pre .. "Down"] = true
		end
		EFFIE.post(c.side, eff)
		if c.prev_fwd then c.fwd_release = s.frame end
		c.prev_fwd = false
		if me.is_blocking then c.guard_at, c.guard_abs = s.frame, eff end   -- solo bloqueo real (ver abajo)
		if c == app.bot then eff = anti_turbo(c, eff, c.side, s.frame) remember(c, eff, c.side) end
		return eff
	end
	local q_empty = not c.queue:busy()
	local frame = res or c.queue:pop()
	-- sin decisión (el brain no devolvió nada y la cola está vacía) con el rival cerca y en el piso: GUARDIA agachada por
	-- defecto, como un jugador real. Antes soltaba todo ("." en el historial de inputs) y el tatsu de Gouki (pega en el
	-- frame 2) o cualquier golpe rápido entraba con el bot parado sin hacer nada. Overhead previsto -> parado
	if c == app.bot and res == nil and q_empty and not op.airborne and not op.knocked_down
		and math.abs(op.x - me.x) < math.min(160, (c.mem and c.mem.guard_range) or 160) then
		local over = c.mem and c.mem.th_over and s.frame - c.mem.th_over <= 2
		frame = over and { back = true } or { back = true, down = true }
	end
	-- dash accidental: adelante, soltar y adelante otra vez en <= 10 frames = dash. "tantea el rango" (toque + soltar)
	-- seguido de "walk in" salía como doble dash al frente y tardaba en pegar (Ken vs Hugo online). Solo pasa el dash
	-- pedido a propósito; los motions (con abajo / botones) no se tocan.
	local lbl = tostring(c.mem and c.mem.label)
	local pure_fwd = frame and frame.fwd and not (frame.up or frame.down or frame.back or frame.lp or frame.mp
		or frame.hp or frame.lk or frame.mk or frame.hk)
	-- el "adelante" que abre un motion (shoryuken f,d,df / hyakki): lo que queda en la cola tiene abajo o botones.
	-- Sin esto el Hyakki de Gouki salía cr.LK (se comía el primer adelante) y el shoryuken de castigo igual
	local motion = false
	for _, f in ipairs(c.queue.q or {}) do
		if f.down or f.up or f.lp or f.mp or f.hp or f.lk or f.mk or f.hk then motion = true break end
	end
	-- solo si el adelante anterior fue un TOQUE corto (<= 4 frames): el dash son dos toques. Tras una caminata larga no hay
	-- dash posible y el filtro solo recortaba los pasos (el bot avanzaba a los tirones o no avanzaba)
	if pure_fwd and not motion and not c.prev_fwd and c.fwd_release and s.frame - c.fwd_release <= 10
		and (c.fwd_len_last or 0) <= 4 and not lbl:find("dash") then
		frame = {}
	end
	-- guardia sin temblor: después de bloquear (effie o guardia propia), 8 frames sin caminar adelante. Bloqueo ->
	-- caminar -> bloqueo frame a frame se veía como izquierda-derecha a velocidad de robot (bolas, presión). Los
	-- motions, el toque del parry y los dashes pedidos pasan igual
	-- (agachado-atrás EN EL LUGAR, 4 frames: antes devolvía la guardia guardada, que parada es CAMINAR ATRÁS, 8 frames
	-- cada vez que quería avanzar después de bloquear: el bot retrocedía todo el tiempo)
	if pure_fwd and not motion and c.guard_at and s.frame - c.guard_at <= 4 and not lbl:find("dash")
		and not lbl:find("^parry") and not lbl:find("post%-parry") and not lbl:find("punish") and not lbl:find("fireballs") then
		frame = { back = true, down = true }
	end
	if c.prev_fwd and not (frame and frame.fwd) then c.fwd_release, c.fwd_len_last = s.frame, c.fwd_len or 0 end
	if frame and frame.fwd then c.fwd_len = c.prev_fwd and ((c.fwd_len or 0) + 1) or 1 end
	c.prev_fwd = frame and frame.fwd or false
	-- carga (Chun-Li, Remy, Urien...): frames seguidos sosteniendo atrás / abajo
	c.charge = c.charge or { h = 0, v = 0 }
	c.charge.h = (frame and frame.back) and (c.charge.h + 1) or 0
	c.charge.v = (frame and frame.down) and (c.charge.v + 1) or 0
	-- guardia pura (atrás sin adelante ni botones): "atrás" según la POSICIÓN del rival, no hacia dónde mira mi
	-- personaje. En un crossup (j.MK de Ibuki) el rival ya pasó al otro lado y mirar la cara bloqueaba al revés
	local facing = me.facing_right
	if frame and frame.back and not frame.fwd and not (frame.lp or frame.mp or frame.hp or frame.lk or frame.mk or frame.hk) then
		local op = s.p[3 - c.side]
		if op and math.abs(op.x - me.x) >= 4 then facing = op.x > me.x end
	end
	local final = input_lib.resolve(c.side, frame, facing)
	-- histéresis de guardia SOLO tras un bloqueo REAL del juego (is_blocking). Antes cualquier frame atrás (la guardia por
	-- defecto, la guardia anticipada, el mismo paso convertido) reiniciaba guard_at -> cada paso adelante se volvía
	-- agachado y el bot NO PODÍA AVANZAR ("remate: se acerca" 8 s a d=97 inmóvil; agachado frente al rival agachado)
	if me.is_blocking then
		c.guard_at, c.guard_abs = s.frame, final
	end
	if c == app.bot then final = anti_turbo(c, final, c.side, s.frame) end
	if c.effie then EFFIE.post(c.side, final) end     -- effie necesita el input REAL del frame
	if c == app.bot then remember(c, final, c.side) end
	return final
end

local last_dump, last_label = 0, ""
local function frame_main()
	hotkeys.poll()
	output.tick(emu.framecount())
	local s = game.read_state()
	app.state = s
	metrics.update(s)
	if output.backend() == "keys" then                 -- jugando con la consola (online): historial de peleas
		if not app.hist_init then history.init(ROOT) app.hist_init = true end
		local me = s.p[cfg.side]
		local sa = game.sa_select and game.sa_select.name(me.char_str, me.sa) or tostring(me.sa)
		local r = history.update(s, metrics, cfg.side, sa, app.input_delay)
		if r then
			output.status(string.format("msg=Pelea %s: %s vs %s  %d-%d", (r.w > r.l) and "GANADA" or "PERDIDA", r.me, r.op, r.w, r.l))
		end
	end

	if cfg.log and s.frame % 60 == 0 and s.frame ~= last_dump then
		last_dump = s.frame
		local opp = s.p[3 - cfg.side]
		log.write("match=%s timer=%d dist=%d | P1 %s hp=%d x=%d y=%d | P2 %s hp=%d x=%d y=%d | bot=%s P%d [%s] radar=%s/%d",
			tostring(s.in_match), s.timer, s.dist,
			s.p[1].char_str, s.p[1].hp, s.p[1].x, s.p[1].y, s.p[2].char_str, s.p[2].hp, s.p[2].x, s.p[2].y,
			tostring(cfg.enabled), cfg.side, app.bot.brain.label and app.bot.brain.label(app.bot) or "",
			tostring(opp and opp.guard), opp and opp.guard_n or 0)
	end

	if cfg.debug and s.frame % 600 == 0 and s.in_match then log.write("METRICS %s", metrics.summary()) end
	-- memoria de Lua (health check: el intérprete de FBNeo es de 32 bits y una fuga lo revienta con "not enough memory")
	if s.frame % 600 == 0 then log.write("MEM %.0f KB", collectgarbage("count")) end
	-- perfil de memoria (CIPHER_MEMPROF=1): elementos alcanzables desde cada módulo cargado y globales, para ver cuál crece
	if os.getenv("CIPHER_MEMPROF") == "1" and s.frame % 600 == 0 then
		local seen = {}
		local function count(t, depth)
			if type(t) ~= "table" or seen[t] or depth > 8 then return 0 end
			seen[t] = true
			local n = 0
			for k, v in pairs(t) do n = n + 1 + count(v, depth + 1) + (type(k) == "table" and count(k, depth + 1) or 0) end
			return n
		end
		local rows = {}
		for name, m in pairs(package.loaded) do
			if type(m) == "table" and name ~= "_G" then rows[#rows + 1] = { name, count(m, 0) } end
		end
		for name, v in pairs(_G) do
			if type(v) == "table" and not package.loaded[name] and name ~= "_G" then rows[#rows + 1] = { "G." .. name, count(v, 0) } end
		end
		-- detalle por campo de un módulo (CIPHER_MEMPROF_MOD=src.tools)
		local mod = os.getenv("CIPHER_MEMPROF_MOD")
		if mod and package.loaded[mod] then
			seen = {}
			rows = {}
			for k, v in pairs(package.loaded[mod]) do rows[#rows + 1] = { mod .. "." .. tostring(k), count(v, 0) } end
		end
		table.sort(rows, function(a, b) return a[2] > b[2] end)
		local parts = {}
		for i = 1, math.min(12, #rows) do parts[#parts + 1] = rows[i][1] .. "=" .. rows[i][2] end
		log.write("MEMPROF %s", table.concat(parts, " "))
	end

	-- CIPHER Console (pipe conectado = backend keys): autoactivar, estado y lado automático
	local console = output.backend() == "keys"
	if console and not app.console_seen then
		app.console_seen = true
		cfg.enabled = true
		log.write("CIPHER Console detectada: bot activado")
	end
	if console then
		local me, op = s.p[cfg.side], s.p[3 - cfg.side]
		if s.frame % 15 == 0 then
			local lb = (app.bot.brain.label and app.bot.brain.label(app.bot) or ""):gsub("|", "/")
			output.status(string.format("bot=%s|side=%d|auto=%s|dl=%s|me=%s|op=%s|sa=%s|act=%s|hp=%s",
				cfg.enabled and "on" or "off", cfg.side, app.side_auto and "1" or "0", tostring(app.input_delay or "?"),
				me.char_str, op.char_str,
				(s.in_match and game.sa_select) and game.sa_select.name(me.char_str, me.sa) or "-", lb,
				s.in_match and string.format("%d - %d   (tiempo %d)", (me.hp == 255) and 0 or me.hp, (op.hp == 255) and 0 or op.hp, s.timer)
					or "fuera de pelea"))
		end
		-- lado automático, invisible: lo que mandamos por teclado contra el input que el juego leyó para P1 y P2
		-- (con delay de GGPO de 0..SIDE_D frames). El jugador cuyo input copia nuestras teclas es el local.
		if game.read_input then
			local SIDE_D = 12
			local sd = app.sd or { hist = {}, score = { {}, {} } }
			app.sd = sd
			table.insert(sd.hist, 1, math.max(output.last_mask or 0, 0))
			if #sd.hist > SIDE_D + 2 then sd.hist[#sd.hist] = nil end
			if cfg.enabled then                      -- también en la pantalla de SA (ahí apretamos teclas)
				local best, bestd = {}, {}
				for p = 1, 2 do
					local v, b = game.read_input(p), 0
					for d = 0, SIDE_D do
						-- solo frames donde NUESTRA máscara cambió: sostener "abajo" coincide en ambos lados
						-- (online detectó P2 por 8 frames con los dos agachados)
						local m, mp = sd.hist[d + 1], sd.hist[d + 2]
						if m and mp and m ~= mp then
							local e = sd.score[p][d] or { ok = 0, n = 0 }
							e.n, e.ok = e.n * 0.97 + 1, e.ok * 0.97 + ((m == v) and 1 or 0)
							sd.score[p][d] = e
						end
						local e = sd.score[p][d]
						if e and e.n >= 6 and e.ok / e.n > b then b, bestd[p] = e.ok / e.n, d end
					end
					best[p] = b
				end
				-- delay real teclado -> juego (GGPO input delay online, 0 offline): latencia del cerebro
				local dl = app.side_auto and best[cfg.side] >= 0.8 and bestd[cfg.side]
				-- histéresis: cambiar solo si el nuevo delay explica claramente mejor que el actual (saltaba 0/1/0/1)
				if dl and dl ~= app.input_delay and app.input_delay then
					local e = sd.score[cfg.side][app.input_delay]
					if e and e.n > 0 and best[cfg.side] - e.ok / e.n < 0.05 then dl = nil end
				end
				if dl and dl ~= app.input_delay then
					app.input_delay = dl
					log.write("input delay medido: %d frames (match %.2f)", dl, best[cfg.side])
				end
				-- histéresis: ya detectado, cambiar de lado exige evidencia más fuerte
				-- (el lado que viene del menú de SA es provisional: se corrige sin histéresis)
				local firm = app.side_src == "input"
				local need, margin = firm and 0.9 or 0.8, firm and 0.5 or 0.3
				local side = (best[1] >= need and best[1] - best[2] >= margin) and 1
					or ((best[2] >= need and best[2] - best[1] >= margin) and 2 or nil)
				if side and (side ~= cfg.side or app.side_src ~= "input") and s.in_match then
					if side ~= cfg.side then app.bot.queue:clear() end
					cfg.side, app.bot.side, app.side_auto, app.side_src = side, side, true, "input"
					log.write("lado detectado: P%d (match P1=%.2f P2=%.2f)", side, best[1], best[2])
				end
			end
		end
		app.was_in_match = s.in_match
	else
		app.was_in_match = s.in_match
	end

	-- SA: en la pantalla de SA el bot elige el guardado para el personaje; en la pelea, recuerda el usado
	if console and game.sa_select then
		if not s.in_match then
			app.sa_checked = false
			if cfg.enabled then
				local m, char, want = game.sa_select.tick(s.frame, cfg.side, app.side_auto)
				local ds = game.sa_select.detected
				if ds then
					game.sa_select.detected = nil
					if ds ~= cfg.side then app.bot.queue:clear() end
					cfg.side, app.bot.side, app.side_auto, app.side_src = ds, ds, true, "menu"
				end
				if m then
					if char then output.status("msg=SA: " .. char .. " -> " .. game.sa_select.name(char, want)) end
					output.raw(m)
					return
				end
			end
		elseif app.side_src == "input" and not app.sa_checked then   -- solo con el lado confirmado en pelea
			app.sa_checked = true
			local me = s.p[cfg.side]
			local diff, want = game.sa_select.learn(me)
			if diff then
				output.status("msg=OJO SA distinto: " .. me.char_str .. " pelea con " .. game.sa_select.name(me.char_str, me.sa)
					.. " (elegido " .. game.sa_select.name(me.char_str, want) .. ")")
			end
		end
	end

	if not s.in_match then          -- fuera de pelea: control humano (menús)
		output.release()
		return
	end

	-- GGPO rollback: si el framecount no avanza (re-simulación) no se decide ni se consume la cola.
	if app.last_frame and s.frame <= app.last_frame and s.frame > app.last_frame - 30 then return end
	app.last_frame = s.frame

	local merged
	if app.spar then merged = run_ctrl(app.spar, s) end
	if cfg.enabled then
		local t = run_ctrl(app.bot, s)
		if cfg.debug and app.bot.brain.label then
			local lb = app.bot.brain.label(app.bot)
			if lb ~= last_label then log.write("bot: %s", lb) last_label = lb end
		end
		if output.backend() == "keys" then
			if t then output.apply(cfg.side, t) end
		elseif t then
			merged = merged or {}
			for k, v in pairs(t) do merged[k] = v end
		end
	end
	if merged then joypad.set(merged) end      -- joypad.set limpia overrides previos: una sola llamada por frame
end


-- fin de frame (lo que hace el main de effie al terminar before_frame): vaciar los pools de tablas de effie y avanzar
-- el GC. DEBE ir después de todo el frame: liberar antes de run_ctrl borraba datos que effie todavía usaba (colgaba).
local function end_of_frame()
	-- recolector de basura por frame (lo que hace el main de effie con tools.GC:update()). Sin esto la basura de
	-- gamestate/prediction de effie se acumulaba ~50 MB cada 10 s de pelea hasta "not enough memory" (health check)
	local gc_tools = package.loaded["src.tools"]
	-- pools de tablas de effie: "se vacían al final de cada frame" (lo hace el main de effie, 3rd_training.lua:375/461).
	-- Sin esto cada alloc() de dummy_control/inputs quedaba en `used` para siempre: ~50 MB cada 10 s -> "not enough memory"
	-- OJO: NO usar pool:free_all(): vacía (t[k] = nil) y recicla tablas que effie todavía referencia en nuestro orden de
	-- llamadas -> datos corruptos, memoria a 870 MB y el emulador a 40 fps. Solo se suelta la lista `used`: las tablas
	-- quedan intactas y el GC las junta cuando nadie las usa.
	if gc_tools and gc_tools.Pools then
		for _, k in ipairs({ "small", "big", "draw" }) do
			local pool = gc_tools.Pools[k]
			if pool and pool.used and #pool.used > 0 then pool.used = {} end
		end
	end
	if gc_tools and gc_tools.GC then gc_tools.GC:update() else collectgarbage("step", 120) end
end

emu.registerbefore(function()
	frame_main()
	end_of_frame()
end)

gui.register(function() overlay.draw(app) end)
emu.registerexit(function()
	output.release()
	if app.bot.brain.save_learned and app.bot.mem and app.bot.mem.parry_stats then app.bot.brain.save_learned(app.bot.mem.parry_stats) end
	log.write("CIPHER exit | %s", metrics.summary())
	log.close()
end)
