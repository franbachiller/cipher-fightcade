-- Lab de inputs: ejecuta cada entrada de la tabla del personaje (chars/<char>.lua + auto) contra un rival quieto a
-- distancia fija y loguea QUÉ animación sale y si conecta. Verifica que cada secuencia hace lo que dice su nombre.
-- Env: CIPHER_P1 (personaje), CIPHER_P2 (rival, def. ryu), CIPHER_METER=1 (barra llena para supers/EX)
local ROOT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\"
package.path = ROOT .. "?.lua;" .. package.path
input_lib = require("core.input")
local H = dofile(ROOT .. "tools\\harness.lua")
local CHAR = os.getenv("CIPHER_P1") or "chunli"
local fh = io.open(ROOT .. "logs\\test_inputs_" .. CHAR .. ".log", "w")
local function L(fmt, ...) fh:write(string.format(fmt .. "\n", ...)) fh:flush() end
local P2X = 0x02069104 + 0x64

local function table_for(name)
	local auto = require("games.sfiii3.chars.auto")(name)
	local ok, t = pcall(require, "games.sfiii3.chars." .. name)
	if not ok or type(t) ~= "table" then return auto end
	for k, v in pairs(auto) do if t[k] == nil then t[k] = v end end
	return t
end

local ch = table_for(CHAR)
local tests = {}
-- movimientos de carga: el brain solo los dispara con la carga lista; el lab la precarga (50f atrás / abajo)
local function precharge(e)
	if not e.charge then return e.seq end
	local hold = e.charge == "v" and { down = true, hold = 50 } or { back = true, down = true, hold = 50 }
	return function() local s = { hold } for _, f in ipairs(e.seq()) do s[#s + 1] = f end return s end
end
local function add(kind, e, dist) if e and e.seq then tests[#tests + 1] = { name = kind .. " " .. (e.name or "?"), seq = precharge(e), d = dist } end end
for _, p in ipairs(ch.pokes or {}) do add("poke", p, math.max(40, (p.range and p.range[2] or 100) - 20)) end
for _, a in ipairs(ch.antiair or {}) do add("aa", a, 80) end
add("aa_special", ch.antiair_special, 80)
add("meaty", ch.meaty, 60)
add("fireball", ch.fireball, 200)
add("command_grab", ch.command_grab, 60)
add("overhead", ch.overhead, 70)
for _, c in ipairs(ch.confirm or {}) do add("confirm", c, 90) end
for _, p in ipairs(ch.punish or {}) do add("punish", p, 60) end
if ch.throw then tests[#tests + 1] = { name = "throw (kara=" .. tostring(ch.kara or 0) .. ")", seq = ch.throw, d = 70 + (ch.kara or 0) } end
for name, sp in pairs(ch.specials or {}) do add("special", sp, sp.d or 90) end

H.to_match({ p1 = CHAR, p2 = os.getenv("CIPHER_P2") or "ryu", sa1 = tonumber(os.getenv("CIPHER_SA") or "1"), sa2 = 1 }, function()
	local S = require("games.sfiii3.state")
	local ti, phase, t0, q, res = 1, "place", 0, nil, nil
	emu.registerbefore(function()
		local s = S.read()
		local t = {}
		if not s.in_match then joypad.set(t) return end
		local me, op = s.p[1], s.p[2]
		if ti > #tests then L("FIN %d pruebas", #tests) ti = 1 end
		local tc = tests[ti]
		if os.getenv("CIPHER_METER") == "1" then memory.writebyte(0x020695BF, 3) memory.writebyte(0x020695B5, 0x80) end
		if phase == "place" then
			memory.writeword(P2X, me.x + tc.d)
			-- 10 frames seguidos en animación neutral: el final de un especial (hien_LK_ext) tiene postura 0 y no ataca,
			-- pero todavía no puede actuar (el salto del Kunai se perdía)
			local neutral = me.move == "standing" or me.move == "crouching" or me.move == "standing_begin"
			still_n = neutral and (still_n or 0) + 1 or 0
			if s.frame - t0 > 25 and still_n >= 10 and me.posture == 0 and not me.attacking and not op.knocked_down and op.hp > 0 then
				q = input_lib.new()
				q:push(tc.seq())
				phase, res = "go", { hp = op.hp, moves = {}, d = s.dist }
			end
		end
		if phase == "go" or phase == "watch" then
			if q and q:busy() then
				t = input_lib.resolve(1, q:pop(), me.facing_right)
			elseif phase == "go" then
				phase, t0 = "watch", s.frame
			end
			if me.move and res.moves[#res.moves] ~= me.move then res.moves[#res.moves + 1] = me.move end
			if op.being_thrown then res.thrown = true end
			if op.hp < res.hp then res.hit = true end
			if phase == "watch" and s.frame - t0 > 45 then
				L("%-34s d=%-4d -> %-60s %s", tc.name, res.d, table.concat(res.moves, ">"),
					(res.thrown and "AGARRA") or (res.hit and "PEGA") or "")
				ti, phase, t0 = ti + 1, "place", s.frame
			end
		end
		joypad.set(t)
	end)
end)
