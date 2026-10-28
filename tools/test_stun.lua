-- Test offline: barra de stun de P2 casi llena siempre -> el primer golpe lo marea; ver si P1 (bot) castiga.
-- Env como eval.lua (CIPHER_P1/P2, CIPHER_SIDE=1, CIPHER_SPAR=sparring, CIPHER_OUTPUT=lua).
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
local H = dofile(ROOT .. "tools\\harness.lua")
local P2_STUN_MAX = 0x0206960B
H.to_match({ p1 = os.getenv("CIPHER_P1") or "ken", p2 = os.getenv("CIPHER_P2") or "ryu", sa1 = 3, sa2 = 1 }, function()
	dofile(ROOT .. "cipher.lua")
	emu.registerafter(function()
		local mx = memory.readbyte(P2_STUN_MAX)
		if memory.readbyte(P2_STUN_MAX - 3) == 0 and mx > 2 and memory.readbyte(P2_STUN_MAX + 6) < mx - 1 then
			memory.writebyte(P2_STUN_MAX + 6, mx - 1)
		end
	end)
end)
