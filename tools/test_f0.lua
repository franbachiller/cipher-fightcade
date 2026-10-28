-- Test F0: llega a una pelea (turbo, mash ambos lados) y carga cipher.lua con el bot ON.
-- Lanzar con CIPHER_AUTOSTART=1 y CIPHER_SIDE=1|2 (tools\run_test.ps1).
local ROOT = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])") or ".\\"
local CIPHER = (os.getenv("CIPHER_LUA") or (ROOT .. "..\\cipher.lua"))
local rb = memory.readbyte
if emu.speedmode then emu.speedmode("turbo") end

local start, loaded = emu.framecount(), false
emu.registerbefore(function()
	if loaded then return end
	if memory.readword(0x020154A6) == 0x0002 then
		loaded = true
		if emu.speedmode then emu.speedmode("normal") end
		dofile(CIPHER)
		return
	end
	local ph = (emu.framecount() - start) % 24
	local t = {}
	if ph < 2 then t["P1 Weak Punch"] = true t["P2 Weak Punch"] = true
	elseif ph >= 8 and ph < 10 then t["P1 Coin"] = true t["P2 Coin"] = true
	elseif ph >= 16 and ph < 18 then t["P1 Start"] = true t["P2 Start"] = true end
	joypad.set(t)
end)
