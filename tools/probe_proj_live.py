"""Diagnóstico SOLO LECTURA sobre la partida en curso: lee la RAM del emulador (ReadProcessMemory), corre el sensor
(games/sfiii3/state.lua) y muestra los proyectiles que ve: emisor, x, vx, vy, cajas de ataque. No toca teclas ni ventanas.
  python -I tools\\probe_proj_live.py <pid> [segundos]"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cipher_ext as ce  # noqa: E402

pid = int(sys.argv[1])
secs = float(sys.argv[2]) if len(sys.argv) > 2 else 20
rt = ce.ExtRuntime(pid)
from lupa.lua51 import LuaRuntime  # noqa: E402

L = LuaRuntime(encoding=None)
L.execute(b"package.path = [[" + ce.ROOT.encode() + b"\\?.lua;]] .. package.path")
run = L.eval(b"function(path, arg) local f = assert(loadfile(path)) return f(arg) end")
py = L.table_from({b"keys": lambda: b"", b"sink": lambda s: None, b"rom": b"sfiii3nr1"})
run(os.path.join(ce.ROOT, "core", "ext_shim.lua").encode(), py)
probe = L.eval(b"""(function()
  local S = require('games.sfiii3.state')
  return function(ram, fc)
    __ext_frame(ram, fc)
    local s = S.read()
    if not s.in_match then return nil end
    local out = {}
    for _, pr in ipairs(s.proj) do
      out[#out + 1] = string.format('emit=%s x=%.0f y=%.0f vx=%.2f vy=%.2f flip=%s type=%s atk=%d life=%s',
        tostring(pr.emitter), pr.x, pr.y, pr.vx, pr.vy or 0, tostring(pr.flip), tostring(pr.type),
        pr.boxes and pr.boxes.attack and #pr.boxes.attack or -1, tostring(pr.life))
    end
    return string.format('fc=%d P1=%s x=%d P2=%s x=%d nproj=%d  %s', fc, s.p[1].char_str, s.p[1].x, s.p[2].char_str,
      s.p[2].x, #s.proj, table.concat(out, ' || '))
  end
end)()""")
last, t_end, shown = None, time.time() + secs, 0
while time.time() < t_end:
    fc = rt.framecount()
    if fc == last:
        time.sleep(0.002)
        continue
    last = fc
    ram = rt.ram_linear()
    line = probe(ram, fc)
    if line and b"nproj=0" not in line and (b"life=0 " in line or b"life=0" == line[-6:] or b"life=10 " in line or b"life=30" in line):
        print(line.decode())
    shown += 1
