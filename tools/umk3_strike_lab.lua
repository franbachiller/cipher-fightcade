-- Lab de golpes UMK3: confirma en vivo la cadena del golpe activo.
-- Entra a una pelea 2P (P1 elige con LP, P2 se une y queda quieto), pone a P2 al lado de P1 escribiendo su X, y P1
-- hace cada normal aislado. Por frame loguea: PC de retorno del proceso de P1 (+0xE0), A11 (+0x60), A10 (+0x80),
-- el registro de golpe que da la cadena (tabla maestra[id][A11]) y la vida de P2.  Log: logs\umk3_strike_lab.log
local ROOT = "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade\\"
local f = io.open(ROOT .. "logs\\umk3_strike_lab.log", "w")
local function L(...) f:write(string.format(...) .. "\n") f:flush() end
local rb = memory.readbyte
local function rw(a) return rb(a) + rb(a + 8) * 256 end
local function rws(a) local v = rw(a) return v >= 0x8000 and v - 0x10000 or v end
local function rd(a) return rw(a) + rw(a + 0x10) * 65536 end
local P = { { blk = 0x010609A0 }, { blk = 0x01061550 } }
local MASTER = 0xFFAF2480
local STRIKER_PC = 0xFFAFF1A0

-- golpes a probar: nombre, teclas (cada uno 3 frames), frames de espera
local MOVES = {
	{ "HK", { "P1 High Kick" } }, { "LK", { "P1 Low Kick" } }, { "HP", { "P1 High Punch" } }, { "LP", { "P1 Low Punch" } },
	{ "sweep", { "P1 Down", "P1 High Kick" }, true }, { "dLP", { "P1 Down", "P1 Low Punch" }, true },
	{ "dHK", { "P1 Down", "P1 High Kick" }, true }, { "dLK", { "P1 Down", "P1 Low Kick" }, true },
	{ "uppercut", { "P1 Down", "P1 High Punch" }, true }, { "back HK (roundhouse)", { "P1 Left", "P1 High Kick" } },
}
local MENU = { [300] = { "P1 Low Punch" }, [700] = { "P1 Coin" }, [780] = { "P1 Coin" }, [860] = { "P2 Coin" },
	[940] = { "P2 Coin" }, [1020] = { "P1 Start" }, [1300] = { "P2 Start" }, [1360] = { "P2 Start" },
	[1550] = { "P1 Low Punch" }, [1620] = { "P2 Low Punch" } }
local start, DIPS, fight_at = emu.framecount(), nil, nil
local mi, mstart = 0, 0

local function strike_of(id, a11)
	local lst = rd(MASTER + id * 0x20)
	local rec = rd(lst + a11 * 0x20)
	if rec < 0xFF800000 then return nil end
	return { x = rws(rec), y = rws(rec + 0x10), w = rws(rec + 0x20), h = rws(rec + 0x30), dmg = rw(rec + 0x50) }
end

emu.registerbefore(function()
	local fc = emu.framecount() - start
	if not DIPS then local j = joypad.get() DIPS = { ["Dip A"] = j["Dip A"], ["Dip B"] = j["Dip B"] } end
	local t = { ["Dip A"] = DIPS["Dip A"], ["Dip B"] = DIPS["Dip B"] }
	for fr, keys in pairs(MENU) do if fc >= fr and fc < fr + 4 then for _, k in ipairs(keys) do t[k] = true end end end
	local hp1, hp2 = rb(P[1].blk + 0xC0), rb(P[2].blk + 0xC0)
	if not fight_at and fc > 1800 and hp1 > 0 and hp2 > 0 then fight_at = fc + 240 L("pelea en fc=%d", fc) end
	if fight_at and fc >= fight_at then
		-- P2 pegado a P1 (X por RAM, entero del objeto +0x90), vidas llenas
		local o1, o2 = rd(P[1].blk + 0x30), rd(P[2].blk + 0x30)
		local x1 = rws(o1 + 0x90)
		local dirx = (rws(o2 + 0x90) >= x1) and 1 or -1
		memory.writeword(o2 + 0x90, x1 + dirx * 60)
		memory.writebyte(P[1].blk + 0xC0, 166) memory.writebyte(P[2].blk + 0xC0, 166)
		local k = fc - mstart
		if mi == 0 or k >= 90 then
			mi, mstart, k = mi + 1, fc, 0
			if not MOVES[mi] then L("FIN") f:close() os.exit(0) end
			L("== %s", MOVES[mi][1])
		end
		local mv = MOVES[mi]
		if mv[3] and k < 40 then t["P1 Down"] = true end       -- agachado: sostener abajo
		if k >= 8 and k < 11 then for _, key in ipairs(mv[2]) do t[key] = true end end
		local proc = rd(P[1].blk + 0x70)
		local pc, a11, a10 = rd(proc + 0xE0), rd(proc + 0x60), rd(proc + 0x80)
		local id = rw(P[1].blk + 0x90)
		if k < 45 then
			local s = (pc == STRIKER_PC) and strike_of(id, a11 % 64)
			-- hp2 se leyó al empezar el frame (antes de rellenar la vida): < 166 = el golpe conectó en el frame anterior
			L("k=%2d pc=%08X a11=%d a10=%d p2hp=%d %s", k, pc, a11, a10, hp2,
				s and string.format("GOLPE x_off=%d y_off=%d %dx%d dmg=%d/%d", s.x, s.y, s.w, s.h, math.floor(s.dmg / 256), s.dmg % 256) or "")
		end
	end
	joypad.set(t)
end)
