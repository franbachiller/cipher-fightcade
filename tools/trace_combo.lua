-- Traza frame a frame un combo del laboratorio: CIPHER_TRACE_SEQ="LK@0,d_LP@22" (normales con su frame de input).
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
package.path = ROOT .. "?.lua;" .. package.path
input_lib = require("core.input")
local H = dofile(ROOT .. "tools\\harness.lua")
local S = require("games.sfiii3.state")
local auto = require("games.sfiii3.chars.auto")
local CHAR, DIST = os.getenv("CIPHER_LAB_CHAR") or "ken", tonumber(os.getenv("CIPHER_LAB_DIST") or "60")
local f = io.open(ROOT .. "logs\\trace_combo.log", "w")
local function L(...) f:write(string.format(...) .. "\n") f:flush() end
local by = {}
for _, n in ipairs(auto(CHAR).normals) do by[n.name] = by[n.name] or n end
local plan = {}
for nm, at in (os.getenv("CIPHER_TRACE_SEQ") or "LK@0,d_LP@22"):gmatch("([%w_]+)@(%d+)") do
	plan[tonumber(at)] = by[nm] plan[tonumber(at) + 1] = by[nm]
end
local NAMES = { lp = "Weak Punch", mp = "Medium Punch", hp = "Strong Punch", lk = "Weak Kick", mk = "Medium Kick", hk = "Strong Kick" }
H.to_match({ p1 = "ryu", p2 = CHAR }, function()
	local state, fr, fwd = "position", 0, nil
	emu.registerbefore(function()
		memory.writebyte(0x02011377, 99)
		local s = S.read()
		if state == "position" then
			fwd = (s.p[1].x < s.p[2].x) and "P2 Left" or "P2 Right"
			if s.dist > DIST then joypad.set({ [fwd] = true }) return end
			state, fr = "settle", 0 return
		elseif state == "settle" then
			fr = fr + 1 if fr >= 25 then state, fr = "run", 0 end return
		elseif state == "run" then
			local n = plan[fr]
			local j = {}
			if n then
				j["P2 " .. NAMES[n.btn]] = true
				if n.dirs.down then j["P2 Down"] = true end
				if n.dirs.fwd then j[fwd] = true end
				if n.dirs.back then j[fwd == "P2 Left" and "P2 Right" or "P2 Left"] = true end
			end
			joypad.set(j)
			L("f=%2d in=%-6s P2=%-12s af=%2d att=%s | P1 hp=%3d move=%-14s post=%02x fz=%d | combo=%d recv=%d",
				fr, n and n.name or "", tostring(s.p[2].move), s.p[2].anim_frame, tostring(s.p[2].attacking), s.p[1].hp,
				tostring(s.p[1].move), s.p[1].posture, s.p[1].freeze, memory.readbyte(0x0206961D), s.p[1].recv_total)
			fr = fr + 1
			if fr > 60 then state = "done" f:close() os.exit(0) end
		end
	end)
end)
