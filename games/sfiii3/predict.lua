-- Predicción de amenazas: ¿en cuántos frames me pega el rival y a qué altura?
-- Cuerpo a cuerpo: cajas de ataque de la frame data (frames futuros de su animación) vs mis cajas vulnerables.
-- Proyectiles: cajas de ataque en vivo extrapoladas con su velocidad.
-- Sin frame data: cajas de ataque en vivo (k = 0).
local S = require("games.sfiii3.state")
local FD = require("games.sfiii3.framedata")

local P = { horizon = 24, dilate = 6 }

local function dir(flip) return flip == 1 and 1 or -1 end

-- mis cajas vulnerables en mundo, dilatadas
local function hurt_rects(me, dx)
	local out = {}
	for _, kind in ipairs({ "vuln", "ext_vuln" }) do
		for _, bx in ipairs(me.boxes[kind]) do
			local l, r, b, t = S.world_box(me.x + (dx or 0), me.y, me.flip, bx)
			out[#out + 1] = { l - P.dilate, r + P.dilate, b - P.dilate, t + P.dilate }
		end
	end
	if #out == 0 then -- fallback: cuerpo genérico
		out[1] = { me.x - 30, me.x + 30, me.y, me.y + 90 }
	end
	return out
end

local function overlaps(l, r, b, t, rects)
	for _, h in ipairs(rects) do
		if l < h[2] and r > h[1] and b < h[4] and t > h[3] then return true end
	end
	return false
end

local function classify(op, a, hit_index)
	local known = a and a.ht and #a.ht > 0
	local ht = known and (a.ht[hit_index] or a.ht[#a.ht]) or 1
	return {
		low = ht == 2,
		-- con hit_type conocido (effie meta) manda el dato: los saltos son 4 (overhead), pero los especiales aéreos como
		-- el tatsumaki de Gouki son 3 (mid) y se bloquean agachado. Antes "en el aire = parado": el bot se paraba
		-- desde agachado para bloquear el tatsu y le pegaban en la transición (11 golpes en 2 peleas)
		overhead = ht == 4 or (not known and op.airborne),
		air = op.airborne,
	}
end

-- amenaza cuerpo a cuerpo del rival `op` sobre `me`
function P.melee(me, op)
	local rects = hurt_rects(me)
	-- en vivo (cubre animaciones sin frame data)
	for _, bx in ipairs(op.boxes.attack) do
		local l, r, b, t = S.world_box(op.x, op.y, op.flip, bx)
		if overlaps(l, r, b, t, rects) then
			local c = classify(op, op.fd, 1)
			c.frames, c.kind, c.move = 0, "melee", op.move
			return c
		end
	end
	local a = op.fd
	if not (a and a.hit) then return nil end
	local f0 = op.anim_frame
	local shift = op.freeze      -- en hitstop la animación no avanza
	local ox = op.x
	-- en el aire: trayectoria balística real (velocidad + aceleración de la RAM, integradas frame a frame)
	local air = op.airborne
	local px, py, pvx, pvy = op.x, op.y, op.vx * dir(op.flip), op.vy
	local pax, pay = (op.ax or 0) * dir(op.flip), (op.ay or 0)
	for k = 1, P.horizon do
		local f = f0 + k
		if f >= a.len then break end
		if a.mx and a.mx[f] then ox = ox + a.mx[f] * dir(op.flip) end
		if air then
			px, py = px + pvx, py + pvy
			pvx, pvy = pvx + pax, pvy + pay
			if py < 0 then py = 0 end
		end
		local bxs = FD.attack_boxes(a, f)
		if bxs then
			local x = air and px or (a.vel and (op.x + op.vx * dir(op.flip) * k) or ox)
			local y = air and py or (op.y + (a.vel and op.vy * k or 0))
			if y < 0 then y = 0 end
			for _, bx in ipairs(bxs) do
				local l, r, b, t = S.world_box(x, y, op.flip, bx)
				if overlaps(l, r, b, t, rects) then
					local hi = 1
					for i, rg in ipairs(a.hit) do if f >= rg[1] and f <= rg[2] then hi = i break end end
					local c = classify(op, a, hi)
					c.frames, c.kind, c.move = k + shift, "melee", a.n
					return c
				end
			end
		end
	end
	return nil
end

-- amenaza de proyectiles enemigos
function P.projectile(me, s)
	local rects = hurt_rects(me)
	local best
	for _, pr in ipairs(s.proj) do
		if pr.emitter ~= me.id and #pr.boxes.attack > 0 then
			-- trayectoria con velocidad horizontal Y vertical: las bolas aéreas (Zanku de Gouki, Kunai de Ibuki,
			-- bolas en ángulo de Oro) bajan en diagonal; solo con vx el bot no las veía hasta que le pegaban
			local vx = pr.vx * dir(pr.flip)
			local vy = pr.vy or 0
			-- velocidad MEDIDA (posición frame a frame) y aceleración: las bolas de Remy cambian de velocidad y con la vx de
			-- la RAM la llegada se calculaba tarde (bloqueo y parry tarde: 0 parries y varias bolas recibidas "bloqueando")
			local ax = 0
			if pr.cipher_f ~= s.frame then
				if pr.cipher_x1 and pr.cipher_f == s.frame - 1 then
					local v1 = pr.x - pr.cipher_x1
					pr.cipher_ax = pr.cipher_v1 and (v1 - pr.cipher_v1) or 0
					pr.cipher_v1 = v1
				end
				pr.cipher_x1, pr.cipher_f = pr.x, s.frame
			end
			if pr.cipher_v1 and math.abs(pr.cipher_v1) > 0.5 then
				vx = pr.cipher_v1
				ax = math.max(-1, math.min(1, pr.cipher_ax or 0))
			end
			for k = 0, P.horizon do
				local x = pr.x + vx * k + 0.5 * ax * k * k
				local y = pr.y + vy * k
				local hit, top = false, 0
				for _, bx in ipairs(pr.boxes.attack) do
					local l, r, b, t = S.world_box(x, y, pr.flip, bx)
					if overlaps(l, r, b, t, rects) then hit = true top = math.max(top, t - me.y) end
				end
				if hit then
					if not best or k < best.frames then
						-- bola BAJA (Light of Virtue K de Remy: va al ras del piso): se bloquea agachado y se parrea abajo.
						-- Antes toda bola era "alta": el bot la parreaba alto y se la comía
						best = { frames = k, kind = "proj", low = top < 40, overhead = false, air = false, move = "proj_" .. pr.type }
					end
					break
				end
			end
		end
	end
	return best
end

-- agarre de comando (animación con caja de agarre que no es el agarre normal): frames hasta la caja de agarre
function P.command_grab(op)
	local a = op.fd
	if not (a and a.thr) or not op.move or op.move:find("^throw") then return nil end
	local first
	for f in pairs(a.thr) do
		if f >= op.anim_frame and (not first or f < first) then first = f end
	end
	if not first then return nil end
	return first - op.anim_frame + op.freeze
end

-- amenaza más próxima
function P.threat(s, me, op)
	local m, p = P.melee(me, op), P.projectile(me, s)
	if m and p then return (m.frames <= p.frames) and m or p end
	return m or p
end

-- frames hasta que el rival pueda actuar (si está en una animación de ataque con frame data)
function P.recovery_left(op)
	local a = op.fd
	if not (a and a.hit) then return nil end
	local last = a.hit[#a.hit][2]
	if op.anim_frame <= last then return nil end      -- todavía puede pegar
	return FD.recovery_end(a) - op.anim_frame + op.freeze
end

return P
