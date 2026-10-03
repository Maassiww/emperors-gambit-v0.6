extends TestCase

var deck: Array[StringName] = [&"bastion", &"strzelec", &"siekacz"]


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_offer_count() -> void:
	GameDB.ensure_loaded()
	var offers := DraftOffer.generate(deck, Army.new(), 0, GameDB.config, _rng(1))
	assert_eq(offers.size(), GameDB.config.offers_per_move)


func test_zero_favor_only_basic() -> void:
	GameDB.ensure_loaded()
	var rng := _rng(2)
	for i in 200:
		for o in DraftOffer.generate(deck, Army.new(), 0, GameDB.config, rng):
			assert_eq(o.tier, 0, "tier at favor 0")
			assert_eq(o.kind, DraftOffer.Kind.ADD, "only ADD with empty army")


func test_high_favor_gives_upgrades() -> void:
	GameDB.ensure_loaded()
	var army := Army.new()
	for id in deck:
		army.add(id, 3)
	var rng := _rng(3)
	var tiers := [0, 0, 0]
	for i in 300:
		for o in DraftOffer.generate(deck, army, 100, GameDB.config, rng):
			tiers[o.tier] += 1
	assert_true(tiers[1] > 0, "no tier 1 at favor 100")
	assert_true(tiers[2] > 0, "no evolutions at favor 100")


func test_offers_only_from_deck() -> void:
	GameDB.ensure_loaded()
	var rng := _rng(4)
	for i in 100:
		for o in DraftOffer.generate(deck, Army.new(), 60, GameDB.config, rng):
			assert_true(o.unit_id in deck, "offer outside deck: %s" % o.unit_id)


func test_multiply_capped() -> void:
	GameDB.ensure_loaded()
	var army := Army.new()
	army.add(&"siekacz", 100)
	var rng := _rng(5)
	var cap := GameDB.unit(&"siekacz").count_per_pick * GameDB.config.multiply_cap_picks
	for i in 200:
		for o in DraftOffer.generate([&"siekacz"] as Array[StringName], army, 0, GameDB.config, rng):
			if o.kind == DraftOffer.Kind.MULTIPLY:
				assert_true(o.amount <= cap, "multiply over cap")
