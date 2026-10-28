-- Solo navega hasta una pelea de arcade (P1 Ken) y no hace nada más: para probar CIPHER Console de punta a punta.
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
local H = dofile(ROOT .. "tools\\harness.lua")
H.to_match({ p1 = os.getenv("CIPHER_P1") or "ken", sa1 = 3, arcade = true }, function()
	if emu.speedmode then emu.speedmode("normal") end
end)
