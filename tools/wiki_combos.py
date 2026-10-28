"""Parser de combos de la wiki (data/sfiii3/wiki/<Char>_Combos.md y la página principal) a una lista de partes
verificables en el emulador (tools/wiki_combo_lab.lua). Nada se acepta sin verificar: esto solo arma candidatos.

Notación wiki:  ">" cadena / target combo,  "xx" cancel,  "," link.
Tokens: normales (cl.MP, far HP, 2LK, cr.MK, 4MK, 5HK, UOH...), movimientos numéricos (623LP, 236236K), nombres
(LP shoryuken, MP DP, fireball, SA3...). Si algún token no se entiende, el combo se descarta.

  python -I tools\\wiki_combos.py   ->  data\\sfiii3\\wiki_combos.lua
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W = os.path.join(ROOT, "data", "sfiii3", "wiki")
OUT = os.path.join(ROOT, "data", "sfiii3", "wiki_candidates.lua")   # wiki_combos.lua es la lista curada a mano
CHARS = {"Akuma": "gouki", "Alex": "alex", "Chun-Li": "chunli", "Dudley": "dudley", "Elena": "elena", "Hugo": "hugo",
         "Ibuki": "ibuki", "Ken": "ken", "Makoto": "makoto", "Necro": "necro", "Oro": "oro", "Q": "q", "Remy": "remy",
         "Ryu": "ryu", "Sean": "sean", "Twelve": "twelve", "Urien": "urien", "Yang": "yang", "Yun": "yun"}
BTN = {"LP": "lp", "MP": "mp", "HP": "hp", "LK": "lk", "MK": "mk", "HK": "hk",
       "JAB": "lp", "STRONG": "mp", "FIERCE": "hp", "SHORT": "lk", "FORWARD": "mk", "ROUNDHOUSE": "hk", "RH": "hk"}


def load_moves(char):
    """move list: nombre -> {tipo, variantes{btn: seq}} y patrón de movimiento"""
    path = os.path.join(ROOT, "data", "sfiii3", "moves", char + ".lua")
    if not os.path.exists(path):
        return []
    txt = open(path, encoding="utf-8").read()
    out = []
    for m in re.finditer(r'\{name="(\w+)",type="(\w+)"[^{]*variants=\{(.*?)\}\}\}', txt):
        name, typ, body = m.group(1), m.group(2), m.group(3)
        variants = re.findall(r'\{btn="(\w*)",seq=(\{.*?\}\})', body + "}")
        motion = ""
        if variants:
            seq = variants[0][1]
            dirs = re.findall(r"\{([^{}]*)\}", seq)
            for d in dirs:
                key = ("u" if "up=true" in d else "") + ("d" if "down=true" in d else "") + \
                      ("f" if "fwd=true" in d else "") + ("b" if "back=true" in d else "")
                if key and (not motion or not motion.endswith("|" + key)):
                    motion += "|" + key
        out.append({"name": name, "type": typ, "btns": [v[0] for v in variants], "motion": motion,
                    "charge": "charge=" in body})
    return out


MOTION_OF = {"623": "|f|d|df", "236": "|d|df|f", "214": "|d|db|b", "41236": "|b|db|d|df|f", "63214": "|f|df|d|db|b",
             "236236": "SUPER", "22": "|d|d", "360": "|f|d|b|u"}
NAMED = {"SHORYUKEN": "623", "DP": "623", "UPPERCUT": "623", "SRK": "623", "FIREBALL": "236", "HADOUKEN": "236",
         "HADOU": "236", "TATSU": "214", "TATSUMAKI": "214", "HURRICANE": "214"}


def find_special(moves, motion_key, btn_class):
    """especial por patrón de movimiento y clase de botón (P / K)"""
    pat = MOTION_OF.get(motion_key)
    if not pat or pat == "SUPER":
        return None
    for mv in moves:
        if mv["type"] == "special" and mv["motion"].replace("|df", "|df").endswith(pat.split("|")[-1]) and \
                pat.strip("|") in mv["motion"].strip("|"):
            btns = mv["btns"]
            if any((b.endswith("P") if btn_class == "P" else b.endswith("K")) for b in btns):
                return mv
    return None


def parse_move(tok, moves, char):
    t = tok.strip().strip("()").strip()
    t = re.sub(r"\s+", " ", t)
    u = t.upper()
    if not t:
        return None
    # super
    if re.fullmatch(r"(SA ?(I{1,3}|[123])|SUPER|236236[PK]?|236236 ?[LMH]?[PK])", u):
        return {"type": "super"}
    if u in ("UOH", "MP+MK", "MPMK"):
        return {"type": "uoh"}
    if u.startswith("J.") or u.startswith("NJ.") or u.startswith("FJ.") or u.startswith("JUMP") or u.startswith("AIR"):
        return {"type": "air"}   # saltos: fuera del verificador de piso por ahora
    # normal: prefijo + botón
    m = re.fullmatch(r"(CL\.?|CLOSE|FAR|ST\.?|STAND|CR\.?|CROUCH|[1-9]|B\.|F\.|T\.|D\.|DF\.|TWD\.?|TOWARDS?)?\s*"
                     r"(LP|MP|HP|LK|MK|HK|JAB|STRONG|FIERCE|SHORT|FORWARD|ROUNDHOUSE|RH)", u)
    if m:
        pre, b = (m.group(1) or "").rstrip(". "), BTN[m.group(2)]
        dirs, anim_pre = {}, ""
        if pre in ("CL", "CLOSE"):
            anim_pre = "cl_"
        elif pre in ("CR", "CROUCH", "2", "D"):
            dirs, anim_pre = {"down": True}, "d_"
        elif pre in ("B", "4"):
            dirs, anim_pre = {"back": True}, "b_"
        elif pre in ("F", "T", "6", "TWD", "TOWARD", "TOWARDS"):
            dirs, anim_pre = {"fwd": True}, "f_"
        elif pre in ("3", "DF"):
            dirs, anim_pre = {"down": True, "fwd": True}, "df_"
        elif pre in ("1",):
            dirs, anim_pre = {"down": True, "back": True}, "db_"
        return {"type": "normal", "btn": b, "dirs": dirs, "anim": anim_pre + b.upper()}
    # numérico: 623LP, 236MP, 214[K], 41236P
    m = re.fullmatch(r"\[?(\d{2,6})\]?\s*([LMH]?[PK]|EX ?[PK]|PP|KK|P|K)", u.replace("~", ""))
    if m:
        motion, btn = m.group(1), m.group(2).replace(" ", "")
        if MOTION_OF.get(motion) == "SUPER":
            return {"type": "super"}
        cls = "K" if btn.endswith("K") else "P"
        mv = find_special(moves, motion, cls)
        if not mv or not mv["btns"]:
            return None
        b = btn if btn in mv["btns"] else ("EX" + cls if btn in ("PP", "KK") or btn.startswith("EX") else
                                           next((x for x in mv["btns"] if x.endswith(cls)), mv["btns"][0]))
        return {"type": "special", "move": mv["name"], "btn": b}
    # nombre: "LP shoryuken", "MP DP", "EX tatsu", "ANY shoryuken", "fireball", "Dragon Smash"
    m = re.fullmatch(r"(EX|LP|MP|HP|LK|MK|HK|ANY|L|M|H)?\s*([A-Z][A-Z \-']*)", u)
    if m:
        strength, name = (m.group(1) or ""), m.group(2).strip()
        key = name.replace(" ", "").replace("-", "")
        motion = NAMED.get(key)
        mv = None
        if motion:
            cls = "K" if motion == "214" else "P"
            mv = find_special(moves, motion, cls)
        if not mv:
            for cand in moves:
                if cand["type"] == "special" and cand["name"].replace("_", "").upper().startswith(key[:6]):
                    mv = cand
                    break
        if not mv or not mv["btns"]:
            return None
        cls = "K" if any(b.endswith("K") for b in mv["btns"]) and not any(b.endswith("P") for b in mv["btns"]) else "P"
        if strength in ("ANY", ""):
            b = next((x for x in mv["btns"] if x.startswith("H")), mv["btns"][0])
        elif strength == "EX":
            b = next((x for x in mv["btns"] if x.startswith("EX")), mv["btns"][0])
        else:
            want = strength[0] + cls
            b = want if want in mv["btns"] else mv["btns"][0]
        return {"type": "special", "move": mv["name"], "btn": b}
    return None


def parse_combo(s, moves, char):
    s = s.replace("→", ">").replace("~", " ")
    s = re.sub(r"\s+or\s+.*$", "", s)                      # "xx LP DP or SA3" -> primera opción
    s = re.sub(r"\([^)]*optional[^)]*\)", "", s, flags=re.I)
    parts, joins = [], []
    toks = re.split(r"\s*(>|xx|,)\s*", s.strip())
    for i, tk in enumerate(toks):
        if i % 2 == 1:
            joins.append({">": "chain", "xx": "cancel", ",": "link"}[tk])
            continue
        mv = parse_move(tk, moves, char)
        if not mv or mv["type"] == "air":
            return None
        parts.append(mv)
    if len(parts) < 2:
        return None
    return {"text": s.strip(), "parts": parts, "joins": joins}


def combos_from_page(path):
    if not os.path.exists(path):
        return []
    t = open(path, encoding="utf-8").read()
    out = []
    for line in t.splitlines():
        line = line.strip().rstrip("|").strip()
        if re.search(r"(>|xx|,)", line) and len(line) < 90 and re.search(r"(LP|MP|HP|LK|MK|HK|SA|DP|UOH)", line) \
                and not re.search(r"[.!?]$", line) and not line.startswith(("-", "#", "Note")):
            out.append(line)
    return out


def lua_val(v):
    if isinstance(v, dict):
        return "{ " + ", ".join("%s = %s" % (k, lua_val(x)) for k, x in v.items()) + " }"
    if isinstance(v, list):
        return "{ " + ", ".join(lua_val(x) for x in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    return '"%s"' % str(v).replace('"', "'")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    lines = ["-- generado por tools/wiki_combos.py: combos de la wiki como CANDIDATOS (se verifican en el emulador)", "return {"]
    total = 0
    for wname, char in CHARS.items():
        moves = load_moves(char)
        seen, ok, bad = set(), [], 0
        for page in (wname + "_Combos.md", wname + "_Strategy.md", wname + ".md"):
            for raw in combos_from_page(os.path.join(W, page)):
                c = parse_combo(raw, moves, char)
                if c and c["text"] not in seen:
                    seen.add(c["text"])
                    ok.append(c)
                elif not c:
                    bad += 1
        lines.append('  ["%s"] = {' % char)
        for c in ok:
            lines.append("    " + lua_val(c) + ",")
        lines.append("  },")
        print("%-7s candidatos=%3d descartados=%3d" % (char, len(ok), bad))
        total += len(ok)
    lines.append("}")
    open(OUT, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("total", total, "->", OUT)


if __name__ == "__main__":
    main()
