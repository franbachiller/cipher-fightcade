-- SA por personaje: elegirlo solo en la pantalla de SA (con teclas: online no se puede escribir RAM) y recordar
-- el que se usó en cada pelea. Tabla persistente: data\sfiii3\sa_pick.lua
local log = require("core.log")

local M = {}
local ROOT = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])games[\\/]") or ".\\"
local PATH = ROOT .. "data\\sfiii3\\sa_pick.lua"
local ROMAN = { "I", "II", "III" }

-- pantalla de selección (effie character_select.lua / tools\harness.lua). state: 2 = personaje, 4 = SA
local SEL = {
	{ row = 0x020154CF, col = 0x0201566B, sa = 0x020154D3, state = 0x0201553D },
	{ row = 0x020154D1, col = 0x0201566D, sa = 0x020154D5, state = 0x02015545 },
}
local GRID = { alex = {0,1}, sean = {0,2}, ibuki = {0,3}, necro = {0,4}, urien = {0,5}, gouki = {0,6},
	yang = {1,0}, twelve = {1,1}, makoto = {1,2}, chunli = {1,3}, q = {1,4}, remy = {1,5}, yun = {1,6},
	ken = {2,0}, hugo = {2,1}, elena = {2,2}, dudley = {2,3}, oro = {2,4}, ryu = {2,5} }
local AT = {}
for name, cr in pairs(GRID) do AT[cr[1] * 10 + cr[2]] = name end

local pick = (function()
	local ok, t = pcall(dofile, PATH)
	return (ok and type(t) == "table") and t or {}
end)()

local function save()
	local f = io.open(PATH, "w")
	if not f then return end
	f:write("-- SA de cada personaje para CIPHER: lo elige solo en la pantalla de SA y se actualiza si elegís otro a mano.\nreturn {\n")
	local names = {}
	for k in pairs(pick) do names[#names + 1] = k end
	table.sort(names)
	for _, k in ipairs(names) do f:write(string.format("  [%q] = %d,\n", k, pick[k])) end
	f:write("}\n")
	f:close()
end

-- nombres de los SA desde la move list importada (type = "sa1".."sa3")
local names_cache = {}
function M.name(char, sa)
	if not names_cache[char] then
		local ok, ml = pcall(dofile, ROOT .. "data\\sfiii3\\moves\\" .. char .. ".lua")
		local t = {}
		if ok and type(ml) == "table" then
			for _, mv in ipairs(ml) do
				local n = mv.type and mv.type:match("^sa(%d)$")
				if n then t[tonumber(n)] = mv.name end
			end
		end
		names_cache[char] = t
	end
	return string.format("SA %s %s", ROMAN[sa] or "?", names_cache[char][sa] or "")
end

function M.get(char) return pick[char] end

-- al empezar cada pelea: si el SA usado no es el guardado (elegido a mano), recordarlo
function M.learn(me)
	if os.getenv("CIPHER_FRESH") == "1" then return end      -- pruebas: no tocar la tabla del usuario
	-- YA NO se aprende: cuando el bot no llegaba a elegir (abortaba / el rival tardaba) la pelea salía con el cursor
	-- por defecto (SA I) y eso se guardaba como preferencia: Ken 3 -> 2 -> 1, Urien 3 -> 1, Alex 2 -> 1. La tabla
	-- data\sfiii3\sa_pick.lua es la autoridad (tier list, tools\tier_list.py); acá solo se avisa la diferencia.
	if not me or not GRID[me.char_str] or not me.sa or me.sa < 1 or me.sa > 3 then return end
	local want = pick[me.char_str]
	if want and want ~= me.sa then
		log.write("SA DISTINTO: %s pelea con %s, el elegido es %s", me.char_str, M.name(me.char_str, me.sa), M.name(me.char_str, want))
		return true, want
	end
end

-- en la pantalla de SA del jugador local: devuelve la máscara a mandar (o nil si no hay que tocar nada) + texto
-- bits de output: 0 up, 1 down, 4 lp
local st = { last_press = -999, on_target = 0, presses = 0, wiggle = 0, votes = { 0, 0 } }
local function cursor(p) return memory.readbyte(SEL[p].sa) end
local function on_screen(p) return memory.readbyte(SEL[p].state) == 4 end

-- lado sin confirmar: tocar abajo/arriba (inofensivo) y ver QUÉ cursor de SA se mueve. 2 votos limpios = lado.
-- (la palabra de input de pelea 0x0206AA8C no se actualiza en los menús)
local function detect_side(frame)
	-- voto válido solo si UN cursor se movió y exactamente en la dirección apretada (abajo +1, arriba -1, con vuelta).
	-- Online el rival también mueve su cursor: un voto sin dirección detectó P2 siendo P1 (se creyó Dudley).
	if st.pending then
		local c1, c2 = cursor(1), cursor(2)
		local m1, m2 = c1 ~= st.pending[1], c2 ~= st.pending[2]
		if m1 or m2 then
			local expect = function(prev) return (st.pending.down and (prev + 1) or (prev + 2)) % 3 end
			local ok1 = m1 and c1 == expect(st.pending[1])
			local ok2 = m2 and c2 == expect(st.pending[2])
			if m1 ~= m2 and (ok1 or ok2) then
				local p = ok1 and 1 or 2
				st.votes[p] = st.votes[p] + 1
			else
				st.votes = { 0, 0 }                               -- ambiguo: los dos se movieron / dirección rara
			end
			st.pending = nil
			for p = 1, 2 do
				if st.votes[p] >= 3 and st.votes[3 - p] == 0 then
					M.detected = p
					log.write("lado detectado en la pantalla de SA: P%d (provisional)", p)
				end
			end
		end
	end
	local since = frame - st.last_press
	if since < 3 then return st.mask end
	if since < 16 then return 0 end
	if st.wiggle >= 16 then return nil end                      -- no se pudo: que elija el jugador
	st.wiggle = st.wiggle + 1
	st.mask = (st.wiggle % 2 == 1) and 2 or 1
	st.pending = { cursor(1), cursor(2), down = st.mask == 2 }
	st.last_press = frame
	return st.mask
end

-- side_known: el lado ya está confirmado (detector de cipher.lua o detect_side). Recién ahí se navega y confirma.
function M.tick(frame, side, side_known)
	if not on_screen(1) and not on_screen(2) then
		st.presses, st.on_target, st.char, st.wiggle, st.pending, st.votes = 0, 0, nil, 0, nil, { 0, 0 }
		st.verify, st.abort, st.vfail, st.verified, st.screen_at = nil, nil, 0, false, nil
		return nil
	end
	-- frame en que MI pantalla de SA apareció: el juego ignora los inputs durante la animación de entrada (la primera
	-- tecla se perdía -> "el cursor no respondió" -> abortaba y la pelea salía con SA I)
	if side_known and on_screen(side) and not st.screen_at then st.screen_at = frame end
	local settled = st.screen_at and frame - st.screen_at >= 30
	-- No tocar teclas mientras alguno esté en la selección de personaje (con el lado mal movían el cursor de PERSONAJE
	-- del jugador). Excepción: el rival tarda y yo ya llevo 3 s en mi pantalla de SA con el lado confirmado en pelea
	-- (si no, el timer elegía SA I solo); la primera tecla verifica que se mueva MI cursor.
	local waiting_rival = false
	for p = 1, 2 do if memory.readbyte(SEL[p].state) < 4 then waiting_rival = true end end
	if waiting_rival and not (side_known and on_screen(side) and st.screen_at and frame - st.screen_at >= 180) then return nil end
	if st.abort then return nil end
	if not side_known then return detect_side(frame) end
	local sel = SEL[side]
	if not on_screen(side) or not settled then return nil end
	-- la primera tecla tiene que mover ESTE cursor; si no: reintentar 2 veces (puede haberse perdido) y recién ahí
	-- abortar (lado dudoso)
	if st.verify and frame - st.last_press >= 16 then
		if memory.readbyte(sel.sa) == st.verify then
			st.vfail = (st.vfail or 0) + 1
			log.write("sa-diag sin respuesta #%d: P%d cursor=%d (antes %d) mask=%s estados P1=%d P2=%d cursores P1=%d P2=%d",
				st.vfail, side, memory.readbyte(sel.sa), st.verify, tostring(st.mask), memory.readbyte(SEL[1].state),
				memory.readbyte(SEL[2].state), cursor(1), cursor(2))
			if st.vfail >= 3 then
				st.abort = true
				log.write("pantalla de SA: el cursor P%d no respondió 3 veces, lado dudoso -> elegís vos", side)
				return nil
			end
			st.verify, st.presses = nil, 0                       -- reintentar
		else
			st.verify, st.verified = nil, true
		end
	end
	local char = AT[memory.readbyte(sel.col) * 10 + memory.readbyte(sel.row)]
	local want = char and pick[char]
	if not want then return nil end
	if st.char ~= char then
		st.char = char
		log.write("pantalla de SA: %s -> elijo %s", char, M.name(char, want))
	end
	local cur = memory.readbyte(sel.sa) + 1
	local since = frame - st.last_press
	if since < 3 then return st.mask end                        -- sostener la pulsación 3 frames
	if since < 16 then return 0 end                             -- soltar y esperar al cursor (delay online)
	if st.presses > 8 then return nil end                       -- no responde (otro lado / ya confirmado): no insistir
	if st.verify then return 0 end                              -- esperando ver si el cursor se movió
	if not st.verified and cur == want then
		-- ya está en el SA buscado pero el lado no se verificó: mover y volver (si el lado estuviera mal, LP
		-- confirmaría el SA que tenga el cursor del jugador sin que nadie lo note)
		st.mask = 2
		st.verify = memory.readbyte(sel.sa)
		st.last_press, st.presses = frame, st.presses + 1
		return st.mask, char, want
	end
	if cur ~= want then
		st.on_target = 0
		st.mask = (want > cur) and 2 or 1
	else
		st.on_target = st.on_target + 1
		if st.on_target < 2 then return 0 end
		st.mask = 16                                            -- LP confirma
	end
	if not st.verified and st.mask ~= 16 then st.verify = memory.readbyte(sel.sa) end
	st.last_press, st.presses = frame, st.presses + 1
	return st.mask, char, want
end

return M
