-- Alcances EXACTOS (px entre centros = s.dist) por atacante / golpe / defensor / postura, calculados con las cajas
-- de la frame data (tools\compute_ranges.py -> data\sfiii3\ranges.lua). Verificado en emulador: agarre de Ken vs
-- Ryu conecta hasta 72-74 (calculado 74). Antes el bot agarraba a < 50 y Hugo a < 56 (Moonsault llega a ~114).
local ROOT = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])games[\\/]") or ".\\"
local ok, DATA = pcall(dofile, ROOT .. "data\\sfiii3\\ranges.lua")
if not ok or type(DATA) ~= "table" then DATA = {} end

local R = {}

-- nombres de las tablas a mano ("cr.MK", "st.MK", "cl.HP") -> nombres de animación de la frame data
local function anim_name(name)
	if not name then return nil end
	return (name:gsub("^cr%.", "d_"):gsub("^st%.", ""):gsub("^cl%.", "cl_"):gsub("^far%.", ""))
end

-- alcance máximo del golpe contra ese defensor (nil si no hay dato)
function R.reach(att, move, def, crouching)
	local a = DATA[att]
	local m = a and (a[move] or a[anim_name(move)])
	if not m then return nil end
	local t = crouching and m.cr or m.st
	return t and (t[def] or (crouching and m.st[def])) or nil
end

-- agarre normal: el más largo de neutral / adelante / atrás
function R.throw(att, def, crouching)
	local best
	for _, n in ipairs({ "throw_neutral", "throw_forward", "throw_back" }) do
		local r = R.reach(att, n, def, crouching)
		if r and (not best or r > best) then best = r end
	end
	return best
end

-- primer agarre de comando que encuentre por prefijo de nombre (ej. "moonsault_press")
function R.prefix(att, prefix, def, crouching)
	local a = DATA[att]
	if not a then return nil end
	local best
	for name, m in pairs(a) do
		if name:sub(1, #prefix) == prefix and not name:find("_ext") then   -- _ext = remate posterior, no el agarre
			local t = crouching and m.cr or m.st
			local r = t and t[def]
			if r and (not best or r > best) then best = r end
		end
	end
	return best
end

return R
