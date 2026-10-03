class_name Bot
extends RefCounted
## Simple heuristic opponent. Sees only Match.view_for(), exactly like a human player.

## Ready-made loadouts: the bot's decks in the prototype and archetypes for balance runs.
const PRESETS := [
	{"name": "Ludzie: mur", "base": &"citadel",
		"deck": [&"bastion", &"strzelec", &"lancer", &"medyk", &"chorazy"]},
	{"name": "Ludzie: łowcy", "base": &"citadel",
		"deck": [&"szturmowiec", &"strzelec", &"lancer", &"zabojca", &"psionik"]},
	{"name": "Orkowie: horda", "base": &"war_camp",
		"deck": [&"pancerniak", &"szaleniec", &"siekacz", &"szaman", &"bombowiec"]},
	{"name": "Orkowie: złom", "base": &"war_camp",
		"deck": [&"pancerniak", &"siekacz", &"rakieciarz", &"konstruktor", &"lotniak"]},
	{"name": "Mix: najemnicy", "base": &"citadel",
		"deck": [&"bastion", &"szaleniec", &"siekacz", &"lancer", &"najemnik"]},
	{"name": "Mix: kontrola", "base": &"war_camp",
		"deck": [&"pancerniak", &"strzelec", &"rakieciarz", &"psionik", &"najemnik"]},
]

## 0 = always the best-scored option, higher = more random.
var noise := 0.15
var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0, p_noise: float = 0.15) -> void:
	rng.seed = seed_value
	noise = p_noise


## Returns an offer index or Match.HOLD.
func choose(view: Dictionary) -> int:
	var me: Dictionary = view.me
	var opp: Dictionary = view.opponent
	var offers: Array = me.offers
	if _should_hold(view):
		return Match.HOLD
	var best := 0
	var best_score := -INF
	for i in offers.size():
		var score := _score(offers[i], me.army, opp.army) * (1.0 + rng.randf_range(-noise, noise))
		if score > best_score:
			best = i
			best_score = score
	return best


func _should_hold(view: Dictionary) -> bool:
	var me: Dictionary = view.me
	var opp: Dictionary = view.opponent
	var cfg := GameDB.config
	if me.favor >= cfg.favor_max - cfg.favor_per_hold / 2:
		return false
	var mine: float = (me.army as Army).power()
	var theirs: float = (opp.army as Army).power()
	# Comfortable lead (in HP or known strength): invest in favor.
	if me.hp > opp.hp and mine > theirs * 1.3 and rng.randf() < 0.5:
		return true
	return view.round > 1 and mine > theirs * 1.6 and rng.randf() < 0.3


## A legal random deck. Biased towards pure decks so balance runs see every archetype.
static func random_deck(rng: RandomNumberGenerator) -> Array[StringName]:
	var cfg := GameDB.config
	var all := GameDB.card_ids_sorted()
	var pool: Array[StringName] = []
	var deck: Array[StringName] = []
	var mode := rng.randi_range(0, 2)
	if mode == 2:
		pool = all.duplicate()
	else:
		var factions := [&"humans", &"orks"]
		var f: StringName = factions[rng.randi_range(0, 1)]
		pool.assign(all.filter(func(id: StringName) -> bool: return GameDB.unit(id).faction == f))
		if mode == 1:
			deck.append(&"najemnik")
	while deck.size() < cfg.deck_size and not pool.is_empty():
		var id: StringName = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var specials := deck.filter(func(d: StringName) -> bool: return GameDB.unit(d).is_special()).size()
		if id in deck or (GameDB.unit(id).is_special() and specials >= cfg.max_specials_in_deck):
			continue
		deck.append(id)
	return deck


func _score(offer: DraftOffer, army: Army, opp_army: Army) -> float:
	var data := GameDB.unit(army.resolve(offer.unit_id))
	var value: float
	if offer.kind == DraftOffer.Kind.EVOLVE:
		value = army.count(offer.unit_id) * (GameDB.unit(data.evolves_to).power() - data.power())
	else:
		value = offer.amount * data.power()
	return value * _counter_factor(data, opp_army) * _composition_factor(data, offer, army)


## Purity auras want no foreign card types; neutral contracts want more factions.
func _composition_factor(data: UnitData, offer: DraftOffer, army: Army) -> float:
	var types := {}
	var factions := {}
	for id in army.counts:
		var f := GameDB.unit(id).faction
		types[f] = types.get(f, 0) + 1
		if f != UnitData.NEUTRAL:
			factions[f] = true
	var f := 1.0
	var new_type := offer.kind == DraftOffer.Kind.ADD and army.count(offer.unit_id) == 0
	var aura := data.get_trait(TraitData.Kind.AURA)
	if aura != null and aura.scales_with_purity:
		var foreign := 0
		for faction in types:
			if faction != data.faction:
				foreign += types[faction]
		f *= [1.0, 0.6, 0.3][mini(foreign, 2)]
	if new_type:
		# Adding a foreign type weakens our purity auras.
		for id in army.counts:
			var u := GameDB.unit(id)
			var a := u.get_trait(TraitData.Kind.AURA)
			if a != null and a.scales_with_purity and u.faction != data.faction:
				f *= 0.7
				break
		if data.faction != UnitData.NEUTRAL and not factions.has(data.faction) and types.has(UnitData.NEUTRAL):
			f *= 1.25
	if data.faction == UnitData.NEUTRAL:
		f *= [0.6, 1.0, 1.3][mini(factions.size(), 2)]
	return f


## Bonus for units that counter what the opponent showed at the last reveal.
func _counter_factor(data: UnitData, opp: Army) -> float:
	var total := opp.total()
	if total == 0:
		return 1.0
	var flyers := 0
	var armor_sum := 0
	var backline := 0
	var divers := 0
	for id in opp.counts:
		var u := GameDB.unit(id)
		armor_sum += u.armor * opp.counts[id]
		if u.is_flying():
			flyers += opp.counts[id]
		if u.unit_class != UnitData.UnitClass.MELEE and not u.is_flying():
			backline += opp.counts[id]
		if u.targets_backline or u.get_trait(TraitData.Kind.KAMIKAZE) != null:
			divers += opp.counts[id]
	var flyer_share := float(flyers) / total
	var avg_armor := float(armor_sum) / total
	var f := 1.0
	if data.get_trait(TraitData.Kind.STUN_PULSE) != null or data.get_trait(TraitData.Kind.KAMIKAZE) != null:
		f *= 1.0 + minf(total, 30) / 60.0
	if data.get_trait(TraitData.Kind.TELEPORT_BACKLINE) != null:
		f *= 1.0 + float(backline) / total
	if data.get_trait(TraitData.Kind.TAUNT) != null:
		f *= 1.0 + float(divers) / total
	if data.armor_pierce:
		f *= 1.0 + avg_armor / 8.0
	if data.role == UnitData.Role.RAPID and avg_armor > 4.0:
		f *= 0.7
	if data.splash_radius > 0:
		f *= 1.0 + minf(total, 30) / 60.0
	if data.can_hit_air():
		f *= 1.0 + 0.5 * flyer_share
	elif flyer_share > 0.4:
		f *= 0.6
	return f
