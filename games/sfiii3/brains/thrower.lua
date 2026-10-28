-- Sparring de laboratorio: solo agarra. Camina, agarra (normal) al estar cerca, agarra en el wakeup del rival
-- y después de que le bloqueen un golpe. Para medir el tech y el anti-agarre del bot.
local M = input_lib.motion
local B = {}

function B.reset(ctx) ctx.mem = { label = "thrower", cd = 0 } end

local NEUTRAL = { [0x00] = true, [0x02] = true, [0x06] = true, [0x08] = true, [0x20] = true, [0x21] = true }

function B.think(ctx, s, me, op)
	local mem = ctx.mem
	if ctx.queue:busy() then return nil end
	if not NEUTRAL[me.posture] or me.attacking or me.freeze > 0 then return nil end
	if mem.cd > 0 then mem.cd = mem.cd - 1 return nil end
	local d = s.dist
	local function go(frames, label, cd) ctx.queue:push(frames) mem.label = label mem.cd = cd or 6 end
	if op.knocked_down then
		if d > 40 then return { fwd = true } end
		return nil                                      -- esperar al lado y agarrar apenas se pare
	end
	if d < 48 then
		if math.random() < 0.7 then go(M.press({ "lp", "lk" }, { fwd = true }, 2), "throw", 20)
		else go(M.press("lp", { down = true }, 2), "cr.LP", 6) end    -- a veces un jab para que bloquee y después agarrar
		return nil
	end
	if d < 110 and math.random() < 0.15 then                          -- dash para entrar al rango de agarre
		go({ { fwd = true, hold = 2 }, { hold = 2 }, { fwd = true, hold = 2 } }, "dash", 4)
		return nil
	end
	return { fwd = true }
end

function B.label(ctx) return ctx.mem.label end

return B
