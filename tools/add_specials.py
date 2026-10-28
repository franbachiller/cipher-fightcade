"""Inserta / reemplaza el bloque `specials` (especiales de identidad por rol) en cada games/sfiii3/chars/<char>.lua.
Fuente de cada especial: la move list importada (SP.make). Roles: poke, zoning, approach, install, taunt."""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "games", "sfiii3", "chars")

T = 'SP.make("{c}", "taunt", nil, "taunt", {{ seq = SP.taunt(), rate = {rate}, cd = 1800 }})'
TAUNT = lambda c, rate: '{ name = "taunt", role = "taunt", seq = SP.taunt(), rate = %s, cd = 2400 }' % rate

SPECIALS = {
    "ken": [TAUNT("ken", 0.3)],
    "ryu": [
        'SP.make("ryu", "hadouken", "EXP", "zoning", { range = { 160, 280 }, meter = 1, rate = 0.03, cd = 120 })',
        'SP.make("ryu", "joudan", "MK", "approach", { range = { 130, 175 }, rate = 0.03, cd = 180 })',
        TAUNT("ryu", 0.2)],
    "chunli": [
        '{ name = "lightning_legs", role = "poke", range = { 0, 95 }, rate = 0.04, cd = 150, seq = function() local s = {} for i = 1, 8 do s[#s + 1] = { lk = true } s[#s + 1] = {} end s[#s + 1] = { hold = 10 } return s end }',
        TAUNT("chunli", 0.15)],
    "hugo": [
        'SP.make("hugo", "monster_lariat", "LK", "approach", { range = { 120, 190 }, rate = 0.03, cd = 200 })',
        TAUNT("hugo", 0.35)],
    "dudley": [
        'SP.make("dudley", "machinegun_blow", "LP", "poke", { range = { 90, 150 }, rate = 0.04, cd = 150 })',
        'SP.make("dudley", "ducking", "LK", "approach", { range = { 120, 200 }, rate = 0.04, cd = 180 })',
        TAUNT("dudley", 0.25)],
    "makoto": [
        'SP.make("makoto", "hayate", "LP", "approach", { range = { 100, 180 }, rate = 0.07, cd = 120 })',
        'SP.make("makoto", "oroshi", "LP", "poke", { range = { 0, 80 }, rate = 0.03, cd = 180 })',
        TAUNT("makoto", 0.2)],
    "alex": [
        'SP.make("alex", "slash_elbow", "LK", "approach", { range = { 120, 190 }, rate = 0.06, cd = 150 })',
        'SP.make("alex", "flash_chop", "LP", "poke", { range = { 60, 120 }, rate = 0.03, cd = 180 })',
        TAUNT("alex", 0.3)],
    "yang": [
        '{ name = "tourouzan_x3", role = "poke", range = { 0, 115 }, rate = 0.05, cd = 150, seq = function() '
        'local s = {} for i = 1, 3 do for _, f in ipairs({ { down = true }, { down = true, fwd = true }, { fwd = true, lp = true }, { hold = 6 } }) do s[#s + 1] = f end end return s end }',
        'SP.make("yang", "senkyuutai", "LK", "approach", { range = { 110, 170 }, rate = 0.03, cd = 180 })',
        TAUNT("yang", 0.2)],
    "yun": [
        'SP.make("yun", "geneijin", "", "install", { meter = 1, sa = 3, rate = 0.6, cd = 600 })',
        '{ name = "zesshou_x", role = "poke", range = { 0, 120 }, rate = 0.03, cd = 180, seq = function() return { { down = true }, { down = true, fwd = true }, { fwd = true, lp = true }, { hold = 2 } } end }',
        TAUNT("yun", 0.2)],
    "urien": [
        'SP.make("urien", "aegis_reflector", "", "install", { meter = 1, sa = 3, rate = 0.5, cd = 900 })',
        'SP.make("urien", "chariot_tackle", "LK", "approach", { range = { 100, 180 }, rate = 0.05, cd = 150 })',
        TAUNT("urien", 0.2)],
    "oro": [
        'SP.make("oro", "tenguishi", "", "install", { meter = 1, sa = 3, rate = 0.5, cd = 900 })',
        TAUNT("oro", 0.1)],
    "gouki": [
        'SP.make("gouki", "hyakki", "LK", "approach", { range = { 100, 180 }, rate = 0.04, cd = 180 })',
        '{ name = "zanku_hadou", role = "zoning", range = { 150, 260 }, rate = 0.03, cd = 150, seq = function() return { { up = true, fwd = true, hold = 3 }, { hold = 7 }, { down = true }, { down = true, fwd = true }, { fwd = true, lp = true }, { hold = 20 } } end }',
        TAUNT("gouki", 0.25)],
    "twelve": [
        '{ name = "air_dash_in", role = "approach", range = { 120, 210 }, rate = 0.05, cd = 150, seq = function() return { { up = true, fwd = true, hold = 3 }, { hold = 5 }, { fwd = true }, {}, { fwd = true }, { hold = 8 }, { hk = true, hold = 3 }, { hold = 14 } } end }',
        TAUNT("twelve", 0.3)],
    "remy": [
        'SP.make("remy", "cold_blue_kick", "LK", "approach", { range = { 100, 170 }, rate = 0.04, cd = 180 })',
        TAUNT("remy", 0.2)],
    "q": [
        'SP.make("q", "dashing_head_attack", "LP", "approach", { range = { 110, 185 }, rate = 0.04, cd = 180 })',
        TAUNT("q", 0.5)],
    "necro": [
        'SP.make("necro", "flying_viper", "LP", "approach", { range = { 100, 170 }, rate = 0.03, cd = 180 })',
        TAUNT("necro", 0.25)],
    "elena": [
        'SP.make("elena", "spin_sides", "LK", "poke", { range = { 90, 160 }, rate = 0.04, cd = 150 })',
        'SP.make("elena", "rhino_horn", "LK", "approach", { range = { 120, 175 }, rate = 0.03, cd = 180 })',
        TAUNT("elena", 0.2)],
    "ibuki": [
        'SP.make("ibuki", "tsumuji", "LK", "poke", { range = { 110, 190 }, rate = 0.04, cd = 150 })',
        'SP.make("ibuki", "hien", "LK", "approach", { range = { 110, 180 }, rate = 0.03, cd = 180 })',
        TAUNT("ibuki", 0.15)],
    "sean": [
        'SP.make("sean", "tornado", "LK", "poke", { range = { 80, 130 }, rate = 0.03, cd = 180 })',
        'SP.make("sean", "ryuubikyaku", "LK", "approach", { range = { 120, 180 }, rate = 0.03, cd = 180 })',
        TAUNT("sean", 0.2)],
}

REQ = 'local SP = require("games.sfiii3.chars.sp")\n'
for char, entries in SPECIALS.items():
    path = os.path.join(D, char + ".lua")
    src = open(path, encoding="utf-8").read()
    if REQ not in src:
        src = src.replace("local M = input_lib.motion\n", "local M = input_lib.motion\n" + REQ, 1)
    block = "\t-- especiales de identidad por rol (tools/add_specials.py)\n\tspecials = SP.list(\n\t\t" + \
            ",\n\t\t".join(entries) + "\n\t),\n"
    src = re.sub(r"\t-- especiales de identidad por rol \(tools/add_specials\.py\)\n\tspecials = SP\.list\(.*?\n\t\),\n", "",
                 src, flags=re.S)
    i = src.rstrip().rfind("}")
    src = src[:i] + block + src[i:]
    open(path, "w", encoding="utf-8").write(src)
    print(char, len(entries))
