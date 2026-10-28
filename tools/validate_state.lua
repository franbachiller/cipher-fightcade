-- Valida games/sfiii3/state.lua contra la frame data: P2 (Ken) ejecuta golpes conocidos, se loguea por frame.
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
package.path = ROOT .. "?.lua;" .. package.path
local H = dofile(ROOT .. "tools\\harness.lua")
local S = require("games.sfiii3.state")
local FD = require("games.sfiii3.framedata")
local f = io.open(ROOT .. "logs\\validate_state.log", "w")
local function L(...) f:write(string.format(...) .. "\n") f:flush() end

-- secuencia para P2 (Ken mira a la izquierda al inicio: adelante = Left)
local SEQ = {
	{ 40, {} },
	{ 3, { ["P2 Down"] = true, ["P2 Strong Punch"] = true } }, { 45, {} },          -- cr.HP
	{ 3, { ["P2 Medium Kick"] = true } }, { 40, {} },                                -- st.MK
	{ 1, { ["P2 Down"] = true } }, { 1, { ["P2 Down"] = true, ["P2 Left"] = true } },
	{ 2, { ["P2 Left"] = true, ["P2 Weak Punch"] = true } }, { 70, {} },             -- hadouken LP
	{ 1, { ["P2 Left"] = true } }, { 1, { ["P2 Down"] = true } },
	{ 2, { ["P2 Down"] = true, ["P2 Left"] = true, ["P2 Medium Punch"] = true } }, { 80, {} }, -- shoryuken MP
	{ 3, { ["P2 Down"] = true, ["P2 Weak Kick"] = true } }, { 40, {} },              -- cr.LK
}

local stats = { frames = 0, with_fd = 0, synced = 0, atk_live = 0, atk_live_in_hit = 0, moves = {} }

H.to_match({ p1 = "ryu", p2 = "ken", sa1 = 1, sa2 = 3 }, function()
	L("in match")
	local step, left, t0 = 1, SEQ[1][1], emu.framecount()
	emu.registerbefore(function()
		local s = S.read()
		local p = s.p[2]
		-- salida de la secuencia
		if step <= #SEQ then
			joypad.set(SEQ[step][2])
			left = left - 1
			if left <= 0 then step = step + 1 left = SEQ[step] and SEQ[step][1] or 0 end
		elseif step == #SEQ + 1 then
			step = step + 1
			L("SUMMARY frames=%d with_fd=%d synced=%d (%.0f%%) live_atk=%d live_atk_in_fd_hit=%d (%.0f%%)",
				stats.frames, stats.with_fd, stats.synced, 100 * stats.synced / math.max(1, stats.with_fd),
				stats.atk_live, stats.atk_live_in_hit, 100 * stats.atk_live_in_hit / math.max(1, stats.atk_live))
			for m, n in pairs(stats.moves) do L("  move %-14s frames=%d", m, n) end
			L("P1 char=%s P2 char=%s proj_seen=%d", s.p[1].char_str, s.p[2].char_str, stats.proj or 0)
		end
		-- métricas
		stats.frames = stats.frames + 1
		if p.fd then
			stats.with_fd = stats.with_fd + 1
			if p.anim_synced then stats.synced = stats.synced + 1 end
			if p.fd.hit then stats.moves[p.move] = (stats.moves[p.move] or 0) + 1 end
		end
		if #p.boxes.attack > 0 then
			stats.atk_live = stats.atk_live + 1
			if p.fd and p.fd.hit then
				for _, r in ipairs(p.fd.hit) do
					if p.anim_frame >= r[1] and p.anim_frame <= r[2] then stats.atk_live_in_hit = stats.atk_live_in_hit + 1 break end
				end
			end
		end
		if #s.proj > 0 then stats.proj = (stats.proj or 0) + 1 end
		if p.fd and p.fd.hit or #p.boxes.attack > 0 or #s.proj > 0 then
			local fdb = FD.attack_boxes(p.fd, p.anim_frame)
			L("f=%d P2 anim=%s move=%s af=%d sync=%s fz=%d att=%s live_atk=%d fd_atk=%d post=%02x proj=%d%s",
				s.frame - t0, p.anim, tostring(p.move), p.anim_frame, tostring(p.anim_synced), p.freeze,
				tostring(p.attacking), #p.boxes.attack, fdb and #fdb or 0, p.posture, #s.proj,
				#s.proj > 0 and string.format(" [type=%s x=%.0f vx=%.2f emit=%d atk=%d]", s.proj[1].type, s.proj[1].x,
					s.proj[1].vx, s.proj[1].emitter, #s.proj[1].boxes.attack) or "")
		end
	end)
end)
