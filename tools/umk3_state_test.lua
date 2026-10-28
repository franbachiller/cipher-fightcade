-- Prueba del sensor games/umk3/state.lua en vivo: entra a una pelea 2P, P1 camina hacia P2 y ataca; loguea lo que
-- lee el sensor y la caja del golpe activo.  Log: logs\umk3_state_test.log
local ROOT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\"
package.path = ROOT .. "?.lua;" .. package.path
local S = require("games.umk3.state")
local f = io.open(ROOT .. "logs\\umk3_state_test.log", "w")
local function L(...) f:write(string.format(...) .. "\n") f:flush() end
local MENU = { [300] = { "P1 Low Punch" }, [700] = { "P1 Coin" }, [780] = { "P1 Coin" }, [860] = { "P2 Coin" },
	[940] = { "P2 Coin" }, [1020] = { "P1 Start" }, [1300] = { "P2 Start" }, [1360] = { "P2 Start" },
	[1550] = { "P1 Low Punch" }, [1620] = { "P2 Low Punch" } }
local start, DIPS, fight_at = emu.framecount(), nil, nil
L("golpes cargados: %d personajes", #S.STRIKES + 1)
emu.registerbefore(function()
	local fc = emu.framecount() - start
	if not DIPS then local j = joypad.get() DIPS = { ["Dip A"] = j["Dip A"], ["Dip B"] = j["Dip B"] } end
	local t = { ["Dip A"] = DIPS["Dip A"], ["Dip B"] = DIPS["Dip B"] }
	for fr, keys in pairs(MENU) do if fc >= fr and fc < fr + 4 then for _, k in ipairs(keys) do t[k] = true end end end
	local s = S.read()
	if s.in_match and not fight_at and fc > 1800 then fight_at = fc + 200 L("en pelea fc=%d", fc) end
	if fight_at and fc >= fight_at then
		local k = fc - fight_at
		local me, op = s.p[1], s.p[2]
		local fwd = (op.x > me.x) and "P1 Right" or "P1 Left"
		if k < 120 then if s.dist > 70 then t[fwd] = true end
		elseif k < 200 then if k == 130 then t["P1 High Kick"] = true end
		elseif k < 280 then t["P1 Down"] = true if k == 210 then t["P1 High Kick"] = true end
		elseif k < 320 then t[fwd] = true
		else L("FIN") f:close() os.exit(0) end
		if k % 4 == 0 or me.strike then
			local bx = S.strike_box(me)
			L("k=%3d d=%3d P1 %s hp=%d x=%d y=%d vx=%.2f mira_der=%s aire=%s run=%d | P2 %s hp=%d x=%d | %s",
				k, s.dist, me.char_str, me.hp, me.x, me.y, me.vx, tostring(me.facing_right), tostring(me.airborne), me.run,
				op.char_str, op.hp, op.x,
				bx and string.format("GOLPE[%d] quedan=%d caja x=%d..%d y=%d..%d dmg=%d", me.strike_idx, me.strike_left,
					bx.l, bx.r, bx.t, bx.b, me.strike.hit) or "-")
		end
	end
	joypad.set(t)
end)
