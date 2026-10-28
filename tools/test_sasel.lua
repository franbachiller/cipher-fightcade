-- Test: lleva a P1 hasta la pantalla de SA y NO elige: lo tiene que elegir CIPHER externo (tools\cipher_ext.py).
-- P2 elige normal. Loguea el SA final de P1 al empezar la pelea.
local OUT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\logs\\test_sasel.log"
local GRID = { chunli = {1,3}, ken = {2,0} }
local SEL = {
	{ row = 0x020154CF, col = 0x0201566B, sa = 0x020154D3, state = 0x0201553D },
	{ row = 0x020154D1, col = 0x0201566D, sa = 0x020154D5, state = 0x02015545 },
}
local p1 = os.getenv("CIPHER_P1") or "chunli"
local start, done = emu.framecount(), false
local f = io.open(OUT, "w") f:write("start\n") f:close()
local function L(s) local h = io.open(OUT, "a") h:write(string.format("[%d] %s\n", emu.framecount(), s)) h:close() end
emu.registerbefore(function()
	if done then return end
	if memory.readbyte(0x020154A7) == 0x02 and memory.readbyte(0x0201546B) == 0x04 then
		done = true
		L("pelea: P1 SA=" .. (memory.readbyte(0x0201138B) + 1))
		return
	end
	local t, fc = {}, emu.framecount() - start
	for p = 1, 2 do
		local pre, sel = "P" .. p .. " ", SEL[p]
		local st = memory.readbyte(sel.state)
		local want = (p == 1) and p1 or "ken"
		if st == 2 then
			memory.writebyte(sel.col, GRID[want][1])
			memory.writebyte(sel.row, GRID[want][2])
			if fc % 6 < 2 then t[pre .. "Weak Punch"] = true end
		elseif st == 4 then
			if p == 1 then
				if not L1 then L1 = true L("P1 en pantalla de SA, cursor=" .. (memory.readbyte(sel.sa) + 1)) end
			elseif fc % 6 < 2 then t[pre .. "Weak Punch"] = true end
		elseif st == 0 or st == 1 then
			local ph = fc % 24
			if ph < 2 then t[pre .. "Coin"] = true elseif ph >= 12 and ph < 14 then t[pre .. "Start"] = true end
		end
	end
	joypad.set(t)
end)
