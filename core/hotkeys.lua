-- Detección de flanco sobre input.get() + Lua hotkeys nativos de FBNeo.
local hotkeys = { binds = {}, prev = {} }

-- name: tecla de input.get(); fn: callback al presionar
function hotkeys.bind(key, fn)
	if key then hotkeys.binds[key] = fn end
end

-- n: 1..9 (Input > Map Lua Hotkeys en FBNeo)
function hotkeys.bindlua(n, fn)
	if n and input.registerhotkey then input.registerhotkey(n, fn) end
end

function hotkeys.poll()
	local cur = input.get()
	for key, fn in pairs(hotkeys.binds) do
		local down = cur[key] and true or false
		if down and not hotkeys.prev[key] then fn() end
		hotkeys.prev[key] = down
	end
end

return hotkeys
