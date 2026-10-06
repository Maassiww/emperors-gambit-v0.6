#!/usr/bin/env python3
"""Writes game/data/units/*.tres from the UNITS table below.

The .tres files are what the game loads; this script only keeps them consistent.
Edit numbers here (or in the editor) and re-run: python3 tools/gen_units.py
"""
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "game", "data", "units")

MELEE, RANGED, SPECIAL = 0, 1, 2
HEAVY, LIGHT, RAPID, SLOW, FLYER, SUPPORT, SPEC = range(7)
K = dict(TAUNT=0, TELEPORT_BACKLINE=1, EXECUTE=2, STUN_PULSE=3, AURA=4, BUILD=5, KAMIKAZE=6, DEATH_BLAST=7, MARK_ON_HIT=8)
ALL, FACTION, MELEE_ONLY = 0, 1, 2


def unit(id, name, faction, cls, role, count, hp, armor, dmg, interval, rng, speed, size, **kw):
    d = dict(id=id, display_name=name, faction=faction, unit_class=cls, role=role, count_per_pick=count,
             hp=hp, armor=armor, damage=dmg, attack_interval=interval, attack_range=rng, speed=speed, size=size)
    d.update(kw)
    return d


def evo(base, id, name, **changes):
    """Evolved form: copy of the base card with changes; never drafted directly."""
    d = dict(base)
    d.pop("evolves_to", None)
    d.update(id=id, display_name=name, is_evolution=True)
    d.update(changes)
    return d


def tr(kind, **kw):
    kw["kind"] = K[kind]
    return kw


U = []
def add(d):
    U.append(d)
    return d

# --- Humans: few units per card, strong stats ----------------------------------------------
b = add(unit("bastion", "Bastion", "humans", MELEE, HEAVY, 1, 490, 8, 22, 1.0, 30, 35, 13,
             blurb="Tank. Prowokacja: wrogowie obok muszą bić jego.",
             traits=[tr("TAUNT", label="Prowokacja", radius=60)], evolves_to="bastion_pretorianin"))
add(evo(b, "bastion_pretorianin", "Pretorianin", hp=785, armor=10, damage=33, size=15,
        traits=[tr("TAUNT", label="Prowokacja", radius=85)]))
b = add(unit("szturmowiec", "Szturmowiec", "humans", MELEE, LIGHT, 2, 140, 3, 44, 0.8, 30, 90, 13,
             blurb="Szybki DPS w zwarciu.", evolves_to="szturmowiec_elity"))
add(evo(b, "szturmowiec_elity", "Szturmowiec Elity", hp=210, armor=4, damage=68, size=15))
b = add(unit("strzelec", "Strzelec", "humans", RANGED, RAPID, 2, 140, 3, 8, 0.25, 220, 60, 13,
             blurb="Szybki ostrzał. Słaby na pancerz.", evolves_to="strzelec_weteran"))
add(evo(b, "strzelec_weteran", "Strzelec Weteran", hp=210, armor=4, damage=13, size=15))
b = add(unit("lancer", "Lancer", "humans", RANGED, SLOW, 1, 160, 3, 110, 2.0, 360, 0, 13, armor_pierce=True,
             blurb="Snajper. Stoi w miejscu, przebija pancerz.", evolves_to="lancer_ciezki"))
add(evo(b, "lancer_ciezki", "Ciężki Lancer", hp=256, armor=4, damage=165, size=15))
b = add(unit("medyk", "Medyk polowy", "humans", SPECIAL, SUPPORT, 1, 180, 2, 25, 1.0, 160, 45, 13, glyph="+",
             blurb="Leczy najbardziej rannego sojusznika.", evolves_to="archimedyk"))
add(evo(b, "archimedyk", "Archimedyk", hp=288, armor=3, damage=43, size=15))
b = add(unit("zabojca", "Zabójca", "humans", SPECIAL, SPEC, 2, 250, 4, 40, 0.7, 28, 95, 12, glyph="Z",
             targets_backline=True, power_bonus=1.3,
             blurb="Po 2 s skacze za tyły wroga i poluje na ostatnią linię. Dobija rannych.",
             traits=[tr("TELEPORT_BACKLINE", label="Skok", delay=2.0),
                     tr("EXECUTE", label="Egzekucja", power=50, threshold_pct=35)],
             evolves_to="mistrz_ostrzy"))
add(evo(b, "mistrz_ostrzy", "Mistrz Ostrzy", hp=375, armor=5, damage=60, size=14,
        traits=[tr("TELEPORT_BACKLINE", label="Skok", delay=1.0),
                tr("EXECUTE", label="Egzekucja", power=75, threshold_pct=35)]))
b = add(unit("psionik", "Psionik", "humans", SPECIAL, SPEC, 1, 210, 2, 14, 1.0, 200, 45, 12, glyph="P",
             power_bonus=2.0, blurb="Co 6 s ogłusza największą grupę wrogów.",
             traits=[tr("STUN_PULSE", label="Ogłuszenie", delay=3.0, period=6.0, cast_range=260, radius=60,
                        duration=1.5, power=20)],
             evolves_to="arcypsionik"))
add(evo(b, "arcypsionik", "Arcypsionik", hp=315, armor=3, damage=21, size=14,
        traits=[tr("STUN_PULSE", label="Ogłuszenie", delay=2.5, period=5.0, cast_range=280, radius=80,
                   duration=2.0, power=30)]))
b = add(unit("chorazy", "Chorąży", "humans", SPECIAL, SPEC, 1, 300, 4, 20, 1.0, 130, 50, 13, glyph="C",
             power_bonus=1.8, blurb="Aura Chorągiew: ludzie w pobliżu +30% obrażeń i +3 pancerza.",
             traits=[tr("AURA", label="Chorągiew", radius=180, affects=FACTION, buff_damage_pct=30, buff_armor=3)],
             evolves_to="chorazy_gwardii"))
add(evo(b, "chorazy_gwardii", "Chorąży Gwardii", hp=450, armor=5, damage=30, size=15,
        traits=[tr("AURA", label="Chorągiew", radius=220, affects=FACTION, buff_damage_pct=40, buff_armor=4)]))

# --- Orks: many units per card, weak stats ---------------------------------------------------
b = add(unit("pancerniak", "Pancerniak", "orks", MELEE, HEAVY, 2, 300, 6, 16, 1.1, 30, 35, 11,
             blurb="Tank w złomowym pancerzu.", evolves_to="megapancerniak"))
add(evo(b, "megapancerniak", "Megapancerniak", hp=480, armor=8, damage=24, size=13))
b = add(unit("szaleniec", "Szaleniec", "orks", MELEE, LIGHT, 5, 80, 0, 22, 0.6, 25, 100, 9,
             blurb="Tania, szybka masa do zwarcia.", evolves_to="berserker"))
add(evo(b, "berserker", "Berserker", hp=120, damage=33, size=11))
b = add(unit("siekacz", "Siekacz", "orks", RANGED, RAPID, 4, 66, 0, 5, 0.3, 190, 60, 9,
             blurb="Masa szybkiego ostrzału.", evolves_to="megasiekacz"))
add(evo(b, "megasiekacz", "Megasiekacz", hp=105, damage=8, size=11))
b = add(unit("rakieciarz", "Rakieciarz", "orks", RANGED, SLOW, 2, 70, 1, 55, 2.2, 340, 0, 9, splash_radius=50,
             blurb="Artyleria obszarowa. Stoi w miejscu.", evolves_to="rakietowy_boss"))
add(evo(b, "rakietowy_boss", "Rakietowy Boss", hp=112, armor=2, damage=82, size=11))
b = add(unit("lotniak", "Lotniak", "orks", SPECIAL, FLYER, 3, 80, 1, 16, 0.8, 30, 110, 9, glyph="L",
             targets_backline=True, blurb="Lata nad frontem, poluje na tyły. Wybucha po śmierci.",
             traits=[tr("DEATH_BLAST", label="Wybuch", radius=45, power=30)], evolves_to="as_lotniak"))
add(evo(b, "as_lotniak", "As Lotników", hp=120, armor=2, damage=26, size=11,
        traits=[tr("DEATH_BLAST", label="Wybuch", radius=55, power=45)]))
b = add(unit("konstruktor", "Konstruktor", "orks", SPECIAL, SPEC, 2, 110, 1, 9, 0.8, 110, 55, 10, glyph="K",
             power_bonus=2.0, blurb="Idąc do przodu, co 7 s stawia wieżyczkę (maks. 2 na konstruktora).",
             traits=[tr("BUILD", label="Wieżyczka", delay=2.0, period=7.0, max_count=2, summon="wiezyczka")],
             evolves_to="mekaszef"))
add(evo(b, "mekaszef", "Mekaszef", hp=165, armor=2, damage=14, size=12,
        traits=[tr("BUILD", label="Wieżyczka", delay=1.5, period=5.0, max_count=3, summon="wiezyczka_ciezka")]))
add(unit("wiezyczka", "Wieżyczka", "orks", RANGED, RAPID, 1, 100, 2, 6, 0.35, 210, 0, 9, glyph="W",
         is_summon=True, blurb="Przywołana przez Konstruktora."))
add(unit("wiezyczka_ciezka", "Ciężka wieżyczka", "orks", RANGED, RAPID, 1, 150, 3, 9, 0.35, 230, 0, 10, glyph="W",
         is_summon=True, blurb="Przywołana przez Mekaszefa."))
b = add(unit("bombowiec", "Bombowiec", "orks", SPECIAL, SPEC, 3, 100, 1, 90, 1.0, 22, 120, 9, glyph="B",
             ground_only=True, armor_pierce=True,
             blurb="Wbiega w największą grupę i wybucha (ignoruje pancerz). Korozja: −pancerz.",
             traits=[tr("KAMIKAZE", label="Korozja", radius=70, stacks=2, duration=6.0)],
             evolves_to="megabombowiec"))
add(evo(b, "megabombowiec", "Megabombowiec", hp=150, armor=2, damage=150, size=11,
        traits=[tr("KAMIKAZE", label="Korozja", radius=85, stacks=3, duration=8.0)]))
b = add(unit("szaman", "Szaman", "orks", SPECIAL, SPEC, 1, 170, 1, 14, 1.0, 120, 55, 11, glyph="S",
             power_bonus=1.8, blurb="Aura Wojenny wrzask: orkowie w pobliżu +25% szybkości ataku, +20% ruchu.",
             traits=[tr("AURA", label="Wojenny wrzask", radius=160, affects=FACTION, buff_attack_speed_pct=25,
                        buff_move_pct=20)],
             evolves_to="wielki_szaman"))
add(evo(b, "wielki_szaman", "Wielki Szaman", hp=255, armor=2, damage=21, size=13,
        traits=[tr("AURA", label="Wojenny wrzask", radius=200, affects=FACTION, buff_attack_speed_pct=35,
                   buff_move_pct=25)]))

# --- Neutral: regular cards; the Contract level (factions on the board) strengthens one effect ----
# Level I: 1 faction among the owner's units (neutral excluded), level II: 2 factions.
def melee_contract(lvl1, lvl2, radius):
    return [tr("AURA", label="Kontrakt I", radius=radius, affects=MELEE_ONLY, buff_damage_pct=lvl1,
               min_factions=1, max_factions=2),
            tr("AURA", label="Kontrakt II", radius=radius, affects=MELEE_ONLY, buff_damage_pct=lvl2,
               min_factions=2)]


def bounty(lvl1, lvl2, dur1, dur2):
    return [tr("MARK_ON_HIT", label="Oznaczenie", power=lvl1, duration=dur1, min_factions=1, max_factions=2),
            tr("MARK_ON_HIT", label="Oznaczenie", power=lvl2, duration=dur2, min_factions=2)]


b = add(unit("najemnik", "Najemnik", "neutral", MELEE, LIGHT, 2, 210, 3, 30, 0.7, 28, 85, 11,
             blurb="Kontrakt: melee w pobliżu +15% obrażeń (1 frakcja na planszy), +30% (2 frakcje).",
             traits=melee_contract(15, 30, 150), power_bonus=1.2, evolves_to="kapitan_najemnikow"))
add(evo(b, "kapitan_najemnikow", "Kapitan Najemników", hp=315, armor=4, damage=45, size=13,
        traits=melee_contract(20, 40, 180)))
b = add(unit("lowca", "Łowca Nagród", "neutral", RANGED, RAPID, 2, 110, 1, 9, 0.35, 210, 60, 11,
             blurb="Kontrakt: trafiony cel dostaje +15% obrażeń przez 3 s (1 frakcja), +30% przez 5 s (2 frakcje).",
             traits=bounty(15, 30, 3.0, 5.0), power_bonus=1.2, evolves_to="mistrz_lowow"))
add(evo(b, "mistrz_lowow", "Mistrz Łowów", hp=165, armor=2, damage=14, size=13,
        traits=bounty(20, 40, 3.0, 6.0)))


# --- writer ----------------------------------------------------------------------------------
ORDER = ["id", "display_name", "faction", "unit_class", "role", "count_per_pick", "hp", "armor", "damage",
         "attack_interval", "attack_range", "speed", "armor_pierce", "splash_radius", "size", "targets_backline",
         "ground_only", "traits", "blurb", "glyph", "power_bonus", "evolves_to", "is_evolution", "is_summon"]
NAMES = {"id", "faction", "evolves_to", "summon"}


def val(k, v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        esc = v.replace("\\", "\\\\").replace('"', '\\"')
        return ('&"%s"' if k in NAMES else '"%s"') % esc
    if isinstance(v, float):
        return repr(v)
    return str(v)


def write(d):
    lines = ['[gd_resource type="Resource" script_class="UnitData" format=3]', "",
             '[ext_resource type="Script" path="res://core/unit_data.gd" id="1"]']
    traits = d.get("traits", [])
    if traits:
        lines.append('[ext_resource type="Script" path="res://core/trait_data.gd" id="2"]')
    lines.append("")
    for i, t in enumerate(traits):
        lines.append('[sub_resource type="Resource" id="trait_%d"]' % i)
        lines.append('script = ExtResource("2")')
        for k, v in t.items():
            lines.append("%s = %s" % (k, val(k, v)))
        lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("1")')
    for k in ORDER:
        if k not in d:
            continue
        if k == "traits":
            if traits:
                refs = ", ".join('SubResource("trait_%d")' % i for i in range(len(traits)))
                lines.append('traits = Array[ExtResource("2")]([%s])' % refs)
            continue
        lines.append("%s = %s" % (k, val(k, d[k])))
    unknown = set(d) - set(ORDER)
    assert not unknown, (d["id"], unknown)
    with open(os.path.join(OUT, d["id"] + ".tres"), "w") as f:
        f.write("\n".join(lines) + "\n")


for d in U:
    write(d)
print("wrote %d units" % len(U))
