class_name DraftOffer
extends RefCounted
## One card in the hand for a draft move. A card always gives the same units;
## favor can bless it (more units) or, at full favor, turn it into an evolution.

enum Kind { ADD, EVOLVE }

var kind: Kind
var unit_id: StringName
## Units gained (ADD). 0 for EVOLVE.
var amount: int
## 0 = normal, 1 = blessed (x units), 2 = evolution. Tiers 1-2 cost favor when played.
var tier: int


func _init(p_kind: Kind = Kind.ADD, p_unit: StringName = &"", p_amount: int = 0, p_tier: int = 0) -> void:
	kind = p_kind
	unit_id = p_unit
	amount = p_amount
	tier = p_tier


func apply(army: Army) -> void:
	if kind == Kind.EVOLVE:
		army.evolve(unit_id)
	else:
		army.add(unit_id, amount)


func favor_cost(cfg: GameConfig) -> int:
	return [0, cfg.bless_cost, cfg.favor_max][tier]


func label() -> String:
	var unit_name := GameDB.unit(unit_id).display_name
	if kind == Kind.EVOLVE:
		return "Ewolucja: %s" % unit_name
	return "+%d %s" % [amount, unit_name]


func to_dict() -> Dictionary:
	return {"kind": kind, "unit": unit_id, "amount": amount, "tier": tier}


## Draws a hand from the deck. Each card may be blessed with chance favor/favor_max.
static func generate(deck: Array[StringName], army: Army, favor: int, cfg: GameConfig, rng: RandomNumberGenerator) -> Array[DraftOffer]:
	var pool := deck.duplicate()
	var hand: Array[StringName] = []
	while hand.size() < cfg.hand_size and not pool.is_empty():
		hand.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	var offers: Array[DraftOffer] = []
	for unit_id in hand:
		var base_amount := GameDB.unit(unit_id).count_per_pick
		var blessed := favor >= cfg.bless_cost and rng.randf() < float(favor) / cfg.favor_max
		if blessed and favor >= cfg.favor_max and army.count(unit_id) > 0 \
				and army.level(unit_id) < cfg.max_level and rng.randf() < cfg.evolution_chance:
			offers.append(DraftOffer.new(Kind.EVOLVE, unit_id, 0, 2))
		elif blessed:
			offers.append(DraftOffer.new(Kind.ADD, unit_id, base_amount * cfg.bless_unit_mult, 1))
		else:
			offers.append(DraftOffer.new(Kind.ADD, unit_id, base_amount, 0))
	return offers
