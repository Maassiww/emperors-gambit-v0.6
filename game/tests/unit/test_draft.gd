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


func test_blessing_doubles_units() -> void:
	GameDB.ensure_loaded()
	var rng := _rng(5)
	var blessed := 0
	for i in 100:
		for o in DraftOffer.generate(deck, Army.new(), 80, GameDB.config, rng):
			if o.tier == 1:
				blessed += 1
				assert_eq(o.amount, GameDB.unit(o.unit_id).count_per_pick * GameDB.config.bless_unit_mult)
	assert_true(blessed > 0, "no blessed cards at favor 80")


func test_evolution_only_at_full_favor() -> void:
	GameDB.ensure_loaded()
	var army := Army.new()
	for id in deck:
		army.add(id, 3)
	var rng := _rng(6)
	var evolutions := 0
	for i in 200:
		for o in DraftOffer.generate(deck, army, 99, GameDB.config, rng):
			assert_true(o.tier < 2, "evolution below full favor")
		for o in DraftOffer.generate(deck, army, GameDB.config.favor_max, GameDB.config, rng):
			if o.tier == 2:
				evolutions += 1
	assert_true(evolutions > 0, "no evolutions at full favor")
