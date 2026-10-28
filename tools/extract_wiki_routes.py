"""Extrae TODAS las rutas de combo de las páginas de la wiki (data/sfiii3/wiki/<Char>*.md) y las traduce a la notación
canónica del lab (games/sfiii3/wiki_combo.lua): normales cl./far/2X/5X/4X/6X, especiales nombre:BOTÓN (mapeados por el
comando desde data/sfiii3/moves/<char>.lua), super SA, conectores xx (cancel) / > (cadena) / , (link o juggle).
Salida: data/sfiii3/wiki_combos_auto.lua (candidatos: solo entran al bot los que verifica el lab).
  python -I tools\\extract_wiki_routes.py"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WIKI = os.path.join(ROOT, "data", "sfiii3", "wiki")
MOVES = os.path.join(ROOT, "data", "sfiii3", "moves")
PAGES = {"Akuma": "gouki", "Alex": "alex", "Chun-Li": "chunli", "Dudley": "dudley", "Elena": "elena", "Hugo": "hugo",
         "Ibuki": "ibuki", "Ken": "ken", "Makoto": "makoto", "Necro": "necro", "Oro": "oro", "Q": "q", "Remy": "remy",
         "Ryu": "ryu", "Sean": "sean", "Twelve": "twelve", "Urien": "urien", "Yang": "yang", "Yun": "yun"}
DIR = {(0, 0): "5", (1, 0): "6", (-1, 0): "4", (0, -1): "2", (0, 1): "8", (1, -1): "3", (-1, -1): "1", (1, 1): "9", (-1, 1): "7"}
BTN = "LP|MP|HP|LK|MK|HK"


def motions(char):
    """{comando numpad: {botón: nombre}} desde la move list importada (cargada con Lua real vía lupa)."""
    import lupa.lua51 as lupa
    out = {}
    path = os.path.join(MOVES, char + ".lua")
    if not os.path.exists(path):
        return out
    L = lupa.LuaRuntime()
    ml = L.execute(open(path, encoding="utf-8").read())
    for i in range(1, len(ml) + 1):
        m = ml[i]
        if m["type"] not in ("special", "super"):
            continue
        for j in range(1, len(m["variants"]) + 1):
            v = m["variants"][j]
            cmd = ""
            seq = v["seq"]
            for k in range(1, len(seq) + 1):
                fr = seq[k]
                x = (1 if fr["fwd"] else 0) - (1 if fr["back"] else 0)
                y = (1 if fr["up"] else 0) - (1 if fr["down"] else 0)
                dgt = DIR[(x, y)]
                if dgt != "5" and (not cmd or cmd[-1] != dgt):
                    cmd += dgt
            if m["type"] == "special":
                out.setdefault(cmd, {})[v["btn"]] = m["name"]
    return out


def norm_btn(b):
    return {"P": "LP", "K": "LK", "PP": "EXP", "KK": "EXK"}.get(b, b)


TOK = re.compile(r"(?:(cl|far|st|cr|c|f|b|d)\.?\s?)?(\[?[1-9]\]?[1-9\[\]]*)?(%s|PP|KK|P|K)(?:\(\d\))?" % BTN)


ALIAS = {"dp": "623", "shoryu": "623", "shoryuken": "623", "fireball": "236", "fb": "236", "hadou": "236",
         "hadouken": "236", "tatsu": "214", "hurricane": "214"}


def names_of(mv):
    """{nombre_de_movimiento: {botón: nombre}} para buscar por nombre ("Hayate", "Tsurugi"...)."""
    out = {}
    for cmd, bt in mv.items():
        for btn, name in bt.items():
            out.setdefault(name, {})[btn] = name
    return out


def convert(route, mv, sa_hint=None):
    """wiki -> (canónica, sa) o None si hay algo que no se entiende (aéreos, dash, taunt...)."""
    r = route.strip().rstrip("|").strip()
    r = re.sub(r"[()]", " ", r)
    if re.search(r"(^|\W)(j\.|sj|nj|fj|bj|tk|taunt|dash|66|corner|whiff|\.\.\.)", r, re.I):
        return None
    r = re.sub(r"\s*->\s*", " , ", r)
    r = re.sub(r"\s+x\s+", " xx ", r)
    parts = re.split(r"\s*(>|xx|,)\s*", r)
    names = names_of(mv)
    out, sa = [], sa_hint
    for i in range(0, len(parts), 2):
        tok = parts[i].strip()
        sep = parts[i - 1] if i > 0 else None
        if not tok:
            return None
        low = tok.lower().replace("lvl1", "").replace("lv1", "").strip()
        m_sa = re.fullmatch(r"(?:sa|super)\s*(i{1,3}|[123])?|(\d{3,})\2\s*[pk]?", low)
        if m_sa or low in ("sa", "super"):
            g = m_sa and m_sa.group(1) or ""
            n = {"i": 1, "ii": 2, "iii": 3, "1": 1, "2": 2, "3": 3}.get(g)
            if n:
                sa = n
            canon, kind = "SA", "super"
        elif low == "uoh":
            canon, kind = "UOH", "normal"
        else:
            m = re.fullmatch(r"(lp|mp|hp|lk|mk|hk|ex|p|k)?\s*([a-z_ ]{2,})", low)
            named = None
            if m and not re.fullmatch(r"(cl|far|st|cr|c|f|b|d)", m.group(2).strip()):
                word = m.group(2).strip()
                btn = (m.group(1) or "lp").upper()
                cmd = ALIAS.get(word.split()[0])
                cands = (cmd and mv.get(cmd)) or next((names[n] for n in names if word.replace(" ", "_") in n or n.split("_")[0] == word.split()[0]), None)
                if cands:
                    if btn == "EX":
                        btn = "EXK" if any(k.endswith("K") for k in cands) and not any(k.endswith("P") for k in cands) else "EXP"
                    elif btn in ("P", "K"):
                        btn = "L" + btn
                    name = cands.get(btn) or next(iter(cands.values()))
                    named = ("%s:%s" % (name, btn), "special")
            if named:
                canon, kind = named
            else:
                m = TOK.fullmatch(tok.replace(" ", ""))
                if not m:
                    m = TOK.fullmatch(tok.replace(" ", "").upper().replace("CL.", "cl.").replace("CR.", "cr.").replace("ST.", "st."))
                if not m:
                    return None
                pre, cmd, b = m.group(1), m.group(2) or "", m.group(3)
                raw = cmd.replace("[", "").replace("]", "")
                if re.fullmatch(r"(\d{3,})\1", raw or "x") or raw in ("2121", "41236236", "63214632"):
                    canon, kind = "SA", "super"
                elif len(raw) >= 2:
                    # carga ([2]8 / [4]6): la move list guarda solo la parte final -> probar sin el primer dígito
                    cands = mv.get(raw) or mv.get(raw[1:]) or {}
                    btn = norm_btn(b)
                    if not cands:
                        return None
                    name = cands.get(btn) or next(iter(cands.values()))
                    canon, kind = "%s:%s" % (name, btn), "special"
                else:
                    if b in ("P", "K", "PP", "KK"):
                        return None
                    n = {"cr": "2", "c": "2", "d": "2", "st": "5", "f": "6", "b": "4"}.get(pre or "", "")
                    canon = ("cl." if pre == "cl" else "far ") + b if pre in ("cl", "far") else (raw or n or "5") + b
                    kind = "normal"
        if sep is not None:
            out.append(", " if sep == "," else (" xx " if kind in ("special", "super") else " > "))
        out.append(canon)
    if len(out) < 3:
        return None
    return "".join(out), sa


def expand(route):
    """'cl.MK/2MK > 214HK' -> una ruta por alternativa (solo en el primer golpe)"""
    m = re.match(r"^\s*([^\s>,]+/[^\s>,]+)(.*)$", route)
    if not m:
        return [route]
    return [alt + m.group(2) for alt in m.group(1).split("/")][:6]


def sa_of(context):
    c = context.upper()
    for k, n in (("SAIII", 3), ("SA III", 3), ("SAII", 2), ("SA II", 2), ("SAI", 1), ("SA I", 1)):
        if k in c:
            return n
    return None


ROUTE = re.compile(r"^[\s\-\*]*((?:cl\.|far |st\.|cr\.|c\.|f\.|b\.|d\.|UOH|[LMH][PK] |EX |\[?\d|[A-Z][a-z]+ )[^|]{2,90}?(?:>|xx| x |->|,)[^|]{2,140}?)\s*\|?\s*$")
res = {}
for page, char in PAGES.items():
    files = sorted(glob.glob(os.path.join(WIKI, page + "_Combos.md"))) + sorted(glob.glob(os.path.join(WIKI, page + ".md")))
    mv = motions(char)
    seen = set()
    for f in files:
        lines = open(f, encoding="utf-8", errors="replace").read().splitlines()
        ctx = ""
        for i, l in enumerate(lines):
            if l.startswith("#") or re.match(r"^\s*(SA ?I{1,3}|Super Art)", l, re.I) or ("Combos" in l and len(l) < 40):
                ctx = l
            m = ROUTE.match(l)
            if not m:
                continue
            near = " ".join(lines[i + 1:i + 3])
            if re.search(r"corner", near, re.I) and not re.search(r"anywhere|midscreen", near, re.I):
                continue
            for route in expand(m.group(1)):
                cv = convert(route, mv, sa_of(ctx))
                if not cv or cv[0] in seen:
                    continue
                seen.add(cv[0])
                res.setdefault(char, []).append((cv[0], cv[1] if "SA" in cv[0] else None, route.strip()))
# personajes sin rutas legibles en la wiki (prosa / tablas partidas): candidatos golpe-de-inicio xx especial; el lab
# descarta los que no existen
STARTERS = ["cl.MP", "cl.MK", "cl.HP", "2MP", "2MK", "5MP", "2LK > 2LK"]
for char in PAGES.values():
    if len(res.get(char, [])) >= 5:
        continue
    mv = motions(char)
    specials = {}
    for cmd, bt in mv.items():
        if len(cmd) < 2:
            continue
        for btn, name in bt.items():
            specials.setdefault(name, set()).add(btn)
    for st in STARTERS:
        for name, btns in sorted(specials.items()):
            for btn in sorted(btns):
                if btn.startswith("M"):
                    continue                              # LP/HP/EX bastan para descubrir la ruta
                canon = "%s xx %s:%s" % (st, name, btn)
                res.setdefault(char, []).append((canon, None, "generado"))
with open(os.path.join(ROOT, "data", "sfiii3", "wiki_combos_auto.lua"), "w", encoding="utf-8") as fo:
    fo.write("-- generado por tools/extract_wiki_routes.py desde las páginas de la wiki: CANDIDATOS (solo entran al bot los que\n"
             "-- verifica tools/wiki_combo_lab.lua). sa = nil en combos con super sin sección -> se prueban en los 3 SA\nreturn {\n")
    total = 0
    for char in sorted(res):
        fo.write("\t%s = {\n" % char)
        for canon, sa, orig in res[char]:
            d = 42 if canon.startswith(("cl.", "UOH")) else (95 if canon.startswith("far") else 60)
            sas = [sa] if sa else ([1, 2, 3] if "SA" in canon else [None])
            for s in sas:
                fo.write('\t\t{ "%s", %sd = %d },%s\n' % (canon.replace('"', ''), ("sa = %d, " % s) if s else "", d,
                                                         "  -- " + orig[:60].replace("\n", " ")))
                total += 1
        fo.write("\t},\n")
    fo.write("}\n")
for char in sorted(PAGES.values()):
    print("%-8s %3d rutas" % (char, len(res.get(char, []))))
print("total entradas:", total)
