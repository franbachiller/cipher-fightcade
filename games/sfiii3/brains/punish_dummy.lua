-- Muñeco del lab de castigos (solo offline, CIPHER_SPAR=punish_dummy): se pone a una distancia y hace un golpe
-- inseguro conocido, en ciclo. Por cada intento loguea "dummy-res <escenario> d=<dist> dmg=<daño recibido en 150f>"
-- para medir si el bot (P1) lo castiga y con cuánto. tools\punish_lab.ps1 + tools\punish_report.py
local M = input_lib.motion
local log = require("core.log")
local S = require("games.sfiii3.state")
local B = {}

-- { nombre, distancia objetivo, secuencia } (inputs de shoto: el muñeco por defecto es Ryu)
local SCEN = {
	{ "shoryuken_whiff", 70,  function() return M.dp("hp") end },
	{ "sweep_blocked",   85,  function() return M.press("hk", { down = true }, 2) end },
	{ "sweep_whiff",     180, function() return M.press("hk", { down = true }, 2) end },
	{ "crMK_whiff",      150, function() return M.press("mk", { down = true }, 2) end },
	{ "stHK_whiff",      165, function() return M.press("hk", nil, 2) end },
	{ "stHP_blocked",    75,  function() return M.press("hp", nil, 2) end },
	{ "tatsu_blocked",   80,  function() return M.qcb("hk") end },
	{ "hadou_close",     90,  function() return M.qcf("hp") end },
}

function B.reset(ctx) ctx.mem = { label = "dummy", i = 0, phase = "place", t = 0 } end

local NEUTRAL = { [0x00] = true, [0x02] = true, [0x06] = true, [0x08] = true, [0x20] = true, [0x21] = true }

function B.think(ctx, s, me, op)
	local mem = ctx.mem
	local d = s.dist
	-- daño recibido frame a frame (la recarga de vida no lo pisa) y vida/reloj llenos SIEMPRE: si la pelea termina el
	-- juego pasa a rivales de arcade y el lab se contamina
	local hp = (me.hp == 255) and 0 or me.hp
	if mem.prev_hp and hp < mem.prev_hp then mem.dmg = (mem.dmg or 0) + (mem.prev_hp - hp) end
	for i = 1, 2 do
		local h = memory.readbyte(S.P[i].base + 0x9F)
		if h < 80 or h == 255 then memory.writebyte(S.P[i].base + 0x9F, 160) end
	end
	memory.writebyte(0x02011377, 99)
	mem.prev_hp = memory.readbyte(S.P[ctx.side or 2].base + 0x9F)
	if mem.phase == "watch" then
		if s.frame - mem.t >= 100 then         -- (150 -> 100: el castigo pega en <60 f; acelera el lab)
			log.write("dummy-res %s d=%d dmg=%d", mem.sc_done[1], mem.d0, mem.dmg or 0)
			-- termina solo cuando cada escenario tiene N muestras (antes: tiempo fijo de 150 s aunque sobraran datos)
			mem.n = (mem.n or 0) + 1
			if mem.n >= #SCEN * (tonumber(os.getenv("CIPHER_PL_N") or "") or 6) then log.write("dummy-fin %d", mem.n) os.exit(0) end
			mem.phase, mem.t = "place", s.frame
		end
		return nil
	end
	if ctx.queue:busy() then return nil end
	if not NEUTRAL[me.posture] or me.attacking or me.freeze > 0 or op.knocked_down then return {} end
	if mem.phase == "place" then
		if not mem.sc then
			mem.i = mem.i % #SCEN + 1
			mem.sc = SCEN[mem.i]
		end
		local want = mem.sc[2]
		-- los dos quietos en neutral: teletransporte al centro a la distancia del escenario (si no, el bot lo arrincona
		-- y el muñeco nunca toma distancia). El muñeco actúa unos frames después, cuando las posiciones asentaron
		-- sin esperar a que el bot esté quieto (lo ataca todo el tiempo: ~18 s de juego por intento): solo que no esté en
		-- el aire / tirado; el teletransporte lo pone en su lugar igual
		if op.airborne or op.knocked_down then mem.placed = nil return {} end
		if not mem.placed then
			local sg = (op.x < me.x) and 1 or -1        -- el muñeco a la derecha del bot si ya lo estaba
			memory.writeword(S.P[3 - (ctx.side or 2)].base + 0x64, math.floor(512 - sg * want / 2))
			memory.writeword(S.P[ctx.side or 2].base + 0x64, math.floor(512 + sg * want / 2))
			mem.placed = s.frame
			return {}
		end
		if s.frame - mem.placed < 4 then return {} end
		mem.placed = nil
		if math.abs(d - want) > 12 then return {} end
		mem.dmg = 0
		mem.d0 = d
		ctx.queue:push(mem.sc[3]())
		mem.label = mem.sc[1]
		mem.phase, mem.t = "watch", s.frame
		local sc = mem.sc
		mem.sc = nil
		mem.sc_done = sc
		return nil
	end
	return {}
end

function B.label(ctx) return ctx.mem.label end

return B
