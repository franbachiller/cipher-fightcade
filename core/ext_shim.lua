-- CIPHER externo: API de FBNeo-Lua (memory/emu/gui/input/joypad) sobre la RAM de CPS3 leída desde
-- fuera del emulador (ReadProcessMemory). La carga tools\cipher_ext.py ANTES de cipher.lua.
-- Online (quark:served) Fightcade no ejecuta hooks de Lua: el bucle de frames lo maneja Python.
local PY = ...                         -- tabla de Python: keys() -> "insert,home", sink(line), rom
local byte = string.byte
local BASE, SIZE = 0x02000000, 0x80000
local R, FC = string.rep("\0", SIZE), 0   -- RAM en orden big-endian lineal (Python ya des-swapeó los dwords)

CIPHER_EXT = true
CIPHER_EXT_SINK = PY.sink

local hooks = { before = {}, after = {}, exit = {} }

function __ext_frame(ram, fc)
	R, FC = ram, fc
	for _, fn in ipairs(hooks.before) do fn() end
	for _, fn in ipairs(hooks.after) do fn() end
end

function __ext_exit()
	for _, fn in ipairs(hooks.exit) do pcall(fn) end
end

local function idx(a)
	local i = a - BASE
	if i < 0 or i >= SIZE then return nil end
	return i + 1
end

-- fuera de la RAM principal (ROM 0x06000000: cajas de ataque / empuje / agarre) -> Python lee la ROM del proceso
-- (estática, con caché por página). Sin esto las cajas de ataque salían vacías online: bolas invisibles.
local romb = PY.rom_byte

memory = {}
function memory.readbyte(a)
	local i = idx(a)
	if i then return byte(R, i) end
	return romb and romb(a) or 0
end
function memory.readbytesigned(a) local v = memory.readbyte(a) return v >= 128 and v - 256 or v end
function memory.readword(a)
	local i = idx(a)
	if not i then
		if not romb then return 0 end
		return romb(a) * 256 + romb(a + 1)
	end
	local x, y = byte(R, i, i + 1)
	return x * 256 + (y or 0)
end
function memory.readwordsigned(a) local v = memory.readword(a) return v >= 32768 and v - 65536 or v end
function memory.readdword(a)
	local i = idx(a)
	if not i then
		if not romb then return 0 end
		return memory.readword(a) * 65536 + memory.readword(a + 2)
	end
	local x, y, z, w = byte(R, i, i + 3)
	return ((x * 256 + (y or 0)) * 256 + (z or 0)) * 256 + (w or 0)
end
function memory.readdwordsigned(a) local v = memory.readdword(a) return v >= 2147483648 and v - 4294967296 or v end
local function nop() end
memory.writebyte, memory.writeword, memory.writedword = nop, nop, nop      -- online: nunca escribir RAM
memory.register, memory.registerwrite, memory.registerexec = nop, nop, nop

emu = {}
function emu.framecount() return FC end
function emu.romname() return PY.rom end
function emu.parentname() return "sfiii3" end
function emu.screenwidth() return 384 end
function emu.screenheight() return 224 end
function emu.registerbefore(fn) hooks.before[#hooks.before + 1] = fn end
function emu.registerafter(fn) hooks.after[#hooks.after + 1] = fn end
function emu.registerexit(fn) hooks.exit[#hooks.exit + 1] = fn end
emu.frameadvance, emu.pause, emu.unpause, emu.message = nop, nop, nop, nop

gui = { register = nop, text = nop, box = nop, line = nop, pixel = nop, drawtext = nop, drawbox = nop }

joypad = { set = nop, get = function() return {} end }

input = {}
function input.get()
	local t = {}
	for k in string.gmatch(PY.keys(), "[^,]+") do t[k] = true end
	return t
end

savestate = {}
