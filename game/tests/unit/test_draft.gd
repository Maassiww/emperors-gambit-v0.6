extends TestCase

var deck: Array[StringName] = [&"bastion", &"strzelec", &"siekacz", &"lancer", &"szaleniec"]


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_hand_is_distinct_cards_from_deck() -> void:
	GameDB.ensure_loaded()
	var rng := _rng(1)
	for i in 100:
		var offers := DraftOffer.generate(deck, Army.new(), 0, GameDB.config, rng)
		assert_eq(offers.size(), GameDB.config.hand_size)
		var seen := {}
		for o in offers:
			assert_true(o.unit_id in deck, "card outside deck")
			assert_true(not seen.has(o.unit_id), "duplicate card in hand")
			seen[o.unit_id] = true


func test_small_deck_shows_all_cards() -> void:
	GameDB.ensure_loaded()
	var small: Array[StringName] = [&"bastion", &"strzelec"]
	assert_eq(DraftOffer.generate(small, Army.new(), 0, GameDB.config, _rng(2)).size(), 2)


func test_card_value_is_fixed() -> void:
	GameDB.ensure_loaded()
	var army := Army.new()
	army.add(&"siekacz", 40)
	var rng := _rng(3)
	for i in 100:
		for o in DraftOffer.generate(deck, army, 0, GameDB.config, rng):
			assert_eq(o.amount, GameDB.unit(o.unit_id).count_per_pick, "card amount changed")


func test_no_blessing_below_cost() -> void:
	GameDB.ensure_loaded()
	var rng := _rng(4)
	for i in 200:
		for o in DraftOffer.generate(deck, Army.new(), GameDB.config.bless_cost - 1, GameDB.config, rng):
			assert_eq(o.tier, 0, "blessed below cost")


func test_at_most_one_special_card() -> void:
	GameDB.ensure_loaded()
	var army := Army.new()
	for id in deck:
		army.add(id, 3)
	var rng := _rng(5)
	var blessed := 0
	for favor in [60, 80, 99, 100]:
		for i in 100:
			var special := 0
			for o in DraftOffer.generate(deck, army, favor, GameDB.config, rng):
				if o.tier > 0:
					special += 1
				if o.tier == 1:
					blessed += 1
					assert_eq(o.amount, GameDB.unit(o.unit_id).count_per_pick * GameDB.config.bless_unit_mult)
			assert_true(special <= 1, "more than one special card")
	assert_true(blessed > 0, "no blessed cards")


func test_full_favor_always_offers_evolution() -> void:
	GameDB.ensure_loaded()
	var army := Army.new()
	for id in deck:
		army.add(id, 3)
	var rng := _rng(6)
	for i in 100:
		var evolutions := 0
		for o in DraftOffer.generate(deck, army, GameDB.config.favor_max, GameDB.config, rng):
			if o.tier == 2:
				evolutions += 1
		assert_eq(evolutions, 1, "full favor without exactly one evolution")
		for o in DraftOffer.generate(deck, army, 99, GameDB.config, rng):
			assert_true(o.tier < 2, "evolution below full favor")


func test_evolution_replaces_units_and_card() -> void:
	GameDB.ensure_loaded()
	var army := Army.new()
	army.add(&"strzelec", 4)
	army.evolve(&"strzelec")
	assert_eq(army.counts.get(&"strzelec", 0), 0, "base units left")
	assert_eq(army.counts[&"strzelec_weteran"], 4)
	army.add(&"strzelec", 2)
	assert_eq(army.counts[&"strzelec_weteran"], 6, "card should now add evolved units")
	assert_true(not army.can_evolve(&"strzelec"), "evolved twice")
	var offers := DraftOffer.generate([&"strzelec"] as Array[StringName], army, 0, GameDB.config, _rng(7))
	assert_eq(offers[0].produces, &"strzelec_weteran")
