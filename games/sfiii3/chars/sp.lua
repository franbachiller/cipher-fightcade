-- Helper: secuencia de un especial/super desde la move list importada (data/sfiii3/moves/<char>.lua), por nombre y
-- botón ("LP", "MK", "EXP", ...; los supers tienen un solo variante). Devuelve una función que crea la secuencia.
local ROOT = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])games[\\/]") or ".\\"
local cache = {}

local function moves(char)
	if cache[char] == nil then
		local ok, t = pcall(dofile, ROOT .. "data\\sfiii3\\moves\\" .. char .. ".lua")
		cache[char] = ok and t or false
	end
	return cache[char]
end

local SP = {}

function SP.seq(char, name, btn)
	local ml = moves(char)
	if not ml then return nil end
	for _, m in ipairs(ml) do
		if m.name == name then
			local pick = m.variants[1]
			for _, v in ipairs(m.variants) do if v.btn == btn then pick = v end end
			return function()
				local out = {}
				for i, fr in ipairs(pick.seq) do local f = {} for k, x in pairs(fr) do f[k] = x end out[i] = f end
				out[#out + 1] = { hold = 2 }
				return out
			end, pick.charge
		end
	end
	return nil
end

-- personal action (taunt): HP+HK
function SP.taunt() return function() return { { hp = true, hk = true, hold = 2 }, { hold = 40 } } end end

-- entrada: definición compacta -> entrada de ch.specials
function SP.make(char, name, btn, role, extra)
	local seq, charge = SP.seq(char, name, btn)
	if not seq then return nil end
	local e = { name = name .. (btn ~= "" and ("_" .. tostring(btn)) or ""), role = role, seq = seq, charge = charge }
	for k, v in pairs(extra or {}) do e[k] = v end
	return e
end

-- lista sin nils
function SP.list(...)
	local out = {}
	for i = 1, select("#", ...) do
		local e = select(i, ...)
		if e then out[#out + 1] = e end
	end
	return out
end

return SP
