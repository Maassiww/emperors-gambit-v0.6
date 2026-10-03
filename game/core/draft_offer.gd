class_name DraftOffer
extends RefCounted
## One of the options shown during a draft move.

enum Kind { ADD, MULTIPLY, EVOLVE }

var kind: Kind
var unit_id: StringName
## Units gained (ADD/MULTIPLY). 0 for EVOLVE.
var amount: int
## 0 = basic, 1 = boosted, 2 = evolution. Higher tiers cost favor when picked.
var tier: int


func _init(p_kind: Kind = Kind.ADD, p_unit: StringName = &"", p_amount: int = 0, p_tier: int = 0) -> void:
	kind = p_kind
	unit_id = p_unit
	amount = p_amount
	tier = p_tier


func apply(army: Army) -> void:
	match kind:
		Kind.ADD, Kind.MULTIPLY:
			army.add(unit_id, amount)
		Kind.EVOLVE:
			army.evolve(unit_id)


func label() -> String:
	var unit_name := GameDB.unit(unit_id).display_name
	match kind:
		Kind.ADD:
			return "+%d %s" % [amount, unit_name]
		Kind.MULTIPLY:
			return "2x %s (+%d)" % [unit_name, amount]
		_:
			return "Ewolucja: %s" % unit_name


func to_dict() -> Dictionary:
	return {"kind": kind, "unit": unit_id, "amount": amount, "tier": tier}


## Builds the options for one draft move. Higher favor -> better tiers more often.
static func generate(deck: Array[StringName], army: Army, favor: int, cfg: GameConfig, rng: RandomNumberGenerator) -> Array[DraftOffer]:
	var offers: Array[DraftOffer] = []
	var used := {}
	for slot in cfg.offers_per_move:
		var offer: DraftOffer
		for attempt in 6:
			offer = _roll(deck, army, favor, cfg, rng)
			var key := "%s/%d" % [offer.unit_id, offer.kind]
			if not used.has(key):
				used[key] = true
				break
		offers.append(offer)
	return offers


static func _roll(deck: Array[StringName], army: Army, favor: int, cfg: GameConfig, rng: RandomNumberGenerator) -> DraftOffer:
	var unit_id := deck[rng.randi_range(0, deck.size() - 1)]
	var base_amount := GameDB.unit(unit_id).count_per_pick
	var tier := 0
	if rng.randf() < favor * cfg.tier1_chance_per_favor:
		tier = 1
		if rng.randf() < (favor - cfg.tier2_favor_threshold) * cfg.tier2_chance_per_favor:
			tier = 2
	if tier == 2:
		if army.count(unit_id) > 0 and army.level(unit_id) < cfg.max_level:
			return DraftOffer.new(Kind.EVOLVE, unit_id, 0, 2)
		tier = 1
	var have := army.count(unit_id)
	if tier == 0 and have > 0 and rng.randf() < cfg.multiply_offer_chance:
		var added := mini(have, base_amount * cfg.multiply_cap_picks)
		return DraftOffer.new(Kind.MULTIPLY, unit_id, added, 0)
	var amount := base_amount * (cfg.tier1_amount_mult if tier == 1 else 1)
	return DraftOffer.new(Kind.ADD, unit_id, amount, tier)
