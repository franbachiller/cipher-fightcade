-- Vuelca la tabla auto-generada de cada personaje a logs\auto_chars.log (verificación offline).
local ROOT = (os.getenv("CIPHER_ROOT") or "C:\\Users\\bachi\\Desktop\\CIPHER-Fightcade") .. "\\"
package.path = ROOT .. "?.lua;" .. package.path
input_lib = require("core.input")
local auto = require("games.sfiii3.chars.auto")
local f = io.open(ROOT .. "logs\\auto_chars.log", "w")
for _, c in ipairs({ "alex", "ryu", "yun", "dudley", "necro", "hugo", "ibuki", "elena", "oro", "yang", "ken", "sean",
	"urien", "gouki", "chunli", "makoto", "q", "twelve", "remy" }) do
	local t = auto(c)
	local function names(list)
		local o = {}
		for _, m in ipairs(list) do o[#o + 1] = string.format("%s(r%s s%d)", m.name, m.range and m.range[2] or "-", m.startup or -1) end
		return table.concat(o, " ")
	end
	f:write(string.format("%-7s fireball=%-26s aa_special=%-28s carga=%s | pokes: %s\n", c,
		t.fireball and (t.fireball.name .. (t.fireball.charge and ("(" .. t.fireball.charge .. ")") or "")) or "-",
		t.antiair_special and (t.antiair_special.name .. " s" .. t.antiair_special.startup .. (t.antiair_special.charge and ("(" .. t.antiair_special.charge .. ")") or "")) or "-",
		tostring(t.charge_moves), names(t.pokes)))
end
f:close()
