-- Capa de inputs: cola frame-exacta en coordenadas relativas (fwd/back) -> joypad.set.
-- Un "frame de input" es una tabla con flags: up, down, fwd, back, lp, mp, hp, lk, mk, hk.
local input_ = {}

local BUTTONS = {
	lp = "Weak Punch", mp = "Medium Punch", hp = "Strong Punch",
	lk = "Weak Kick",  mk = "Medium Kick",  hk = "Strong Kick",
}

local Queue = {}
Queue.__index = Queue

function input_.new()
	return setmetatable({ q = {} }, Queue)
end

function Queue:clear() self.q = {} end
function Queue:busy() return #self.q > 0 end

-- Encola frames. Cada elemento: tabla de flags, o {hold=n, ...flags} para repetir n frames.
function Queue:push(frames)
	for _, f in ipairs(frames) do
		local n = f.hold or 1
		for _ = 1, n do table.insert(self.q, f) end
	end
end

function Queue:pop()
	return table.remove(self.q, 1) or {}
end

-- Traduce un frame relativo a la tabla de joypad.set para el jugador `p`.
-- facing_right: el personaje mira a la derecha.
function input_.resolve(p, f, facing_right)
	local pre = "P" .. p .. " "
	local right = (f.fwd and facing_right) or (f.back and not facing_right)
	local left  = (f.fwd and not facing_right) or (f.back and facing_right)
	local t = {
		[pre .. "Up"]    = f.up and true or false,
		[pre .. "Down"]  = f.down and true or false,
		[pre .. "Left"]  = left and true or false,
		[pre .. "Right"] = right and true or false,
	}
	for k, name in pairs(BUTTONS) do t[pre .. name] = f[k] and true or false end
	return t
end

-- Motions estándar (lado derecho = adelante). btn: "lp".."hk" o tabla de botones.
local function withbtn(f, btn)
	if type(btn) == "table" then for _, b in ipairs(btn) do f[b] = true end
	elseif btn then f[btn] = true end
	return f
end

input_.motion = {
	qcf = function(btn) return { {down=true}, {down=true, fwd=true}, withbtn({fwd=true}, btn) } end,
	qcb = function(btn) return { {down=true}, {down=true, back=true}, withbtn({back=true}, btn) } end,
	dp  = function(btn) return { {fwd=true}, {down=true}, withbtn({down=true, fwd=true}, btn) } end,
	qcf2 = function(btn) return { {down=true}, {down=true, fwd=true}, {fwd=true},
	                              {down=true}, {down=true, fwd=true}, withbtn({fwd=true}, btn) } end,
	press = function(btn, dirs, hold)
		local f = withbtn({}, btn)
		if dirs then for k, v in pairs(dirs) do f[k] = v end end
		f.hold = hold or 2
		return { f }
	end,
	neutral = function(n) return { {hold = n or 1} } end,
}

return input_
