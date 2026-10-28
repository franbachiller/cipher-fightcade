-- Valida medidor y ejecución de super: P2 Ken (SA3) carga barra con cr.MK sobre P1 quieto y tira qcf qcf+LK.
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
package.path = ROOT .. "?.lua;" .. package.path
local H = dofile(ROOT .. "tools\\harness.lua")
local S = require("games.sfiii3.state")
local f = io.open(ROOT .. "logs\\validate_super.log", "w")
local function L(...) f:write(string.format(...) .. "\n") f:flush() end
local rb = memory.readbyte
local A = { meter_master = 0x020695EB, gauge = 0x020695E1, max_gauge = 0x020695DF, max_count = 0x020695E9, sa_state = 0x020695D9, sel_sa = 0x0201138C }

local QCF2_LK = { { ["P2 Down"] = true }, { ["P2 Down"] = true, ["P2 Left"] = true }, { ["P2 Left"] = true },
	{ ["P2 Down"] = true }, { ["P2 Down"] = true, ["P2 Left"] = true }, { ["P2 Left"] = true, ["P2 Weak Kick"] = true },
	{ ["P2 Left"] = true, ["P2 Weak Kick"] = true } }

local SEQ1 = QCF2_LK
local SEQ2 = {}
for _, fr in ipairs(QCF2_LK) do SEQ2[#SEQ2 + 1] = fr SEQ2[#SEQ2 + 1] = fr end
H.to_match({ p1 = "ryu", p2 = "ken", sa1 = 1, sa2 = 3 }, function()
	local t0, tries, seq_i, prev_mm, watch = emu.framecount(), 0, nil, -1, 0
	L("in match")
	emu.registerbefore(function()
		local s = S.read()
		local p2 = s.p[2]
		local fc = emu.framecount() - t0
		local mm, g = rb(A.meter_master), rb(A.gauge)
		if fc % 60 == 0 or mm ~= prev_mm then
			L("fc=%d meter_master=%d gauge=%d max_gauge=%d max_count=%d sa_state=%d sel_sa=%d | state.meter=%d state.gauge=%d sa=%d",
				fc, mm, g, rb(A.max_gauge), rb(A.max_count), rb(A.sa_state), rb(A.sel_sa), p2.meter, p2.gauge, p2.sa)
			prev_mm = mm
		end
		if watch > 0 then
			watch = watch - 1
			L("  +%d P2 anim=%s move=%s att=%s P1 hp=%d sa_state=%d", 40 - watch, p2.anim, tostring(p2.move), tostring(p2.attacking), s.p[1].hp, rb(A.sa_state))
		end
		if seq_i then
			joypad.set(QCF2_LK[seq_i])
			seq_i = seq_i + 1
			if seq_i > #QCF2_LK then seq_i = nil watch = 40 end
			return
		end
		if mm >= 1 and tries < 4 and watch == 0 and (p2.move == "standing" or p2.move == "crouching") and not p2.attacking then
			tries = tries + 1
			QCF2_LK = (tries % 2 == 1) and SEQ1 or SEQ2
			L("TRY super #%d %s (meter_master=%d gauge=%d) from=%s", tries, (tries % 2 == 1) and "1f" or "2f", mm, g, p2.move)
			seq_i = 1
			return
		end
		if mm >= 1 and tries < 4 then return end   -- esperar neutral sin cargar más
		-- cargar barra: cr.MK cada 20 frames, acercándose a P1
		local ph = fc % 20
		if s.dist > 100 then joypad.set({ ["P2 Left"] = true })
		elseif ph < 2 then joypad.set({ ["P2 Down"] = true, ["P2 Medium Kick"] = true }) end
		-- P1 vida infinita para que la pelea no termine
		memory.writebyte(S.P[1].base + 0x9F, 160)
	end)
end)
