-- ¿Funcionan los savestates en memoria? Guarda en la pelea, avanza, carga y compara estado.
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
local H = dofile(ROOT .. "tools\\harness.lua")
local f = io.open(ROOT .. "logs\\probe_savestate.log", "w")
local function L(...) f:write(string.format(...) .. "\n") f:flush() end
local P2 = 0x02069104
local function snap() return string.format("fc=%d timer=%d p1x=%d p2x=%d p1hp=%d", emu.framecount(), memory.readbyte(0x02011377),
	memory.readwordsigned(0x02068C6C + 0x64), memory.readwordsigned(P2 + 0x64), memory.readbyte(0x02068C6C + 0x9F)) end

H.to_match({ p1 = "ryu", p2 = "ken" }, function()
	local st, phase, t0 = nil, 0, emu.framecount()
	emu.registerbefore(function()
		local fc = emu.framecount() - t0
		if phase == 0 and fc == 30 then
			st = savestate.create(tonumber(os.getenv("CIPHER_SLOT") or "9"))
			L("created %s", tostring(st))
			savestate.save(st)
			L("SAVED   %s", snap())
			phase = 1
		elseif phase == 1 then
			joypad.set({ ["P2 Left"] = true, ["P1 Right"] = true })   -- mover a ambos
			if fc == 150 then L("MOVED   %s", snap()) savestate.load(st) phase = 2 end
		elseif phase == 2 then
			L("LOADED  %s", snap())
			-- segunda vuelta: repetir determinista
			phase = 3
		elseif phase == 3 and fc >= 160 then
			local t = os.clock()
			for i = 1, 20 do savestate.load(st) end
			L("20 loads en %.1f ms", (os.clock() - t) * 1000)
			phase = 4
		end
	end)
end)
