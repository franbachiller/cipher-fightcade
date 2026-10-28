-- Lab de tech: P2 camina y agarra; P1 quieto aprieta LP+LK K frames después de que su flag "being thrown"
-- sube (K = 0..6, rota), o K negativo = apretar al ver la animación de agarre del rival. Loguea TECHED/FAILED por K.
local ROOT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\"
package.path = ROOT .. "?.lua;" .. package.path
local H = dofile(ROOT .. "tools\\harness.lua")
local fh = io.open(ROOT .. "logs\\test_tech.log", "w")
local function L(fmt, ...) fh:write(string.format("[%d] " .. fmt .. "\n", emu.framecount(), ...)) fh:flush() end
local KS = { 0, 1, 2, 3, 4, 5, 6 }
local HOLD = tonumber(os.getenv("CIPHER_TECH_HOLD") or "1")

H.to_match({ p1 = "ken", p2 = "ryu", sa1 = 1, sa2 = 1 }, function()
	local S = require("games.sfiii3.state")
	local ki, pending, press_at, hp0, watch = 1, nil, nil, nil, nil
	local cd = 0
	emu.registerbefore(function()
		local s = S.read()
		local t = {}
		if not s.in_match then joypad.set(t) return end
		local me, op = s.p[1], s.p[2]
		local right2 = me.x > op.x                     -- P2 mira hacia P1
		-- P2: caminar y agarrar
		if cd > 0 then cd = cd - 1 end
		if not op.attacking and not op.being_thrown and not me.being_thrown and cd == 0 and not watch then
			if s.dist > 46 then t["P2 " .. (right2 and "Right" or "Left")] = true
			else
				t["P2 " .. (right2 and "Right" or "Left")] = true
				t["P2 Weak Punch"], t["P2 Weak Kick"] = true, true
				cd = 40
			end
		end
		-- P1: tech K frames después de que lo agarran
		if me.has_just_been_thrown and not watch then
			press_at = s.frame + KS[ki]
			watch = { frame = s.frame, k = KS[ki], hp = me.hp, cd = me.throw_countdown }
		end
		if press_at and s.frame >= press_at and s.frame < press_at + HOLD then
			t["P1 Weak Punch"], t["P1 Weak Kick"] = true, true
		end
		if watch and s.frame - watch.frame >= 90 then
			local dmg = watch.hp - ((me.hp == 255) and 0 or me.hp)
			L("K=%d hold=%d cd=%d -> %s dmg=%d", watch.k, HOLD, watch.cd, dmg > 0 and "FAILED" or "TECHED", dmg)
			watch, press_at = nil, nil
			ki = ki % #KS + 1
			cd = 30
		end
		joypad.set(t)
	end)
end)
