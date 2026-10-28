-- Harness de pruebas offline (backend lua): bootea, fuerza personajes/SA por RAM y llega a la pelea.
-- Uso:  local H = dofile(".../tools/harness.lua"); H.to_match({p1="ryu", p2="ken", sa1=1, sa2=3}, function() ... end)
local H = {}

-- {col, row} de la grilla (effie character_select.lua)
local GRID = { alex = {0,1}, sean = {0,2}, ibuki = {0,3}, necro = {0,4}, urien = {0,5}, gouki = {0,6},
	yang = {1,0}, twelve = {1,1}, makoto = {1,2}, chunli = {1,3}, q = {1,4}, remy = {1,5}, yun = {1,6},
	ken = {2,0}, hugo = {2,1}, elena = {2,2}, dudley = {2,3}, oro = {2,4}, ryu = {2,5} }
local SEL = {
	{ row = 0x020154CF, col = 0x0201566B, sa = 0x020154D3, state = 0x0201553D },
	{ row = 0x020154D1, col = 0x0201566D, sa = 0x020154D5, state = 0x02015545 },
}

function H.to_match(opts, on_match)
	if emu.speedmode then emu.speedmode("turbo") end
	local start, done, sa_wait = emu.framecount(), false, { 0, 0 }
	emu.registerbefore(function()
		if done then return end
		if memory.readbyte(0x020154A7) == 0x02 and memory.readbyte(0x0201546B) == 0x04 then
			done = true
			if emu.speedmode then emu.speedmode("normal") end
			on_match()
			return
		end
		local t, fc = {}, emu.framecount() - start
		for p = 1, (opts.arcade and 1 or 2) do
			local pre, sel = "P" .. p .. " ", SEL[p]
			local st = memory.readbyte(sel.state)
			local want = opts["p" .. p]
			if st == 2 and want and GRID[want] then
				memory.writebyte(sel.col, GRID[want][1])
				memory.writebyte(sel.row, GRID[want][2])
				if fc % 6 < 2 then t[pre .. "Weak Punch"] = true end
			elseif st == 4 then
				local sa = opts["sa" .. p]
				if sa then memory.writebyte(sel.sa, sa - 1) end
				sa_wait[p] = sa_wait[p] + 1
				if sa_wait[p] > 6 and fc % 6 < 2 then t[pre .. "Weak Punch"] = true end
			elseif st == 0 or st == 1 then
				local ph = fc % 24
				if ph < 2 then t[pre .. "Coin"] = true elseif ph >= 12 and ph < 14 then t[pre .. "Start"] = true end
			end
		end
		joypad.set(t)
	end)
end

return H
