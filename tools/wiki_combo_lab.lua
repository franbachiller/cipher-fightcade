-- Verificador de combos de la wiki (data/sfiii3/wiki_combos.lua, notación canónica curada a mano desde las páginas
-- de SuperCombo). P2 = personaje, P1 = muñeco parado. Para cada combo busca paso a paso el frame de cada
-- chain (>) / cancel (xx) / link (,): un paso vale solo si suma golpes al contador SIN que el combo se corte.
-- De la ventana que funciona se queda con el centro del tramo contiguo más largo (margen para el online).
-- Nada entra al bot sin pasar por acá.
-- Env: CIPHER_ROOT, CIPHER_WCL_CHAR, CIPHER_WCL_SA, CIPHER_WCL_DUMMY (ryu), CIPHER_WCL_CROUCH (1 = muñeco agachado)
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
package.path = ROOT .. "?.lua;" .. package.path
input_lib = require("core.input")
local H = dofile(ROOT .. "tools\\harness.lua")
local S = require("games.sfiii3.state")

local CHAR = os.getenv("CIPHER_WCL_CHAR") or "ken"
local SA = tonumber(os.getenv("CIPHER_WCL_SA") or "3")
local DUMMY = os.getenv("CIPHER_WCL_DUMMY") or "ryu"
local CROUCH = os.getenv("CIPHER_WCL_CROUCH") == "1"
local BASE = os.getenv("CIPHER_WCL_BASE") == "1"         -- esta corrida también prueba los combos sin super
local TAG = string.format("%s_sa%d_%s%s", CHAR, SA, DUMMY, CROUCH and "_cr" or "")
-- corrida partida en varias instancias (tools\combo_lab_char.ps1): cada parte escribe su archivo y después se juntan
local PART = os.getenv("CIPHER_WCL_PART") or ""
-- corrida de un solo set (p. ej. "auto"): resultados en su propio archivo para no pisar los del resto
local SETTAG = os.getenv("CIPHER_WCL_SET") or ""
if SETTAG ~= "" then TAG = TAG .. "_" .. SETTAG end
if PART ~= "" then TAG = TAG .. "_p" .. PART end
os.execute('mkdir "' .. ROOT .. 'data\\sfiii3\\combos\\wiki" 2>nul')
local OUT = ROOT .. "data\\sfiii3\\combos\\wiki\\" .. TAG .. ".lua"
local logf = io.open(ROOT .. "logs\\wiki_combo_lab_" .. TAG .. ".log", "w")
local function L(...) logf:write(string.format(...) .. "\n") logf:flush() end

local rb, wb, rws = memory.readbyte, memory.writebyte, memory.readwordsigned
local P1B, P2B = S.P[1].base, S.P[2].base
local P2_COMBO = 0x0206961D
local P2_STOCK, P2_MAXCOUNT = 0x020695EB, 0x020695E9
local NAMES = { lp = "Weak Punch", mp = "Medium Punch", hp = "Strong Punch", lk = "Weak Kick", mk = "Medium Kick", hk = "Strong Kick" }
local NEUTRAL = { standing = true, crouching = true, standing_begin = true, crouching_begin = true,
	standing_turn = true, crouching_turn = true, walk_forward = true, walk_back = true, walk_transition = true }

-- ---------------------------------------------------------------- catálogo y parser
local MOVES = dofile(ROOT .. "data\\sfiii3\\moves\\" .. CHAR .. ".lua")
local ALL = {}
-- combos de la wiki + candidatos con super para los 3 SA (tools/gen_super_candidates.py)
-- CIPHER_WCL_SET = "wiki" | "super" | "" (todos)
local SET = os.getenv("CIPHER_WCL_SET") or ""
for _, f in ipairs({ "wiki_combos.lua", "super_combos.lua", "wiki_combos_auto.lua" }) do   -- auto: tools/extract_wiki_routes.py
	if SET == "" or f:find(SET, 1, true) then
		local ok, t = pcall(dofile, ROOT .. "data\\sfiii3\\" .. f)
		for _, e in ipairs(ok and t[CHAR] or {}) do ALL[#ALL + 1] = e end
	end
end

local WC = require("games.sfiii3.wiki_combo")
local function parse(text) return WC.parse(text, MOVES, SA) end
local window = WC.window
local PRE = 0
local function build(combo, upto, ts) return WC.build(combo.steps, upto, ts) end

-- ---------------------------------------------------------------- estado
local state, fwd_key, SAVE, SNAP
local ci, combo, step, ts, cand, ci_t, best
local trial
local results = {}
local stats = { trials = 0, frames = 0, t0 = os.clock() }

local function to_joy(fr)
	local j = {}
	if CROUCH then j["P1 Down"] = true end
	if not fr then return j end
	if fr.up then j["P2 Up"] = true end
	if fr.down then j["P2 Down"] = true end
	if fr.fwd then j[fwd_key] = true end
	if fr.back then j[fwd_key == "P2 Left" and "P2 Right" or "P2 Left"] = true end
	for b, n in pairs(NAMES) do if fr[b] then j["P2 " .. n] = true end end
	return j
end

local function save_results()
	local f = io.open(OUT, "w")
	f:write("-- generado por tools/wiki_combo_lab.lua (" .. TAG .. "): combos de la wiki verificados en emulador\nreturn {\n")
	for _, r in ipairs(results) do
		f:write(string.format("  { text = %q, ok = %s, d = %d, sa = %d, dmg = %d, hits = %d, done = %d, t = {%s}, win = {%s}, pre = %d },\n",
			r.text, tostring(r.ok), r.d, SA, r.dmg, r.hits, r.done, table.concat(r.t, ","), table.concat(r.win, ","), r.pre))
	end
	f:write("}\n")
	f:close()
end

local function begin_trial()
	savestate.load(SAVE)
	wb(P2_STOCK, rb(P2_MAXCOUNT))
	local tt = {}
	for i = 1, step - 1 do tt[i] = ts[i] end
	tt[step] = cand[ci_t]
	local last = tt[step]
	trial = { frame = 0, plan = build(combo, step, tt), last = last, peak = 0, broke = false, hpmin = 999, reloads = 0,
		cap = last + (combo.steps[step].super and 260 or 120) }
	stats.trials = stats.trials + 1
	joypad.set({})
end

-- centro del tramo contiguo más largo
local function center(list)
	table.sort(list)
	local ba, bb, a = list[1], list[1], list[1]
	for i = 2, #list + 1 do
		if i > #list or list[i] ~= list[i - 1] + 1 then
			if list[i - 1] - a > bb - ba then ba, bb = a, list[i - 1] end
			a = list[i]
		end
	end
	return math.floor((ba + bb) / 2), ba, bb
end

local next_combo

local function finish_combo(ok)
	local r = { text = combo.text, ok = ok, d = combo.d, dmg = combo.dmg or 0, hits = combo.peak or 0,
		done = ok and #combo.steps or (step - 1), t = {}, win = {}, pre = PRE }
	for i = 1, (ok and #combo.steps or step - 1) do
		r.t[i] = ts[i]
		r.win[#r.win + 1] = string.format("%d", combo.win[i] or 0)
	end
	results[#results + 1] = r
	save_results()
	L("%s %-55s hits=%d dmg=%d t=[%s]%s", ok and "OK  " or "FAIL", combo.text, r.hits, r.dmg, table.concat(r.t, ","),
		ok and "" or ("  (corta en " .. tostring(combo.steps[step] and combo.steps[step].tok) .. ")"))
	next_combo()
end

local function start_step()
	local st = combo.steps[step]
	if step == 1 then
		cand = { PRE }
	else
		local lo, hi = window(st, combo.steps[step - 1])
		cand = {}
		for x = ts[step - 1] + lo, ts[step - 1] + hi do cand[#cand + 1] = x end
		if st.charge and combo.steps[1] == st then end
	end
	ci_t, best = 1, { ok = {}, peak = combo.peak or 0 }
	begin_trial()
end

next_combo = function()
	while true do
		ci = ci + 1
		local e = ALL[ci]
		if not e then
			L("FIN %d combos, %d ensayos, %d frames, %.0fs", #results, stats.trials, stats.frames, os.clock() - stats.t0)
			logf:close()
			os.exit(0)
		end
		local want = e.sa
		local only = os.getenv("CIPHER_WCL_ONLY")
		local picked = not only or only == "" or ("," .. only .. ","):find("," .. ci .. ",", 1, true)
		if picked and ((not want and BASE) or want == SA) then
			local steps, bad = parse(e[1])
			if steps then
				combo = { text = e[1], steps = steps, d = e.d or ((e[1]:match("^cl%.") or e[1]:match("^UOH")) and 42 or
					e[1]:match("^far") and 95 or 60), win = {}, peak = 0 }
				PRE = WC.pre(steps)
				ts, step = {}, 1
				state = "place"
				trial = { frame = 0 }
				return
			else
				L("SKIP %-55s token no reconocido: %s", e[1], tostring(bad))
			end
		end
	end
end

H.to_match({ p1 = DUMMY, p2 = CHAR, sa1 = 1, sa2 = SA }, function()
	if emu.speedmode then
		if not pcall(emu.speedmode, "maximum") then pcall(emu.speedmode, "turbo") end
	end
	L("char=%s sa=%d dummy=%s%s combos=%d", CHAR, SA, DUMMY, CROUCH and " (agachado)" or "", #ALL)
	ci = 0
	next_combo()
	emu.registerbefore(function()
		wb(0x02011377, 99)
		local s = S.read()
		if state == "place" then
			-- P2 a distancia exacta del muñeco (X por RAM), los dos quietos
			trial.frame = trial.frame + 1
			local me, op = s.p[2], s.p[1]
			-- los dos al centro del escenario (contra la pared la X se recorta y la distancia queda mal)
			local side = (me.x >= op.x) and 1 or -1
			local CX = 512
			-- vida llena en cada ubicación: si no, el muñeco se queda sin vida a lo largo de la corrida (daño recortado,
			-- fin de round a mitad de combo = falsos FAIL)
			HP_FULL = HP_FULL or { rb(P1B + 0x9F), rb(P2B + 0x9F) }
			wb(P1B + 0x9F, HP_FULL[1]) wb(P2B + 0x9F, HP_FULL[2])
			if trial.frame <= 30 then
				memory.writeword(P1B + 0x64, math.floor(CX - side * combo.d / 2))
				memory.writeword(P2B + 0x64, math.floor(CX + side * combo.d / 2))
			end
			fwd_key = (op.x < me.x) and "P2 Left" or "P2 Right"
			-- limpiar el buffer de motion: el savestate guarda el historial de inputs y el 236236 del combo anterior
			-- convertía el primer botón del siguiente en super (Oro: "cl.HP" salía como Kishinriki)
			local j = CROUCH and { ["P1 Down"] = true } or {}
			if trial.frame <= 25 then j[fwd_key == "P2 Left" and "P2 Right" or "P2 Left"] = true end
			joypad.set(j)
			-- objetivo menor que el contacto de las cajas de empuje (~50 px): vale el contacto
			if trial.frame >= 50 and math.abs(s.dist - combo.d) > 4 and not (combo.d < 58 and s.dist < 58) then
				trial.frame = 0
				trial.tries = (trial.tries or 0) + 1
				if trial.tries > 6 then L("ERROR ubicación d=%s (quería %d)", tostring(s.dist), combo.d) finish_combo(false) end
				return
			end
			if trial.frame >= 50 and me.move and NEUTRAL[me.move] and op.move and NEUTRAL[op.move] then
				-- slot propio por emulador (archivo compartido); "anon" = savestate anónimo (más de 9 instancias)
				local slot = os.getenv("CIPHER_WCL_SLOT") or "9"
				SAVE = (slot == "anon") and savestate.create() or savestate.create(tonumber(slot))
				savestate.save(SAVE)
				SNAP = { hp = rb(P1B + 0x9F), x1 = rws(P1B + 0x64), x2 = rws(P2B + 0x64) }
				state = "run"
				start_step()
			end
			return
		end
		if state ~= "run" then return end

		trial.frame = trial.frame + 1
		stats.frames = stats.frames + 1
		if trial.frame == 1 then
			local bad = rb(P2_COMBO) ~= 0 or rb(P1B + 0x9F) ~= SNAP.hp
				or math.abs(rws(P1B + 0x64) - SNAP.x1) > 2 or math.abs(rws(P2B + 0x64) - SNAP.x2) > 2
			if bad then
				trial.reloads = trial.reloads + 1
				if trial.reloads > 200 then L("ERROR carga inválida en %s", combo.text) finish_combo(false) return end
				savestate.load(SAVE)
				wb(P2_STOCK, rb(P2_MAXCOUNT))
				trial.frame = 0
				joypad.set({})
				return
			end
		end
		local fr = trial.frame - 1
		joypad.set(to_joy(trial.plan[fr]))
		local c = rb(P2_COMBO)
		if trial.peak >= 1 and c == 0 and not trial.dropped then trial.dropped, trial.drop_fr = true, fr end
		if trial.dropped and c > 0 then trial.broke = true end
		if c > trial.peak then trial.peak = c end
		local hp = rb(P1B + 0x9F)
		if hp < trial.hpmin and hp ~= 255 then trial.hpmin = hp end
		local dmg_now = SNAP.hp - (trial.hpmin == 999 and SNAP.hp or trial.hpmin)
		-- tras cortarse el contador se sigue mirando 45f: el daño de un agarre (Shootdown, Megaton, Niouriki) llega después
		local done = trial.broke or fr >= trial.cap
			or (trial.dropped and fr > trial.last + 3 and fr - trial.drop_fr > 45)
			or (fr > trial.last + 110 and dmg_now <= (combo.dmg or 0) + 1)
		if not done then return end

		-- resultado del ensayo
		if step == 1 then
			local sr = S.read()
			L("  paso1 %s peak=%d broke=%s fr=%d d=%s p2=%s p1=%s", combo.steps[1].tok, trial.peak, tostring(trial.broke), fr,
				tostring(sr.dist), tostring(sr.p[2].move), tostring(sr.p[1].move))
		end
		-- el paso vale si SUMA DAÑO al prefijo solo y el combo no se cortó. Antes se exigían más golpes: un cancel en el
		-- 1er golpe de un normal de 2 (cl.MP(1) xx Hitobashira de Oro) deja el contador igual, y los agarres en combo
		-- (Shootdown / Megaton de Hugo) suman daño pero no golpes
		if not trial.broke and dmg_now > (combo.dmg or 0) + 1 then
			best.ok[#best.ok + 1] = cand[ci_t]
			best.res = best.res or {}
			best.res[cand[ci_t]] = { peak = trial.peak, dmg = dmg_now }
		end
		ci_t = ci_t + 1
		if ci_t <= #cand then begin_trial() return end
		-- fin del paso: elegir el t (máximo daño, tolerancia 2; centro de su ventana)
		if #best.ok == 0 then finish_combo(false) return end
		local top = 0
		for _, t in ipairs(best.ok) do top = math.max(top, best.res[t].dmg) end
		local good = {}
		for _, t in ipairs(best.ok) do if best.res[t].dmg >= top - 2 then good[#good + 1] = t end end
		local t, a, b = center(good)
		ts[step] = t
		combo.win[step] = b - a + 1
		combo.peak = best.res[t].peak
		combo.dmg = best.res[t].dmg
		if step == #combo.steps then finish_combo(true) return end
		step = step + 1
		start_step()
	end)
end)
