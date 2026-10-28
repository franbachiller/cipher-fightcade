-- Instancia observadora para el test de netplay: no inyecta nada, solo loguea estado.
local ROOT = (os.getenv("CIPHER_ROOT") or ".") .. "\\"
os.execute('mkdir "' .. ROOT .. 'logs" 2>nul')
local f = io.open(ROOT .. "logs\\" .. (os.getenv("CIPHER_LOGNAME") or "observer") .. ".log", "w")
local P = { 0x02068C6C, 0x02069104 }
local rb, rws = memory.readbyte, memory.readwordsigned
f:write(string.format("observer start online=%s\n", tostring(emu.isonline and emu.isonline()))) f:flush()
-- Hasta la pelea mashea (necesario para pasar char select); en pelea no inyecta NADA.
emu.registerbefore(function()
	if os.getenv("CIPHER_OBS_MASH") ~= "1" then return end   -- default: no inyecta nada (evita desync)
	if memory.readword(0x020154A6) == 0x0002 then return end
	local ph = emu.framecount() % 24
	local t = {}
	if ph < 2 then t["P1 Weak Punch"] = true t["P2 Weak Punch"] = true
	elseif ph >= 8 and ph < 10 then t["P1 Coin"] = true t["P2 Coin"] = true
	elseif ph >= 16 and ph < 18 then t["P1 Start"] = true t["P2 Start"] = true end
	joypad.set(t)
end)
emu.registerafter(function()
	local fc = emu.framecount()
	if fc % 60 == 0 then
		local pr = {}
		for k, v in pairs(joypad.get()) do if v == true and k:sub(1, 3) == "P2 " then pr[#pr + 1] = k:sub(4) end end
		table.sort(pr)
		f:write("    P2 pressed: " .. table.concat(pr, ",") .. "\n")
		f:write(string.format("[%07d] match=%08X timer=%d | P1 c=%d hp=%d x=%d | P2 c=%d hp=%d x=%d\n", fc,
			memory.readdword(0x020154A6), rb(0x02011377),
			memory.readword(P[1] + 0x3C0), rb(P[1] + 0x9F), rws(P[1] + 0x64),
			memory.readword(P[2] + 0x3C0), rb(P[2] + 0x9F), rws(P[2] + 0x64)))
		f:flush()
	end
end)
