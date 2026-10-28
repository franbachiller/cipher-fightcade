-- Sparring aleatorio (solo pruebas offline): pokes, barridos, jump-ins, fireballs, agarres y caminata.
local M = input_lib.motion
local B = {}

function B.reset(ctx) ctx.mem = { label = "spar", cd = 0 } end

local NEUTRAL = { [0x00] = true, [0x02] = true, [0x06] = true, [0x08] = true, [0x20] = true, [0x21] = true }

function B.think(ctx, s, me, op)
	local mem = ctx.mem
	if ctx.queue:busy() then return nil end
	if not NEUTRAL[me.posture] or me.attacking or me.freeze > 0 then return nil end
	if mem.cd > 0 then mem.cd = mem.cd - 1 return nil end
	local d, r = s.dist, math.random()
	local function go(frames, label, cd) ctx.queue:push(frames) mem.label = label mem.cd = cd or 6 end
	if d > 170 then
		if r < 0.25 then go(M.qcf("lp"), "hadouken", 30)
		elseif r < 0.45 then go({ { up = true, fwd = true, hold = 3 }, { hold = 20 }, { hk = true, hold = 2 } }, "jump-in HK", 40)
		else go({ { fwd = true, hold = 12 } }, "walk in") end
	elseif d > 80 then
		if r < 0.30 then go(M.press("mk", { down = true }, 2), "cr.MK", 14)
		elseif r < 0.42 then go(M.press("hk", { down = true }, 2), "sweep", 30)
		elseif r < 0.55 then go({ { up = true, fwd = true, hold = 3 }, { hold = 18 }, { hk = true, hold = 2 } }, "jump-in HK", 40)
		elseif r < 0.62 then go(M.press("hp", nil, 2), "st.HP", 30)
		elseif r < 0.80 then go({ { fwd = true, hold = 8 } }, "walk in")
		else go({ { back = true, hold = 8 } }, "walk back") end
	else
		if r < 0.25 then go(M.press({ "lp", "lk" }, { fwd = true }, 2), "throw", 20)
		elseif r < 0.50 then go(M.press("lk", { down = true }, 2), "cr.LK", 10)
		elseif r < 0.65 then go(M.press("mp", nil, 2), "st.MP", 14)
		elseif r < 0.75 then go(M.dp("hp"), "shoryuken", 40)
		else go({ { back = true, hold = 10 } }, "walk back") end
	end
	return nil
end

function B.label(ctx) return ctx.mem.label end

return B
