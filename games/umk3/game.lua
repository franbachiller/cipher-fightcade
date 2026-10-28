-- Adapter UMK3 (umk3 rev 1.2). Sensor en state.lua; mapa de RAM en la memoria del proyecto (umk3-ram-map).
local S = require("games.umk3.state")

local game = { name = "umk3", S = S }

-- el driver expone los DIP switches como teclas: cualquier joypad.set tiene que mandar sus valores originales o la
-- placa arranca en MODO TEST (ver tools/umk3_probe.lua)
game.keep_inputs = { "Dip A", "Dip B" }

function game.read_state() return S.read() end
function game.in_match() return S.read().in_match end

return game
