-- Verifica la física del salto: y(t+1) = y(t) + vy(t)? vy(t+1) = vy(t) + ay? (y x con flip)
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
package.path = ROOT .. "?.lua;" .. package.path
local H = dofile(ROOT .. "tools\\harness.lua")
local S = require("games.sfiii3.state")
local f = io.open(ROOT .. "logs\\probe_jump.log", "w")
H.to_match({ p1 = "ryu", p2 = "ken" }, function()
	local fr = 0
	emu.registerbefore(function()
		local s = S.read()
		local p = s.p[2]
		fr = fr + 1
		if fr >= 30 and fr < 33 then joypad.set({ ["P2 Up"] = true, ["P2 Left"] = true }) end
		if fr >= 30 and fr <= 80 then
			f:write(string.format("f=%d x=%.2f y=%.2f vx=%.2f vy=%.2f ax=%.3f ay=%.3f flip=%d air=%s post=%02x\n",
				fr, p.x, p.y, p.vx, p.vy, p.ax, p.ay, p.flip, tostring(p.airborne), p.posture))
			f:flush()
		end
		if fr == 81 then f:close() os.exit(0) end
	end)
end)
