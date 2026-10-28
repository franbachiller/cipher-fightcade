-- CIPHER config. Nombres de teclas = los de input.get() de FBNeo
-- (insert, home, end, pageup, pagedown, delete, F1..F24, numpad0..9, A..Z, 0..9, ...)
return {
	keys = {
		toggle  = "insert",   -- activar / desactivar bot
		side    = "home",     -- cambiar jugador controlado (P1 <-> P2)
		overlay = "end",      -- mostrar / ocultar overlay
		debug   = "pageup",   -- overlay de debug (RAM en vivo)
	},
	-- Lua hotkeys de FBNeo (Input > Map Lua Hotkeys): permiten bindear a botones de joystick.
	luahotkeys = { toggle = 1, side = 2 },

	side    = 1,        -- jugador que controla el bot al arrancar (1 o 2)
	enabled = false,    -- arranca apagado
	overlay = true,
	debug   = false,
	brain   = "fundamentals",   -- games/<juego>/brains/<brain>.lua (demo | fundamentals)
	-- tuning de fundamentals
	parry_rate   = 0.95, -- prob. de intentar parry ante una amenaza (resto: bloqueo)
	parry_lead   = 3,    -- frames de anticipación del toque de parry
	block_lead   = 14,   -- frames de anticipación para empezar a bloquear
	antiair_rate = 0.9,
	poke_rate    = 0.12,
	walk_back_rate = 0.2,
	-- Salida: "auto" = keys si tools\cipher_keys.py está corriendo, si no lua.
	--   keys -> SendInput (entra antes de GGPO: ONLINE). Controla al jugador local; poné side = tu lado.
	--   lua  -> joypad.set (solo emulación local: offline / training / bot vs bot).
	output  = "auto",

	log     = true,     -- logs/cipher.log
}
