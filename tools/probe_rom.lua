-- RE: ¿a dónde apuntan los punteros de cajas? Vuelca el puntero y 256 bytes de datos (vía Lua) para ubicarlos desde
-- afuera en la memoria del proceso.
local ROOT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\"
local H = dofile(ROOT .. "tools\\harness.lua")
H.to_match({ p1 = "ken", p2 = "ryu", sa1 = 1, sa2 = 1 }, function()
	local n = 0
	emu.registerafter(function()
		n = n + 1
		if n ~= 120 then return end
		local f = io.open(ROOT .. "logs\\probe_rom.log", "w")
		for _, off in ipairs({ 0x2A0, 0x2C8, 0x2D4, 0x2C0 }) do
			local ptr = memory.readdword(0x02068C6C + off)
			local hex = {}
			for i = 0, 255 do hex[#hex + 1] = string.format("%02X", memory.readbyte(ptr + i)) end
			f:write(string.format("%X %08X %s\n", off, ptr, table.concat(hex)))
		end
		f:close()
	end)
end)
