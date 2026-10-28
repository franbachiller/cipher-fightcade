-- Sonda UMK3: secuencia de menú programada por env (CIPHER_UMK3_SEQ = "frame:tecla,tecla;frame:..."), loguea las
-- direcciones conocidas del fbneo-training-mode (vida, dirección) para confirmar el mapeo de memoria.
-- Log: logs\umk3_probe.log
local ROOT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\"
local f = io.open(ROOT .. "logs\\umk3_probe.log", "w")
local function L(...) f:write(string.format(...) .. "\n") f:flush() end
local rb = memory.readbyte
local A = { p1hp = 0x01060a60, p2hp = 0x01061610, p1dir = 0x01030541, p2dir = 0x0105fa01 }
-- secuencia: frame -> teclas (cada una se sostiene 4 frames)
local SEQ = {}
for fr, keys in (os.getenv("CIPHER_UMK3_SEQ") or "240:P1 Coin;420:P1 Start;600:P1 High Punch;780:P1 High Punch"):gmatch("(%d+):([^;]+)") do
	SEQ[#SEQ + 1] = { fr = tonumber(fr), keys = keys }
end
L("arranca umk3 probe, %d pasos", #SEQ)
local start = emu.framecount()
-- el driver expone los DIP switches como "teclas" (Dip A / Dip B): joypad.set sin ellos los pone en 0 y la placa
-- arranca en MODO TEST. Hay que leer sus valores originales y mandarlos siempre.
local DIPS
emu.registerbefore(function()
	local fc = emu.framecount() - start
	if not DIPS then
		local j = joypad.get()
		DIPS = { ["Dip A"] = j["Dip A"], ["Dip B"] = j["Dip B"] }
		L("DIPs originales: A=%s B=%s", tostring(DIPS["Dip A"]), tostring(DIPS["Dip B"]))
	end
	local t = { ["Dip A"] = DIPS["Dip A"], ["Dip B"] = DIPS["Dip B"] }
	for _, st in ipairs(SEQ) do
		if fc >= st.fr and fc < st.fr + 4 then
			for k in st.keys:gmatch("[^,]+") do t[k] = true end
		end
	end
	-- fase de volcado de RAM (CIPHER_UMK3_DUMP=1): ya en pelea (las dos vidas > 0), guion de P1 y copia de la RAM
	-- 0x01000000-0x0107FFFF cada 6 frames a logs\umk3_dump.bin (cabecera: frame, fase) para correlacionar offline
	if os.getenv("CIPHER_UMK3_DUMP") == "1" then
		if not FIGHT_AT and rb(A.p1hp) > 0 and rb(A.p2hp) > 0 and fc > 1500 then FIGHT_AT = fc + 200 end
		if FIGHT_AT and fc >= FIGHT_AT then
			local k = fc - FIGHT_AT
			local PLAN = os.getenv("CIPHER_UMK3_PLAN") == "attack"
				and { { 60, "idle" }, { 90, "lp" }, { 90, "hp" }, { 90, "block" }, { 90, "sweep" }, { 90, "lk" } }
				or { { 90, "idle" }, { 90, "right" }, { 90, "left" }, { 60, "idle" }, { 60, "up" }, { 60, "idle" },
				{ 60, "down" }, { 60, "idle" }, { 60, "right" } }
			local acc, phase = 0, nil
			for i, p in ipairs(PLAN) do
				if k < acc + p[1] then phase = i break end
				acc = acc + p[1]
			end
			if phase then
				local act = PLAN[phase][2]
				if act == "right" then t["P1 Right"] = true elseif act == "left" then t["P1 Left"] = true
				elseif act == "up" then if k % 30 < 3 then t["P1 Up"] = true end
				elseif act == "down" then t["P1 Down"] = true
				-- ataques: un toque cada 45 frames (acercarse antes: en la fase idle camina)
				elseif act == "lp" then if k % 45 < 3 then t["P1 Low Punch"] = true end
				elseif act == "hp" then if k % 45 < 3 then t["P1 High Punch"] = true end
				elseif act == "lk" then if k % 45 < 3 then t["P1 Low Kick"] = true end
				elseif act == "block" then t["P1 Block"] = true
				elseif act == "sweep" then t["P1 Down"] = true if k % 45 < 3 then t["P1 High Kick"] = true end end
				if act == "idle" and os.getenv("CIPHER_UMK3_PLAN") == "attack" then t["P1 Right"] = true end
				if k % 6 == 0 then
					DUMP = DUMP or io.open(ROOT .. "logs\\umk3_dump.bin", "wb")
					local bytes = memory.readbyterange(0x01000000, 0x80000)
					local parts = {}
					for i = 1, #bytes, 4096 do parts[#parts + 1] = string.char(unpack(bytes, i, math.min(#bytes, i + 4095))) end
					DUMP:write(string.format("%08d%02d", k, phase))
					DUMP:write(table.concat(parts))
				end
			elseif DUMP then DUMP:close() DUMP = nil L("volcado terminado") end
		end
	end
	joypad.set(t)
	if fc % 60 == 0 then
		L("fc=%d p1hp=%d p2hp=%d p1dir=%02x p2dir=%02x", fc, rb(A.p1hp), rb(A.p2hp), rb(A.p1dir), rb(A.p2dir))
	end
end)
