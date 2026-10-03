extends TestCase


func _army(counts: Dictionary) -> Army:
	var a := Army.new()
	for id in counts:
		a.add(id, counts[id])
	return a


func _sim(a: Dictionary, b: Dictionary, seed_value: int = 1, bases: Array = [&"citadel", &"war_camp"]) -> BattleSim:
	GameDB.ensure_loaded()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var armies: Array[Army] = [_army(a), _army(b)]
	var b2: Array[BaseData] = [GameDB.base(bases[0]), GameDB.base(bases[1])]
	return BattleSim.new(armies, b2, GameDB.config, rng)


func test_deterministic() -> void:
	var a := {&"bastion": 2, &"strzelec": 4, &"medyk": 1}
	var b := {&"szaleniec": 10, &"siekacz": 8, &"lotniak": 3}
	var r1 := _sim(a, b, 7).run()
	var r2 := _sim(a, b, 7).run()
	assert_eq(r1.ticks, r2.ticks, "ticks")
	assert_eq(r1.winner, r2.winner, "winner")
	assert_eq(r1.hp_left, r2.hp_left, "hp_left")
	assert_eq(r1.damage_dealt, r2.damage_dealt, "damage")


func test_empty_army_loses() -> void:
	var r := _sim({}, {&"siekacz": 1}).run()
	assert_eq(r.winner, 1)
	assert_eq(r.outcome, BattleSim.Outcome.ELIMINATION)


func test_both_empty_is_coin() -> void:
	var r := _sim({}, {}).run()
	assert_eq(r.outcome, BattleSim.Outcome.COIN)
	assert_true(r.winner in [0, 1])


func test_melee_cannot_hit_flyers() -> void:
	var r := _sim({&"bastion": 1}, {&"lotniak": 3}, 1, [&"war_camp", &"war_camp"]).run()
	assert_eq(r.damage_dealt[0], 0, "melee dealt damage to flyers")
	assert_eq(r.winner, 1)


func test_armor_reduces_rapid_fire() -> void:
	var sim := _sim({&"bastion": 1}, {&"siekacz": 1}, 1, [&"war_camp", &"war_camp"])
	var siekacz := sim.units[1]
	var bastion := sim.units[0]
	# 5 dmg vs 8 armor -> minimum 1 per shot.
	assert_eq(sim._damage_after_armor(siekacz, bastion), 1)


func test_pierce_ignores_armor() -> void:
	var sim := _sim({&"lancer": 1}, {&"pancerniak": 1}, 1, [&"war_camp", &"war_camp"])
	assert_eq(sim._damage_after_armor(sim.units[0], sim.units[1]), 90)


func test_citadel_armor_only_for_humans() -> void:
	var sim := _sim({&"bastion": 1, &"pancerniak": 1}, {}, 1, [&"citadel", &"war_camp"])
	for u in sim.units:
		if u.data.id == &"bastion":
			assert_eq(u.armor, 8 + GameDB.base(&"citadel").passive_value, "bastion armor")
		else:
			assert_eq(u.armor, 5, "ork armor under human base")


func test_battle_ends_within_time_limit() -> void:
	var r := _sim({&"medyk": 1}, {&"medyk": 1}).run()
	assert_true(r.ticks <= int(GameDB.config.battle_max_seconds * GameDB.config.ticks_per_second), "timeout")
