-- Lab de 360 (Hugo y otros grapplers): P1 pegado a un P2 quieto, prueba variantes de la secuencia y
-- loguea qué animación sale (frame data) y si el rival queda agarrado / pierde vida.
-- Env: CIPHER_P1 (hugo), CIPHER_BTN (lp)
local ROOT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\"
package.path = ROOT .. "?.lua;" .. package.path
local H = dofile(ROOT .. "tools\\harness.lua")
local OUT = ROOT .. "logs\\test_360.log"
local fh = io.open(OUT, "w")
local function L(fmt, ...) fh:write(string.format("[%d] " .. fmt .. "\n", emu.framecount(), ...)) fh:flush() end
local BTN = os.getenv("CIPHER_BTN") or "lp"

-- relativo (fwd/back) -> se resuelve con el lado
local V = {
	A = { {"f"}, {"d","f"}, {"d"}, {"d","b"}, {"b"}, {"u","b","B"} },
	B = { {"f"}, {"d"}, {"b"}, {"u","B"} },
	C = { {"f"}, {"f"}, {"d"}, {"d"}, {"b"}, {"b"}, {"u","B"} },
	D = { {"b"}, {"d","b"}, {"d"}, {"d","f"}, {"f"}, {"u","f","B"} },
	E = { {"f"}, {"d","f"}, {"d"}, {"d","b"}, {"b"}, {"u","b"}, {"u","B"} },
	F = { {"b"}, {"d","b"}, {"d"}, {"d","f"}, {"f"}, {"u","f"}, {"u","B"} },
}
local ORDER = { "A", "B", "C", "D", "E", "F" }

H.to_match({ p1 = os.getenv("CIPHER_P1") or "hugo", p2 = "ryu", sa1 = 1, sa2 = 1 }, function()
	local S = require("games.sfiii3.state")
	local phase, vi, step, t0, tries, res = "approach", 1, 0, 0, 0, {}
	emu.registerbefore(function()
		local s = S.read()
		if not s.in_match then joypad.set({}) return end
		local me, op = s.p[1], s.p[2]
		local right = op.x > me.x
		local function dir(k)
			if k == "f" then return right and "Right" or "Left" end
			if k == "b" then return right and "Left" or "Right" end
			if k == "u" then return "Up" end
			if k == "d" then return "Down" end
		end
		local t = {}
		if phase == "approach" then
			if s.dist > 52 then t["P1 " .. (right and "Right" or "Left")] = true
			elseif me.posture == 0 and not me.attacking and op.posture == 0 and op.hp > 0 then
				phase, step = "input", 1
			end
		elseif phase == "input" then
			local seq = V[ORDER[vi]]
			local fr = seq[step]
			for _, k in ipairs(fr) do
				if k == "B" then t["P1 " .. ({ lp = "Weak Punch", mp = "Medium Punch", hp = "Strong Punch", lk = "Weak Kick", mk = "Medium Kick", hk = "Strong Kick" })[BTN]] = true
				else t["P1 " .. dir(k)] = true end
			end
			step = step + 1
			if step > #seq then phase, t0, res = "watch", s.frame, { d = s.dist, hp = op.hp, moves = {} } end
		elseif phase == "watch" then
			if me.move and res.moves[#res.moves] ~= me.move then res.moves[#res.moves + 1] = me.move end
			if op.being_thrown then res.thrown = true end
			if me.airborne then res.air = true end
			if s.frame - t0 >= 40 then
				L("variante %s d=%d -> %s | agarrado=%s salto=%s dmg=%d", ORDER[vi], res.d, table.concat(res.moves, ">"),
					tostring(res.thrown), tostring(res.air), res.hp - op.hp)
				tries = tries + 1
				if tries % 2 == 0 then vi = vi % #ORDER + 1 end
				phase = "reset"
				t0 = s.frame
			end
		elseif phase == "reset" then
			-- alejarse un poco y esperar a que el rival se pare
			if s.frame - t0 < 20 then t["P1 " .. (right and "Left" or "Right")] = true
			elseif op.posture == 0 and not op.knocked_down then phase = "approach" end
		end
		joypad.set(t)
	end)
end)
