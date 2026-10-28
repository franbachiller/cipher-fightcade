"""Health check estático del brain (sin emulador): compila todo, busca globales no definidas y locales usadas antes de
declararse, carga las tablas de los 19 personajes y valida cada secuencia de input, carga los combos.
  python -I tools\\brain_health.py          (código de salida 1 si hay fallas)"""
import glob
import os
import re
import sys

import lupa.luajit21 as L

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
CHARS = ["alex", "chunli", "dudley", "elena", "gouki", "hugo", "ibuki", "ken", "makoto", "necro", "oro", "q", "remy",
         "ryu", "sean", "twelve", "urien", "yang", "yun"]
fails, warns = [], []

# ---------------------------------------------------------------- 1. compilación
lua = L.LuaRuntime()
files = (glob.glob("games/**/*.lua", recursive=True) + glob.glob("core/*.lua") + ["cipher.lua"]
         + glob.glob("data/sfiii3/*.lua") + glob.glob("data/sfiii3/moves/*.lua") + glob.glob("data/sfiii3/combos/wiki/*.lua")
         + glob.glob("tools/*.lua"))
for f in files:
    err = lua.execute("local f,e = loadfile([[%s]]) return e and tostring(e) or nil" % f)
    if err:
        fails.append("COMPILA %s: %s" % (f, err))
print("1. compilación: %d archivos, %d con error" % (len(files), sum(1 for x in fails if x.startswith("COMPILA"))))

# ---------------------------------------------------------------- 2. globales no definidas / locales antes de declararse
KNOWN = set("""and break do else elseif end false for function goto if in local nil not or repeat return then true until while
math string table os io coroutine debug bit jit package require pairs ipairs next type tostring tonumber select pcall xpcall
error assert setmetatable getmetatable rawget rawset rawequal unpack print loadfile loadstring dofile load collectgarbage
setfenv getfenv _G _VERSION self arg
memory emu joypad savestate gui input_lib CIPHER_EXT CIPHER_EFFIE_LAG PY""".split())


def strip(src):
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", "", src, flags=re.S)
    src = re.sub(r"\[(=*)\[.*?\]\1\]", '""', src, flags=re.S)
    src = re.sub(r"--[^\n]*", "", src)
    src = re.sub(r'"(\\.|[^"\\\n])*"', '""', src)
    src = re.sub(r"'(\\.|[^'\\\n])*'", "''", src)
    return src


for f in ["games/sfiii3/brains/fundamentals.lua", "cipher.lua", "games/sfiii3/combos.lua", "games/sfiii3/wiki_combo.lua",
          "games/sfiii3/predict.lua", "games/sfiii3/sa_select.lua", "core/effie_bridge.lua", "games/sfiii3/chars/sp.lua",
          "games/sfiii3/chars/auto.lua", "games/sfiii3/ranges.lua", "games/sfiii3/state.lua"]:
    if not os.path.exists(f):
        continue
    s = strip(open(f, encoding="utf-8").read())
    declared = set(re.findall(r"\blocal\s+function\s+(\w+)", s))
    for grp in re.findall(r"\blocal\s+([\w\s,]+?)(?:=|\n|$)", s):
        declared |= set(x.strip() for x in grp.split(",") if x.strip())
    for grp in re.findall(r"\bfunction\s*[\w.:]*\s*\(([^)]*)\)", s):
        declared |= set(x.strip() for x in grp.split(",") if x.strip() and x.strip() != "...")
    for grp in re.findall(r"\bfor\s+([\w\s,]+?)\s*(?:=|\bin\b)", s):
        declared |= set(x.strip() for x in grp.split(","))
    declared |= set(re.findall(r"^\s*(\w+)\s*=", s, flags=re.M))           # globales asignadas en el archivo
    declared |= set(re.findall(r"\bfunction\s+(\w+)\s*\(", s))
    used = set()
    for m in re.finditer(r"(?<![\w.:])([A-Za-z_]\w*)", s):
        name = m.group(1)
        nxt = s[m.end():m.end() + 3]
        prev = s[max(0, m.start() - 1):m.start()]
        if prev in (".", ":") or re.match(r"\s*=[^=]", nxt) and s[max(0, m.start() - 2):m.start()].strip() in ("{", ","):
            continue
        used.add(name)
    undef = sorted(n for n in used - declared - KNOWN if not n.isupper() or n in ("CIPHER_FRESH",))
    # campos de constructores de tabla {a = ..., b = ...} quedan como falsos positivos: filtrarlos
    undef = [n for n in undef if not re.search(r"[{,]\s*%s\s*=" % re.escape(n), s)]
    if undef:
        fails.append("GLOBAL NO DEFINIDA en %s: %s" % (f, ", ".join(undef)))
    # local usada antes de su declaración (tipo `push`)
    lines = s.splitlines()
    defs = {}
    for i, l in enumerate(lines):
        m = re.match(r"\s*local function (\w+)", l) or re.match(r"\s*local (\w+)\s*=\s*function", l)
        if m and m.group(1) not in defs:
            defs[m.group(1)] = i
    fwd = set(re.findall(r"^\s*local (\w+)\s*$", s, flags=re.M))
    for name, d in defs.items():
        if name in fwd:
            continue
        for i in range(d):
            if re.search(r"(?<![\w.:])%s\(" % name, lines[i]):
                fails.append("LOCAL ANTES DE DEFINIR en %s: %s (L%d, definida L%d)" % (f, name, i + 1, d + 1))
                break
print("2. globales / orden de definición: %d problemas" % sum(1 for x in fails if x.startswith(("GLOBAL", "LOCAL"))))

# ---------------------------------------------------------------- 3. tablas de personajes y secuencias
lua = L.LuaRuntime()
res = lua.execute(r"""
package.path = [[%s\?.lua;]] .. package.path
input_lib = require("core.input")
local VALID = { up = 1, down = 1, fwd = 1, back = 1, lp = 1, mp = 1, hp = 1, lk = 1, mk = 1, hk = 1, hold = 1 }
local out = {}
local function check(char, where, seq)
  if type(seq) ~= "table" then out[#out+1] = "FAIL " .. char .. " " .. where .. ": la secuencia no es tabla" return end
  if #seq == 0 then out[#out+1] = "FAIL " .. char .. " " .. where .. ": secuencia vacía" return end
  for i, f in ipairs(seq) do
    if type(f) ~= "table" then out[#out+1] = "FAIL " .. char .. " " .. where .. ": frame " .. i .. " no es tabla" return end
    for k, v in pairs(f) do
      if not VALID[k] then out[#out+1] = "FAIL " .. char .. " " .. where .. ": tecla desconocida '" .. tostring(k) .. "'" return end
      if k == "hold" and (type(v) ~= "number" or v < 1) then out[#out+1] = "FAIL " .. char .. " " .. where .. ": hold inválido" return end
    end
  end
end
-- misma carga que el brain (fundamentals.chars_table): tabla a mano completada con la automática
local function chars_of(name)
  local auto = require("games.sfiii3.chars.auto")(name)
  local ok, t = pcall(require, "games.sfiii3.chars." .. name)
  if not ok then error(t) end
  if type(t) ~= "table" then return auto end
  for k, v in pairs(auto) do if t[k] == nil then t[k] = v end end
  return t
end
for _, c in ipairs({%s}) do
  local ok, ch = pcall(chars_of, c)
  if not ok or type(ch) ~= "table" then out[#out+1] = "FAIL " .. c .. ": la tabla no carga: " .. tostring(ch)
  else
    local n = 0
    for _, key in ipairs({ "pokes", "antiair", "punish", "confirm", "specials" }) do
      for i, e in ipairs(ch[key] or {}) do
        if type(e.seq) ~= "function" then out[#out+1] = "FAIL " .. c .. " " .. key .. "[" .. i .. "] sin seq"
        else
          local okc, s = pcall(e.seq, ch)
          if not okc then out[#out+1] = "FAIL " .. c .. " " .. key .. " " .. tostring(e.name) .. ": " .. tostring(s)
          else check(c, key .. " " .. tostring(e.name), s) n = n + 1 end
        end
        if (key == "pokes") and not e.range then out[#out+1] = "FAIL " .. c .. " poke " .. tostring(e.name) .. " sin range" end
      end
    end
    for _, key in ipairs({ "antiair_special", "meaty", "fireball", "command_grab", "overhead" }) do
      local e = ch[key]
      if type(e) == "table" and e.seq then
        local okc, s = pcall(e.seq, ch)
        if not okc then out[#out+1] = "FAIL " .. c .. " " .. key .. ": " .. tostring(s) else check(c, key, s) n = n + 1 end
      end
    end
    for _, key in ipairs({ "throw", "tech" }) do
      if type(ch[key]) ~= "function" then out[#out+1] = "FAIL " .. c .. " sin " .. key
      else local okc, s = pcall(ch[key]) if okc then check(c, key, s) n = n + 1 else out[#out+1] = "FAIL " .. c .. " " .. key .. ": " .. tostring(s) end end
    end
    out[#out+1] = "ok   " .. c .. " " .. n .. " secuencias"
  end
end
-- combos
local C = require("games.sfiii3.combos")
for _, c in ipairs({%s}) do
  local ok, db = pcall(C.load, c)
  if not ok then out[#out+1] = "FAIL combos " .. c .. ": " .. tostring(db)
  elseif db then
    local n = 0
    for _, e in ipairs(db.list) do
      local okc, s = pcall(C.full_seq, e, nil, c)
      if not okc then out[#out+1] = "FAIL combo " .. c .. " " .. tostring(e.label) .. ": " .. tostring(s)
      else check(c, "combo " .. tostring(e.label), s) n = n + 1 end
    end
    out[#out+1] = "ok   combos " .. c .. " " .. n
  else out[#out+1] = "WARN combos " .. c .. ": ninguno" end
end
return table.concat(out, "\n")
""" % (ROOT, ",".join('"%s"' % c for c in CHARS), ",".join('"%s"' % c for c in CHARS)))
for l in res.splitlines():
    if l.startswith("FAIL"):
        fails.append(l)
    elif l.startswith("WARN"):
        warns.append(l)
print("3. personajes y combos: %d fallas" % sum(1 for l in res.splitlines() if l.startswith("FAIL")))
print("   " + "  ".join(l[5:].replace(" secuencias", "s") for l in res.splitlines() if l.startswith("ok   ") and "combos" not in l))
print("   combos: " + "  ".join(l[12:] for l in res.splitlines() if l.startswith("ok   combos")))

print("\n== %d FALLAS ==" % len(fails))
for f in fails:
    print(" ", f)
for w in warns:
    print(" ", w)
sys.exit(1 if fails else 0)
