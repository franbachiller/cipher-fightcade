-- Diagnóstico online: ¿qué hooks de Lua se ejecutan en quark:served? Solo escribe contadores a un archivo.
local OUT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\logs\\probe_hooks.log"
local c = { before = 0, after = 0, gui = 0, write = 0, exec = 0 }
local function dump(tag)
	local f = io.open(OUT, "a")
	if f then
		f:write(string.format("%s %s fc=%s before=%d after=%d gui=%d write=%d\n", os.date("%H:%M:%S"), tag,
			tostring(emu.framecount and emu.framecount()), c.before, c.after, c.gui, c.write))
		f:close()
	end
end
local f0 = io.open(OUT, "w") if f0 then f0:close() end
dump("load")
emu.registerbefore(function() c.before = c.before + 1 if c.before % 120 == 1 then dump("before") end end)
emu.registerafter(function() c.after = c.after + 1 if c.after % 120 == 1 then dump("after") end end)
gui.register(function() c.gui = c.gui + 1 if c.gui % 120 == 1 then dump("gui") end end)
-- timer de partida: el juego lo escribe una vez por segundo
pcall(memory.registerwrite, 0x02011377, function() c.write = c.write + 1 if c.write % 5 == 1 then dump("write") end end)
