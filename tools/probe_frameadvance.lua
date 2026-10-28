-- Diagnóstico online: ¿funciona un bucle principal con emu.frameadvance() en quark:served?
local OUT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\logs\\probe_fa.log"
local f0 = io.open(OUT, "w") if f0 then f0:write(os.date("%H:%M:%S") .. " load fc=" .. tostring(emu.framecount()) .. "\n") f0:close() end
local n = 0
while true do
	n = n + 1
	if n % 120 == 1 then
		local f = io.open(OUT, "a")
		if f then
			f:write(string.format("%s loop n=%d fc=%d p1hp=%d p2hp=%d\n", os.date("%H:%M:%S"), n, emu.framecount(),
				memory.readbyte(0x02068C6C + 0x9F), memory.readbyte(0x02069104 + 0x9F)))
			f:close()
		end
	end
	emu.frameadvance()
end
