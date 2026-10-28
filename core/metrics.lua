-- Métricas de pelea por lado: golpes recibidos, bloqueos, parries, daño, anti-airs, techs.
local FD = require("games.sfiii3.framedata")
local log = require("core.log")

local M = { t = { {}, {} }, rounds = 0 }

local function zero() return { hits_taken = 0, blocks = 0, parries = 0, dmg_taken = 0, dmg_dealt = 0,
	aa_hits = 0, teched = 0, thrown = 0, rounds_won = 0 } end

function M.reset() M.t = { zero(), zero() } M.prev = {} M.rounds = 0 end
M.reset()

local function is_parry_anim(pl)
	local c = FD.char(pl.char_str)
	if not c then return false end
	local st = c.states
	return pl.anim == st.parry_high or pl.anim == st.parry_low or pl.anim == st.parry_air
end

local function dead(hp) return hp == 0 or hp == 255 end

-- fin de round: por KO (vida 0/255) o por salir de la pelea (time over). El último round contra Gill
-- pasa directo al final sin la transición de match_state, por eso el KO es la señal principal.
local function close_round(s, hp1, hp2)
	M.round_open = false
	M.rounds = M.rounds + 1
	if not dead(hp1) and (dead(hp2) or hp1 > hp2) then M.t[1].rounds_won = M.t[1].rounds_won + 1
	elseif not dead(hp2) and (dead(hp1) or hp2 > hp1) then M.t[2].rounds_won = M.t[2].rounds_won + 1 end
	log.write("ROUND %d end P1=%s(hp %d) P2=%s(hp %d) | %s | meter P1=%d/%d P2=%d/%d", M.rounds, s.p[1].char_str, hp1,
		s.p[2].char_str, hp2, M.summary(), s.p[1].meter or 0, s.p[1].gauge or 0, s.p[2].meter or 0, s.p[2].gauge or 0)
end

function M.update(s)
	local hp1, hp2 = s.p[1].hp, s.p[2].hp
	if M.round_open and (dead(hp1) or dead(hp2)) then
		close_round(s, hp1, hp2)
	end
	if not s.in_match then
		if M.round_open then close_round(s, M.last_hp and M.last_hp[1] or hp1, M.last_hp and M.last_hp[2] or hp2) end
		M.was_in_match = false
		M.prev = {}
		return
	end
	if not M.round_open and not dead(hp1) and not dead(hp2) and hp1 == 160 and hp2 == 160 then M.round_open = true end
	M.was_in_match = true
	M.last_chars = { s.p[1].char_str, s.p[2].char_str }
	M.last_hp = { s.p[1].hp, s.p[2].hp }
	for i = 1, 2 do
		local me, op, t, pv = s.p[i], s.p[3 - i], M.t[i], M.prev[i] or {}
		local parry = me.has_just_parried
		if parry then t.parries = t.parries + 1 end
		if me.has_just_blocked_conn then t.blocks = t.blocks + 1 end
		if pv.hp and me.hp < pv.hp and me.hp ~= 255 then
			t.dmg_taken = t.dmg_taken + (pv.hp - me.hp)
			M.t[3 - i].dmg_dealt = M.t[3 - i].dmg_dealt + (pv.hp - me.hp)
			if not me.is_blocking then
				t.hits_taken = t.hits_taken + 1
				if me.airborne then M.t[3 - i].aa_hits = M.t[3 - i].aa_hits + 1 end
			end
		end
		if me.has_just_been_thrown then t.thrown = t.thrown + 1 end
		M.prev[i] = { hp = me.hp, parry = parry }
	end
end

function M.summary()
	local out = {}
	for i = 1, 2 do
		local t = M.t[i]
		out[#out + 1] = string.format("P%d won=%d dealt=%d taken=%d hits_taken=%d blocks=%d parries=%d aa=%d thrown=%d",
			i, t.rounds_won, t.dmg_dealt, t.dmg_taken, t.hits_taken, t.blocks, t.parries, t.aa_hits, t.thrown)
	end
	return table.concat(out, " || ")
end

return M
