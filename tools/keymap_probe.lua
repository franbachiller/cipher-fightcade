-- Escribe en cada frame los botones P1 presionados (lectura post-input) a CIPHER_PROBE_OUT.
local out = os.getenv("CIPHER_PROBE_OUT")
emu.registerafter(function()
	local t = {}
	for k, v in pairs(joypad.get()) do
		if v == true and k:sub(1, 3) == "P1 " then t[#t + 1] = k end
	end
	table.sort(t)
	local f = io.open(out, "w")
	if f then f:write(table.concat(t, ",")) f:close() end
end)
