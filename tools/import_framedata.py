"""Convierte la frame data de effie3rd/3rd_training_lua (GPL-3.0) a tablas Lua compactas.

  python -I tools/import_framedata.py <effie_repo> <out_dir>

Salida: <out_dir>/<char>.lua y projectiles.lua con
  states = { standing = "0fe0", block_high = "27ec", ..., wakeups = {...} }
  anims  = { ["af68"] = { n = "d_HP", len = 29, hit = {{7,11}}, ht = {2}, idle = 22, air = false,
                          sync = { ["43fc0400"] = 0, ... },   -- hash (frame_id|countdown|0x205) -> índice de frame
                          atk  = { [7] = {{b,h,l,w},...}, ... }, -- cajas de ataque por frame (relativas al personaje)
                          mx   = { [3] = 6, ... } } }          -- desplazamiento X por frame (movement)
Índices de frame 0-based, igual que en effie.
"""
import json
import os
import re
import sys

ATTACK_TYPES = {5, 6}
THROW_TYPE = 7


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def lua(v, indent=""):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, list):
        return "{" + ",".join(lua(x) for x in v) + "}"
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            key = f"[{k}]" if isinstance(k, int) else (k if re.fullmatch(r"[A-Za-z_]\w*", k) else f"[{lua_str(k)}]")
            parts.append(f"{key}={lua(x)}")
        return "{" + ",".join(parts) + "}"
    raise TypeError(type(v))


def parse_meta(path):
    """frame_data_meta["char"]["anim"] = { hit_type = {..} } (solo líneas no comentadas)."""
    meta = {}
    rx = re.compile(r'^\s*frame_data_meta\["(\w+)"\]\["(\w+)"\]\s*=\s*\{(.*)\}')
    for line in open(path, encoding="utf-8"):
        m = rx.match(line)
        if not m:
            continue
        char, anim, body = m.groups()
        ht = re.search(r"hit_type\s*=\s*\{([^}]*)\}", body)
        if ht:
            meta.setdefault(char, {})[anim] = [int(x) for x in ht.group(1).split(",") if x.strip()]
    return meta


def convert_anim(v, hit_types):
    frames = v.get("frames", [])
    out = {"n": v.get("name", "?"), "len": len(frames)}
    if v.get("hit_frames"):
        out["hit"] = v["hit_frames"]
    if hit_types:
        out["ht"] = hit_types
    if v.get("idle_frames"):
        out["idle"] = min(r[0] for r in v["idle_frames"])
    if v.get("air"):
        out["air"] = True
    if v.get("loops"):
        out["loops"] = v["loops"]
    sync, atk, thr, mx, proj = {}, {}, {}, {}, []
    for i, f in enumerate(frames):
        h8 = f.get("hash", "")[:8]
        if h8 and h8 not in sync:
            sync[h8] = i
        boxes = f.get("boxes") or []
        a = [b[1:5] for b in boxes if b[0] in ATTACK_TYPES]
        t = [b[1:5] for b in boxes if b[0] == THROW_TYPE]
        if a:
            atk[i] = a
        if t:
            thr[i] = t
        if f.get("movement") and f["movement"][0]:
            mx[i] = f["movement"][0]
        if f.get("projectile"):
            proj.append(i)
    out["sync"] = sync
    if atk:
        out["atk"] = atk
    if thr:
        out["thr"] = thr
    if mx:
        out["mx"] = mx
    if proj:
        out["proj"] = proj
    if v.get("uses_velocity"):
        out["vel"] = True
    return out


def convert_file(src, char, meta):
    fd = json.load(open(src, encoding="utf-8"))
    states, anims = {}, {}
    for k, v in fd.items():
        if isinstance(v, dict) and "frames" in v:
            anims[k] = convert_anim(v, meta.get(char, {}).get(k))
        else:
            states[k] = v
    return {"char": char, "states": states, "anims": anims}


def main():
    repo, out_dir = sys.argv[1], sys.argv[2]
    src_dir = os.path.join(repo, "data", "sfiii3nr1", "framedata")
    meta = parse_meta(os.path.join(repo, "src", "data", "framedata_meta.lua"))
    os.makedirs(out_dir, exist_ok=True)
    total = 0
    for fn in sorted(os.listdir(src_dir)):
        m = re.fullmatch(r"@(\w+)_framedata\.json", fn)
        if not m:
            continue
        char = m.group(1)
        data = convert_file(os.path.join(src_dir, fn), char, meta)
        path = os.path.join(out_dir, f"{char}.lua")
        with open(path, "w", encoding="ascii", newline="\n") as f:
            f.write(f"-- generado por tools/import_framedata.py desde effie3rd/3rd_training_lua (GPL-3.0)\n")
            f.write("return " + lua(data) + "\n")
        n_hit = sum(1 for a in data["anims"].values() if "hit" in a)
        total += len(data["anims"])
        print(f"{char:12s} anims={len(data['anims']):4d} con_hit={n_hit:4d} ht={len(meta.get(char, {})):3d} -> {os.path.getsize(path)//1024} KB")
    print("total anims", total)


if __name__ == "__main__":
    main()
