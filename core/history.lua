-- Historial de peleas (al mejor de 3 rounds) desde el punto de vista del bot: logs\online\historial.csv
-- Se alimenta de core\metrics (contadores acumulados por lado) y nunca se pisa (append).
local log = require("core.log")

local H = { path = nil, cur = nil, seen_rounds = nil, snap = nil }

local HEADER = "fecha,lado,cipher,sa,rival,rounds_cipher,rounds_rival,resultado,dano_hecho,dano_recibido,parries,golpes_recibidos,input_delay\n"

function H.init(root)
	os.execute('mkdir "' .. root .. 'logs\\online" 2>nul')
	H.path = root .. "logs\\online\\historial.csv"
	local f = io.open(H.path, "r")
	if f then f:close() return end
	f = io.open(H.path, "w")
	if f then f:write(HEADER) f:close() end
end

local function snapshot(metrics)
	local t = {}
	for i = 1, 2 do
		local x = metrics.t[i]
		t[i] = { won = x.rounds_won, dealt = x.dmg_dealt, taken = x.dmg_taken, parries = x.parries, hits = x.hits_taken }
	end
	return t
end

local function write_row(m, delay)
	if not H.path then return end
	local f = io.open(H.path, "a")
	if not f then return end
	f:write(string.format("%s,P%d,%s,%s,%s,%d,%d,%s,%d,%d,%d,%d,%s\n", os.date("%Y-%m-%d %H:%M"), m.side, m.me, m.sa, m.op,
		m.w, m.l, (m.w > m.l) and "GANÓ" or "PERDIÓ", m.dealt, m.taken, m.parries, m.hits, tostring(delay or "?")))
	f:close()
end

-- llamar cada frame después de metrics.update. side = lado del bot; sa_name = texto del SA usado
function H.update(s, metrics, side, sa_name, delay)
	if H.seen_rounds == nil or metrics.rounds < H.seen_rounds then   -- arranque o metrics.reset
		H.seen_rounds, H.snap = metrics.rounds, snapshot(metrics)
		return
	end
	if metrics.rounds == H.seen_rounds then return end
	H.seen_rounds = metrics.rounds
	local now, before = snapshot(metrics), H.snap
	H.snap = now
	local me, op = s.p[side], s.p[3 - side]
	local m = H.cur
	if not m or m.me ~= me.char_str or m.op ~= op.char_str or m.side ~= side then
		m = { side = side, me = me.char_str, op = op.char_str, sa = sa_name or "?", w = 0, l = 0,
			dealt = 0, taken = 0, parries = 0, hits = 0 }
		H.cur = m
	end
	local a, b = now[side], before[side]
	if a.won > b.won then m.w = m.w + 1 end
	if now[3 - side].won > before[3 - side].won then m.l = m.l + 1 end
	m.dealt, m.taken = m.dealt + a.dealt - b.dealt, m.taken + a.taken - b.taken
	m.parries, m.hits = m.parries + a.parries - b.parries, m.hits + a.hits - b.hits
	if m.w >= 2 or m.l >= 2 then
		write_row(m, delay)
		log.write("PELEA %s: %s (%s) vs %s  %d-%d", (m.w > m.l) and "GANADA" or "PERDIDA", m.me, m.sa, m.op, m.w, m.l)
		H.cur = nil
		return m
	end
end

return H
