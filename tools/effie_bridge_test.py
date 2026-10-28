"""Banco de prueba del puente a effie (core/effie_bridge.lua) con LuaJIT, leyendo RAM/ROM de un emulador offline.
  python -I tools\\effie_bridge_test.py <pid> [frames]"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cipher_ext as ce  # noqa: E402
from lupa.luajit21 import LuaRuntime  # noqa: E402

pid = int(sys.argv[1])
nframes = int(sys.argv[2]) if len(sys.argv) > 2 else 600
rt = ce.ExtRuntime(pid)
L = LuaRuntime(encoding=None)
L.execute(b"package.path = [[" + ce.ROOT.encode() + b"\\?.lua;]] .. package.path")
run = L.eval(b"function(path, arg) local f = assert(loadfile(path)) return f(arg) end")
py = L.table_from({b"keys": lambda: b"", b"sink": lambda s: None, b"rom": b"sfiii3nr1", b"rom_byte": rt.rom_byte})
run(os.path.join(ce.ROOT, "core", "ext_shim.lua").encode(), py)
bridge = L.eval(b"require('core.effie_bridge')")
t0 = time.time()
ok = bridge.init()
print("init", ok, bridge.err, "%.1fs" % (time.time() - t0))
if os.environ.get("FOOTSIES") == "1":
    bridge.want_footsies(1); print("footsies pedido")
step = L.eval(b"""function(ram, fc, side)
  __ext_frame(ram, fc)
  local B = require('core.effie_bridge')
  local t = B.frame(side)
  local out = {}
  if t then for k, v in pairs(t) do if v then out[#out + 1] = k end end end
  table.sort(out)
  local tr = require('src.training')
  local gs = require('src.gamestate')
  local n = 0
  local ea = tr.dummy and tr.dummy.blocking and tr.dummy.blocking.expected_attacks
  if ea then for k, l in pairs(ea) do n = n + #l end end
  local p2 = gs.player_objects and gs.player_objects[2]
  local pr = require('src.data.prediction')
  local okp, res = pcall(pr.predict_hits, nil, nil, 15)
  local n15 = 0
  if okp and res then for k, l in pairs(res) do n15 = n15 + #l end end
  local info = p2 and string.format('fd=%s af=%s char=%s pred15=%s', tostring(p2.animation_frame_data ~= nil),
    tostring(p2.animation_frame), tostring(p2.char_str), okp and tostring(n15) or ('ERR ' .. tostring(res))) or '-'
  return table.concat(out, ','), B.err, n, p2 and tostring(p2.animation) or '-', p2 and tostring(p2.is_attacking) or '-', info
end""")
last, n, acts = None, 0, 0
while n < nframes:
    fc = rt.framecount()
    if fc == last:
        time.sleep(0.001)
        continue
    last = fc
    res = step(rt.ram_linear(), fc, 1)
    act, err, nexp, p2anim, p2att, info = res
    n += 1
    if p2att == b"true" and n % 5 == 0:
        print("fc", fc, "esperados", nexp, "p2", p2anim, "accion", act, info)
    if err:
        print("ERR", err.decode()[:300])
        break
    if act:
        acts += 1
        if acts <= 40:
            print(fc, act.decode())
print("frames", n, "con acción", acts); print(L.eval(b"require('core.effie_bridge').debug_footsies()"))
