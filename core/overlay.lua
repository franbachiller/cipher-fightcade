local overlay = {}

local C_ON, C_OFF, C_TXT, C_BG = 0x00FF00FF, 0xFF3030FF, 0xFFFFFFFF, 0x000000C0

function overlay.draw(app)
	if not app.cfg.overlay then return end
	local w = emu.screenwidth()
	local status = app.cfg.enabled and "ON" or "OFF"
	local line = string.format("CIPHER %s  P%d  [%s] %s", status, app.cfg.side, app.cfg.brain, app.output.backend())
	local x = math.floor(w / 2 - #line * 2)
	gui.box(x - 2, 1, x + #line * 4 + 1, 9, C_BG, C_BG)
	gui.text(x, 2, line, app.cfg.enabled and C_ON or C_OFF)
	if app.cfg.enabled and app.bot and app.bot.brain.label then
		local lb = app.bot.brain.label(app.bot)
		gui.text(math.floor(w / 2 - #lb * 2), 11, lb, C_TXT)
	end

	if app.cfg.debug and app.state then
		local s = app.state
		local y = 30
		gui.text(4, y, string.format("match=%s frame=%d timer=%d", tostring(s.in_match), s.frame, s.timer), C_TXT) y = y + 8
		for p = 1, 2 do
			local pl = s.p[p]
			gui.text(4, y, string.format("P%d char=%2d hp=%3d x=%4d y=%4d facingR=%s",
				p, pl.char, pl.hp, pl.x, pl.y, tostring(pl.facing_right)), C_TXT)
			y = y + 8
		end
		gui.text(4, y, string.format("dist=%d", s.dist), C_TXT)
	end
end

return overlay
