-- RE offline: deja una marca conocida en RAM de CPS3 y publica valores de referencia para el escáner externo.
-- 0x0207FFF0..FF = patrón mágico (16 bytes) · 0x0207FFE0 = emu.framecount() (dword, escrito cada frame)
local OUT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\logs\\probe_ramfind.log"
local MAGIC = { 0xC1, 0x9E, 0x7A, 0x33, 0x05, 0xD2, 0x11, 0xFB, 0x48, 0x6C, 0xA0, 0x0F, 0x93, 0x27, 0xE8, 0x5D }
local function stamp()
	for i, v in ipairs(MAGIC) do memory.writebyte(0x0207FFF0 + i - 1, v) end
	memory.writedword(0x0207FFE0, emu.framecount())
end
emu.registerafter(function()
	stamp()
	if emu.framecount() % 30 == 0 then
		local f = io.open(OUT, "w")
		if f then
			local hex = {}
			for i = 0, 15 do hex[#hex + 1] = string.format("%02X", memory.readbyte(0x0207FFF0 + i)) end
			f:write(string.format("fc=%d rb=%s rw=%04X rd=%08X p1hp=%d p2hp=%d p1x=%d\n", emu.framecount(), table.concat(hex),
				memory.readword(0x0207FFF0), memory.readdword(0x0207FFF0),
				memory.readbyte(0x02068C6C + 0x9F), memory.readbyte(0x02069104 + 0x9F), memory.readwordsigned(0x02068C6C + 0x64)))
			f:close()
		end
	end
end)
