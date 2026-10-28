-- Brain F0: footsies básicos por distancia (referencia mínima).
local M = input_lib.motion

local brain = {}

function brain.reset(ctx) ctx.cooldown = 0 end
function brain.label() return "demo" end

function brain.think(ctx, s, me, op)
	if ctx.queue:busy() then return end
	if ctx.cooldown > 0 then ctx.cooldown = ctx.cooldown - 1 return end
	local d = s.dist
	if op.y > 20 and d < 110 then
		ctx.queue:push(M.dp("hp")) ctx.cooldown = 30
	elseif d > 160 then
		if me.char == 2 or me.char == 11 or me.char == 14 then ctx.queue:push(M.qcf("mp")) ctx.cooldown = 40
		else ctx.queue:push({ { fwd = true, hold = 8 } }) end
	elseif d > 90 then
		ctx.queue:push({ { fwd = true, hold = 6 } })
		ctx.queue:push(M.press("mk", { down = true }, 3))
		ctx.cooldown = 12
	else
		ctx.queue:push(M.press("lk", { down = true }, 2))
		ctx.cooldown = 10
	end
end

return brain
