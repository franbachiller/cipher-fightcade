-- Backends de salida:
--   keys: máscara -> named pipe -> tools\cipher_keys.py -> SendInput. Entra ANTES de InputMake/GGPO:
--         válido online. Controla al jugador LOCAL (teclas P1 del emulador). Latencia +1 frame.
--   lua : joypad.set. Se aplica DESPUÉS de la sync GGPO (RunFrame 0x449960 -> FUN_00418570):
--         solo afecta la emulación local. Frame-exacto, offline / training / bot vs bot local.
local log = require("core.log")

local PIPE = [[\\.\pipe\cipher_input]]
local ORDER = { "Up", "Down", "Left", "Right", "Weak Punch", "Medium Punch", "Strong Punch",
                "Weak Kick", "Medium Kick", "Strong Kick" }

local output = { mode = "auto", pipe = nil, last_mask = -1, next_try = 0 }

function output.init(mode) output.mode = mode or "auto" end

local function connect(frame)
	if output.pipe or output.mode == "lua" or frame < output.next_try then return end
	output.next_try = frame + 120
	-- CIPHER externo (tools\cipher_ext.py): las líneas van directo a Python, sin pipe
	local f = CIPHER_EXT_SINK and { write = function(_, s) CIPHER_EXT_SINK(s) return true end, flush = function() return true end }
		or io.open(PIPE, "wb")
	if f then
		output.pipe, output.last_mask = f, -1
		log.write("output: pipe conectado (backend keys)")
	end
end

function output.backend()
	if output.mode == "lua" then return "lua" end
	if output.pipe then return "keys" end
	return output.mode == "keys" and "keys(sin helper)" or "lua"
end

local function send_mask(mask)
	if not output.pipe or mask == output.last_mask then return end
	local ok = output.pipe:write(mask .. "\n") and output.pipe:flush()
	if not ok then
		log.write("output: pipe caído, vuelvo a lua")
		pcall(io.close, output.pipe)
		output.pipe = nil
		return
	end
	output.last_mask = mask
end

function output.tick(frame) connect(frame) end

-- t: tabla joypad.set ya resuelta para el jugador p ("P1 Up" = true/false ...)
function output.apply(p, t)
	local b = output.backend()
	if b == "keys" then
		local pre, mask = "P" .. p .. " ", 0
		for i, name in ipairs(ORDER) do
			if t[pre .. name] then mask = mask + 2 ^ (i - 1) end
		end
		send_mask(mask)
	elseif b == "lua" then
		joypad.set(t)
	end
end

-- Estado para CIPHER Console: línea "#k=v|k=v" (solo si cambió)
function output.status(line)
	if not output.pipe or line == output.last_status then return end
	output.last_status = line
	if not (output.pipe:write("#" .. line .. "\n") and output.pipe:flush()) then
		pcall(io.close, output.pipe)
		output.pipe = nil
	end
end

-- Máscara directa (sondeo de lado): bit 2 = izquierda, bit 3 = derecha
function output.raw(mask) send_mask(mask) end

-- Suelta todo (bot OFF / fuera de pelea): las teclas físicas del jugador vuelven a mandar.
function output.release()
	if output.pipe then send_mask(0) end
end

return output
