-- Verificación de alcances: pone a P2 (quieto) a distancia exacta D de P1 escribiendo su X en RAM y P1 hace el
-- golpe/agarre. Loguea si conectó (rival agarrado o recibió el golpe). Barrido de D por env.
-- Env: CIPHER_P1, CIPHER_P2, CIPHER_MOVE (throw|moonsault|dMK|dLK), CIPHER_DMIN, CIPHER_DMAX
local ROOT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\"
package.path = ROOT .. "?.lua;" .. package.path
local H = dofile(ROOT .. "tools\\harness.lua")
local fh = io.open(ROOT .. "logs\\" .. (os.getenv("CIPHER_LOGNAME") or "test_range") .. ".log", "w")
local function L(fmt, ...) fh:write(string.format(fmt .. "\n", ...)) fh:flush() end
local MOVE = os.getenv("CIPHER_MOVE") or "throw"
local DMIN, DMAX = tonumber(os.getenv("CIPHER_DMIN") or "66"), tonumber(os.getenv("CIPHER_DMAX") or "82")
local P2X = 0x02069104 + 0x64

-- secuencias (P1 mirando a la derecha: adelante = Right)
local SEQ = {
	throw = { { "Weak Punch", "Weak Kick" } },
	moonsault = { { "Left" }, { "Left", "Down" }, { "Down" }, { "Down", "Right" }, { "Right" }, { "Up", "Right" }, { "Up", "Weak Punch" } },
	dMK = { { "Down", "Medium Kick" } },
	dLK = { { "Down", "Weak Kick" } },
	dHK = { { "Down", "Strong Kick" } },
	-- kara throw de Ryu (wiki Ryu/Strategy): adelante sostenido, f.MP y LP+LK al frame siguiente
	kara_fMP = { { "Right" }, { "Right" }, { "Right", "Medium Punch" }, { "Right", "Weak Punch", "Weak Kick" } },
	-- kara throw de Chun-Li: st.MK cancelado al frame siguiente en agarre
	kara_stMK = { { "Medium Kick" }, { "Weak Punch", "Weak Kick" } },
	-- kara throw de Oro: st.HK cancelado al frame siguiente en agarre
	kara_stHK = { { "Strong Kick" }, { "Weak Punch", "Weak Kick" } },
	MK = { { "Medium Kick" } },
	HK = { { "Strong Kick" } },
	-- Alex: kara f.HP > agarre y Power Bomb (63214+P, P1 mirando a la derecha)
	kara_fHP = { { "Right", "Strong Punch" }, { "Right", "Weak Punch", "Weak Kick" } },
	power_bomb = { { "Right" }, { "Right", "Down" }, { "Down" }, { "Down", "Left" }, { "Left", "Weak Punch" } },
	walk_throw = { { "Right" }, { "Right" }, { "Right", "Weak Punch", "Weak Kick" } },
}

H.to_match({ p1 = os.getenv("CIPHER_P1") or "ken", p2 = os.getenv("CIPHER_P2") or "ryu", sa1 = 1, sa2 = 1 }, function()
	local S = require("games.sfiii3.state")
	local D, phase, t0, step, res = DMIN, "place", 0, 1, nil
	emu.registerbefore(function()
		local s = S.read()
		local t = {}
		if not s.in_match then joypad.set(t) return end
		local me, op = s.p[1], s.p[2]
		if phase == "place" then
			memory.writeword(P2X, me.x + D)
			if s.frame - t0 > 20 and me.posture == 0 and not me.attacking and op.posture == 0 and not op.knocked_down then
				phase, step, res = "go", 1, { d = s.dist, hp = op.hp }
			end
		elseif phase == "go" then
			for _, b in ipairs(SEQ[MOVE][step]) do t["P1 " .. b] = true end
			step = step + 1
			if step > #SEQ[MOVE] then phase, t0 = "watch", s.frame end
		elseif phase == "watch" then
			if op.being_thrown then res.thrown = true end
			if op.hp < res.hp then res.hit = true end
			if s.frame - t0 > 70 then
				L("%s D=%d (dist real %d) -> %s", MOVE, D, res.d, (res.thrown and "AGARRA") or (res.hit and "PEGA") or "NADA")
				D = D + 2
				if D > DMAX then D = DMIN end
				phase, t0 = "place", s.frame
			end
		end
		joypad.set(t)
	end)
end)
