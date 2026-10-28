-- Evaluación offline: fuerza personajes, llega a la pelea y carga cipher.lua con bot + sparring.
-- Env: CIPHER_ROOT, CIPHER_P1/CIPHER_P2 (personajes), CIPHER_SA1/CIPHER_SA2, CIPHER_TURBO=1
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
local H = dofile(ROOT .. "tools\\harness.lua")
H.to_match({
	p1 = os.getenv("CIPHER_P1") or "ryu", p2 = os.getenv("CIPHER_P2") or "ken",
	sa1 = tonumber(os.getenv("CIPHER_SA1") or "1"), sa2 = tonumber(os.getenv("CIPHER_SA2") or "3"),
	arcade = os.getenv("CIPHER_ARCADE") == "1",
}, function()
	dofile(ROOT .. "cipher.lua")
	if os.getenv("CIPHER_TURBO") == "1" and emu.speedmode then emu.speedmode("turbo") end
end)
