-- Adapter SF3 3rd Strike (sfiii3 / sfiii3nr1). Sensor completo en state.lua, mapa en data\sfiii3\ram-map.md.
local S = require("games.sfiii3.state")

local game = { name = "sfiii3", S = S }

-- Input que el juego leyó este frame (word, mismos bits que output: up down left right LP MP HP LK MK HK).
-- Hallado con tools\re_inputram.py; +2 = frame anterior. Sirve para saber qué jugador maneja nuestro teclado.
game.input_addr = { 0x0206AA8C, 0x0206AA90 }
game.sa_select = require("games.sfiii3.sa_select")   -- SA por personaje: elegir solo + recordar
function game.read_input(p) return memory.readword(game.input_addr[p]) % 1024 end

function game.read_state() return S.read() end
function game.in_match() return S.read().in_match end

return game
