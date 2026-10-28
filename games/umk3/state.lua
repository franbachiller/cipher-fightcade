-- Sensor de UMK3 (umk3 rev 1.2, Midway Wolf / TMS34010). Mapa en la memoria del proyecto (umk3-ram-map) y en los
-- tools/umk3_*.py. OJO: la Lua de FBNeo direcciona por BIT (TMS34010): el byte real n está en 0x01000000 + 8*n,
-- las palabras de 16 bits van cada 0x10 (little-endian) y los punteros de la RAM ya son direcciones de bit.
local S = {}

local rb = memory.readbyte
local function rw(a) return rb(a) + rb(a + 8) * 256 end
local function rws(a) local v = rw(a) return v >= 0x8000 and v - 0x10000 or v end
local function rd(a) return rw(a) + rw(a + 0x10) * 65536 end
local function fixed(a) return rws(a + 0x10) + rw(a) / 65536 end      -- 16.16: fracción en a, entero en a+0x10
S.rw, S.rws, S.rd = rw, rws, rd

-- bloque fijo de cada jugador (0xBB0 de largo)
S.BLOCK = { 0x010609A0, 0x01061550 }
local B = { obj = 0x30, proc = 0x70, char = 0x90, hp = 0xC0, run = 0xD0 }
-- objeto del personaje (dinámico, desde el puntero del bloque)
local O = { vx = 0x40, vy = 0x60, x = 0x80, y = 0xA0, flags = 0xF0 }
-- proceso del personaje: registros guardados al dormir
local PR = { a11 = 0x60, a10 = 0x80, a9 = 0xA0, pc = 0xE0 }
S.CAM = { x = 0x0105DAE0, y = 0x0105D8A0 }
S.HP_MAX = 166
S.GROUND_Y = 112
S.STANCE_PC = 0xFF81FC00                -- postura neutral (A10/A11 quedan viejos acá)
S.CHARS = { [0] = "kano", "sonya", "jax", "nightwolf", "subzero", "stryker", "sindel", "sektor", "cyrax", "kunglao",
	"kabal", "sheeva", "shangtsung", "liukang", "smoke", "kitana", "jade", "mileena", "scorpion", "reptile", "ermac",
	"classic_subzero", "human_smoke", "noob_saibot" }

-- golpes desde la ROM (tools/umk3_strikes.py export): STRIKES[id].strikes[A11] = { x_off, y_off, w, h, hit, block }
local ROOT = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])games[\\/]") or ".\\"
local okS, STRIKES = pcall(dofile, ROOT .. "data\\umk3\\strikes.lua")
S.STRIKES = okS and STRIKES or {}

local function valid_ptr(p) return p >= 0x01000000 and p < 0x01080000 end

local function read_player(i)
	local blk = S.BLOCK[i]
	local p = { side = i, blk = blk }
	p.char = rw(blk + B.char)
	p.char_str = S.CHARS[p.char] or ("char" .. p.char)
	p.hp = rb(blk + B.hp)
	p.run = rw(blk + B.run)
	p.obj = rd(blk + B.obj)
	p.proc = rd(blk + B.proc)
	if valid_ptr(p.obj) then
		local o = p.obj
		p.x, p.y = rws(o + O.x + 0x10), rws(o + O.y + 0x10)
		p.vx, p.vy = fixed(o + O.vx), fixed(o + O.vy)
		p.flags = rw(o + O.flags)
		p.facing_right = (p.flags % 32) < 16                 -- bit 4 = espejado (mira a la izquierda)
		p.airborne = p.y < S.GROUND_Y - 2
	else
		p.x, p.y, p.vx, p.vy, p.facing_right, p.airborne = 0, 0, 0, 0, true, false
	end
	-- golpe activo: el proceso duerme en un bucle de golpe con A11 = índice y A10 = frames activos restantes
	if valid_ptr(p.proc) then
		p.pc, p.a11, p.a10, p.a9 = rd(p.proc + PR.pc), rd(p.proc + PR.a11), rd(p.proc + PR.a10), rd(p.proc + PR.a9)
		local tbl = S.STRIKES[p.char]
		local rec = tbl and tbl.strikes[p.a11]
		-- A10 = frames activos que quedan; en 0 la ventana ya terminó (el registro queda viejo: medido en vivo, el
		-- golpe figuraba activo 50 frames de más)
		if p.pc ~= S.STANCE_PC and rec and p.a10 >= 1 and p.a10 <= 40 then
			p.strike, p.strike_idx, p.strike_left = rec, p.a11, p.a10
		end
	end
	return p
end

-- caja de ataque en el mundo (como la función de cajas del juego, 0xFFAFF4C0): x_off es el borde lejano desde el
-- anipoint, espejado según hacia dónde mira; y_off hacia abajo desde la Y del objeto
function S.strike_box(p)
	local r = p.strike
	if not r then return nil end
	local x1
	if p.facing_right then x1 = p.x + r.x_off - r.w else x1 = p.x - r.x_off end
	return { l = x1, r = x1 + r.w, t = p.y + r.y_off, b = p.y + r.y_off + r.h }
end

function S.read()
	local s = { frame = emu.framecount(), p = { read_player(1), read_player(2) } }
	local a, b = s.p[1], s.p[2]
	s.dist = math.abs((a.x or 0) - (b.x or 0))
	s.cam_x, s.cam_y = rws(S.CAM.x), rws(S.CAM.y)
	s.in_match = valid_ptr(a.obj) and valid_ptr(b.obj) and a.char < 24 and b.char < 24
		and a.hp <= S.HP_MAX and b.hp <= S.HP_MAX and (a.hp > 0 or b.hp > 0)
	s.timer = 0
	return s
end

return S
