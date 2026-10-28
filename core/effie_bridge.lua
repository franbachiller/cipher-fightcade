-- Puente a effie3rd/3rd_training_lua (GPL-3.0): corre SU estado de juego, SU predictor y SU control de dummy
-- (bloqueo, parry, red parry, tech de agarre, machacar stun, quick stand) con nuestro personaje como "dummy".
-- El cerebro usa estas decisiones en defensa; la ofensiva sigue siendo nuestra.
local B = { ok = false, err = nil }

local ROOT = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[\\/])core[\\/]") or ".\\"
local EFFIE = ROOT .. "third_party\\effie3rd__3rd_training_lua\\"

local gamestate, framedata, prediction, dummy_control, inputs, training, settings, loading

-- globales que la Lua de FBNeo trae y effie usa
local function fbneo_globals()
	if not copytable then
		function copytable(t)
			if type(t) ~= "table" then return t end
			local o = {}
			for k, v in pairs(t) do o[k] = copytable(v) end
			return setmetatable(o, getmetatable(t))
		end
	end
	if not bit then bit = require("bit") end
	gd = gd or setmetatable({}, { __index = function() return function() end end })
	emu.speedmode = emu.speedmode or function() end
	emu.isonline = emu.isonline or function() return false end
	emu.sourcename = emu.sourcename or function() return "sfiii3nr1" end
	emu.gamename = emu.gamename or function() return "sfiii3nr1" end
	if not memory.readwordsigned then memory.readwordsigned = memory.readword end
	input.registerhotkey = input.registerhotkey or function() end
	savestate = savestate or {}
	savestate.create = savestate.create or function() return {} end
	savestate.load = savestate.load or function() end
	savestate.save = savestate.save or function() end
end

local function load()
	fbneo_globals()
	package.path = EFFIE .. "?.lua;" .. package.path
	settings = require("src.settings")
	-- rutas de effie relativas a su carpeta
	settings.framedata_path = EFFIE .. (settings.framedata_path or "data/sfiii3nr1/framedata/")
	gamestate = require("src.gamestate")
	framedata = require("src.data.framedata")
	loading = require("src.loading")
	prediction = require("src.data.prediction")
	inputs = require("src.control.inputs")
	dummy_control = require("src.control.dummy_control")
	training = require("src.training")
	loading.load_framedata_human_readable()
	framedata.is_loaded = true
	if framedata.patch_frame_data then pcall(framedata.patch_frame_data) end
end

function B.init()
	local ok, err = pcall(load)
	B.ok, B.err = ok, (not ok) and tostring(err) or nil
	return ok, err
end

-- ---------------------------------------------------------------- ataque: modo "footsies" de effie
-- IA de neutral de effie (pokes, espaciado, castigo de whiffs, con la tabla de golpes de cada personaje).
-- La interfaz gráfica de effie se reemplaza por stubs: solo corre la lógica.
local stub
stub = setmetatable({}, { __index = function() return stub end, __call = function() return stub end })
local footsies, modes, modules, advanced_control

-- globales de 3rd_training.lua: cola de comandos por frame y callbacks de load state
local command_queue = {}
function Queue_Command(frame, command, args)
	command_queue[frame] = command_queue[frame] or {}
	table.insert(command_queue[frame], { command = command, args = args })
end
function Call_After_Load_State() end
function Register_Load_State_Callback() end
function Unregister_Load_State_Callback() end
Load_State_Caller = ""
local function run_commands(frame)
	for key, cmds in pairs(command_queue) do
		if key == frame then
			for _, c in ipairs(cmds) do
				if c.args then c.command(unpack(c.args)) else c.command() end
			end
			command_queue[key] = nil
		elseif key < frame then
			command_queue[key] = nil
		end
	end
end

function B.want_footsies(side) B.footsies_wanted = side end

function B.init_footsies(side)
	if not B.ok then return false end
	local ok, err = xpcall(function()
		for _, m in ipairs({ "src.ui.hud", "src.ui.draw", "src.ui.colors", "src.ui.menu", "src.ui.menu_items",
			"src.ui.image_tables", "src.ui.input_history", "src.ui.themes" }) do
			package.loaded[m] = package.loaded[m] or stub
		end
		if settings.load_training_data then settings.load_training_data() end
		modules = require("src.modules")
		modes = require("src.modes")
		advanced_control = require("src.control.advanced_control")
		modules.init()
		modules.load_all_modules()
		if modes.init then modes.init() end
		training.init()
		footsies = modules.get_module("footsies")
		-- en effie los golpes de footsies se eligen en el menú: habilitarlos todos, con caminata hacia atrás
		local fs = settings.modules.footsies
		if fs and fs.characters then
			for _, cs in pairs(fs.characters) do
				if type(cs.moves) == "table" then for i in pairs(cs.moves) do cs.moves[i] = true end end
				cs.walk_out = true
			end
		end
		training.set_controllers_by_name(side == 1 and "footsies" or "player", side == 1 and "player" or "footsies")
		B.footsies_side = side
		B.footsies_started = false
	end, debug.traceback)
	B.footsies_ok = ok
	if not ok then B.err = "footsies: " .. tostring(err) end
	return ok
end

function B.debug_footsies()
	if not B.footsies_ok then return "footsies_ok=" .. tostring(B.footsies_ok) .. " err=" .. tostring(B.err) end
	local ft = require("src.training.footsies.footsies_tables")
	local nact, ntot = 0, 0
	for _, m in ipairs(ft.get_moves() or {}) do ntot = ntot + 1 if m.active then nact = nact + 1 end end
	return string.format("active=%s playable=%s moves=%d/%d dummy=%s started=%s", tostring(footsies.is_mode_active),
		tostring(gamestate.is_in_match_playable), nact, ntot, tostring(footsies.dummy and footsies.dummy.char_str),
		tostring(B.footsies_started))
end

local function footsies_frame(input)
	if not B.footsies_ok then return end
	run_commands(gamestate.frame_number)
	if not B.footsies_started then
		if modes.start then modes.start(footsies) else footsies.start() end
		B.footsies_started = true
	end
	footsies.update()
	advanced_control.update()
end

local opts = {}
local NAMES = { "Up", "Down", "Left", "Right", "Weak Punch", "Medium Punch", "Strong Punch", "Weak Kick", "Medium Kick", "Strong Kick" }

-- corre un frame de effie con `side` como dummy. Devuelve la tabla joypad del dummy si effie quiere actuar (o nil)
function B.frame(side)
	if not B.ok then return nil end
	local ok, res = pcall(function()
		gamestate.gamestate_read()
		if not gamestate.is_in_match then return nil end
		local dummy = gamestate.player_objects[side]
		training.dummy = dummy
		training.player = gamestate.player_objects[3 - side]
		local input = {}
		local pre = "P" .. side .. " "
		for _, n in ipairs(NAMES) do input[pre .. n] = false end
		inputs.input = input
		inputs.update_input(input, gamestate.player_objects)
		prediction.update_before(B.prev or {}, dummy)
		inputs.previous_input = B.prev or {}
		opts.mode = 2                -- Blocking_Mode.ON (1 = OFF)
		-- offline: parry (effie decide parry / bloqueo con la validez real del parry en RAM).
	-- online (runtime externo): SOLO bloqueo. Con rollback el golpe del rival aparece tarde en la RAM local y el parry
	-- de reacción sale a destiempo: Q vs Oro = 35 parries pero 67 golpes recibidos y 8 bloqueos, con el stick
	-- yendo adelante/atrás (se veía como un bot roto)
	opts.style = CIPHER_EXT and 1 or 2
		opts.red_parry_hit_count = 1
		opts.parry_every_n_count = 1
		opts.prefer_parry_low = false
		opts.prefer_block_low = false
		opts.force_blocking_direction = 1
		if B.footsies_wanted and B.footsies_ok == nil then B.init_footsies(B.footsies_wanted) end
		if B.footsies_ok then footsies_frame(input) end
		dummy_control.update_blocking(input, dummy, opts)
		dummy_control.update_mash_inputs(input, dummy, 4)
		dummy_control.update_tech_throws(input, dummy, 2)
		dummy_control.update_fast_wake_up(input, dummy, 2)
		local any = false
		for _, n in ipairs(NAMES) do if input[pre .. n] then any = true end end
		return any and input or nil
	end)
	if not ok then
		B.err = tostring(res)
		return nil
	end
	return res
end

-- después de decidir el frame: lo que REALMENTE mandó el bot (effie lo usa como input previo y para predecir
-- la animación propia del frame siguiente; antes recibía su propio input y no veía la guardia/neutral reales)
function B.post(side, final)
	if not B.ok then return end
	B.prev = final or {}
	pcall(function() prediction.update_after(B.prev, training.dummy) end)
end

return B
