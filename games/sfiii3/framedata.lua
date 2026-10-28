-- Carga perezosa de frame data por personaje (data/sfiii3/fd/<char>.lua, generada por tools/import_framedata.py).
-- Cajas en la frame data: {bottom, height, left, width} relativas al personaje.
local FD = { cache = {}, root = nil }

local function root()
	if not FD.root then
		local src = debug.getinfo(1, "S").source:gsub("^@", "")
		FD.root = (src:match("^(.*[\\/])games[\\/]sfiii3[\\/]") or ".\\") .. "data\\sfiii3\\fd\\"
	end
	return FD.root
end

function FD.char(name)
	local c = FD.cache[name]
	if c == nil then
		local ok, t = pcall(dofile, root() .. name .. ".lua")
		c = ok and t or false
		FD.cache[name] = c
	end
	return c or nil
end

function FD.anim(char, anim)
	local c = FD.char(char)
	return c and c.anims[anim] or nil
end

function FD.state_anim(char, state)
	local c = FD.char(char)
	return c and c.states[state] or nil
end

-- cajas de ataque del frame f (0-based) como {l,w,b,h}
function FD.attack_boxes(a, f)
	local raw = a and a.atk and a.atk[f]
	if not raw then return nil end
	local out = {}
	for i, bx in ipairs(raw) do out[i] = { b = bx[1], h = bx[2], l = bx[3], w = bx[4] } end
	return out
end

-- primer frame accionable (idle) o fin de animación
function FD.recovery_end(a)
	return a.idle or a.len
end

-- índice del próximo rango activo que empieza en/tras f; devuelve start, finish, hit_index
function FD.next_hit(a, f)
	if not a or not a.hit then return nil end
	for i, r in ipairs(a.hit) do
		if r[2] >= f then return math.max(r[1], f), r[2], i end
	end
	return nil
end

return FD
