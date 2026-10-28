-- Avanza desde cualquier pantalla hasta una pelea (mash coin/start/LP en ambos lados)
-- y guarda savestate en <script dir>\savestates\sfiii3nr1 slot 01.fs. Loguea a logs\harness.log
os.execute('mkdir savestates 2>nul') os.execute('mkdir logs 2>nul')
local f = io.open("logs\\harness.log", "w")
local function L(...) f:write(string.format(...) .. "\n") f:flush() end
local rb, rd = memory.readbyte, memory.readdword
local P = { 0x02068C6C, 0x02069104 }
if emu.speedmode then emu.speedmode("turbo") end

local start, last_timer, ticks, saved = emu.framecount(), -1, 0, false
emu.registerbefore(function()
	local fc = emu.framecount() - start
	local timer = rb(0x02011377)
	local hp1, hp2 = rb(P[1] + 0x9F), rb(P[2] + 0x9F)
	if fc % 30 == 0 then
		L("fc=%d match=%08X timer=%d hp=%d/%d x=%d/%d", fc, rd(0x020154A6), timer, hp1, hp2,
			memory.readwordsigned(P[1] + 0x64), memory.readwordsigned(P[2] + 0x64))
	end
	-- pelea: timer bajando con ambos HP plenos
	if timer ~= last_timer then
		if last_timer ~= -1 and timer == last_timer - 1 and hp1 == 160 and hp2 == 160 then ticks = ticks + 1 end
		last_timer = timer
	end
	if ticks >= 2 and not saved then
		saved = true
		local s = savestate.create(1) savestate.save(s)
		L("SAVED fc=%d match=%08X timer=%d", fc, rd(0x020154A6), timer)
		if emu.speedmode then emu.speedmode("normal") end
		return
	end
	if saved then return end
	local ph = fc % 24
	local t = {}
	if ph < 2 then t["P1 Weak Punch"] = true t["P2 Weak Punch"] = true
	elseif ph >= 8 and ph < 10 then t["P2 Coin"] = true t["P1 Coin"] = true
	elseif ph >= 16 and ph < 18 then t["P2 Start"] = true t["P1 Start"] = true end
	joypad.set(t)
end)
