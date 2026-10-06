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
	# Percent armor: 8 points x 6% = -48%, so 5 dmg -> 2.
	assert_eq(sim._damage(siekacz, bastion, siekacz.damage), 2)


func test_armor_reduction_is_capped() -> void:
	var cfg := GameDB.config
	assert_eq(UnitData.armor_pass_pct(0, cfg), 100)
	assert_eq(UnitData.armor_pass_pct(5, cfg), 100 - 5 * cfg.armor_pct_per_point)
	assert_eq(UnitData.armor_pass_pct(50, cfg), 100 - cfg.armor_max_reduction_pct)


func test_pierce_ignores_armor() -> void:
	var sim := _sim({&"lancer": 1}, {&"pancerniak": 1}, 1, [&"war_camp", &"war_camp"])
	assert_eq(sim._damage(sim.units[0], sim.units[1], sim.units[0].damage), GameDB.unit(&"lancer").damage)


func test_citadel_armor_only_for_humans() -> void:
	var sim := _sim({&"bastion": 1, &"pancerniak": 1}, {}, 1, [&"citadel", &"war_camp"])
	for u in sim.units:
		if u.data.id == &"bastion":
			assert_eq(u.armor, 8 + GameDB.base(&"citadel").passive_value, "bastion armor")
		else:
			assert_eq(u.armor, u.data.armor, "ork armor under human base")


func test_healers_only_end_immediately_by_hp() -> void:
	var r := _sim({&"medyk": 2}, {&"medyk": 1}).run()
	assert_eq(r.ticks, 1, "stalemate not detected")
	assert_eq(r.outcome, BattleSim.Outcome.HP)
	assert_eq(r.winner, 0)


func test_battle_ends_by_elimination() -> void:
	# Before overtime existed this matchup could time out; now someone must die.
	var r := _sim({&"bastion": 3, &"medyk": 2}, {&"pancerniak": 4}).run()
	assert_eq(r.outcome, BattleSim.Outcome.ELIMINATION)


func test_overtime_raises_damage() -> void:
	var sim := _sim({&"bastion": 1}, {&"pancerniak": 1})
	assert_eq(sim.overtime_pct(), 100)
	sim.tick = int((GameDB.config.overtime_after_seconds + 2.0) * GameDB.config.ticks_per_second)
	assert_eq(sim.overtime_pct(), 100 + 2 * GameDB.config.overtime_damage_pct_per_second)


func test_formation_order_front_to_back() -> void:
	var sim := _sim({&"lancer": 1, &"bastion": 1, &"medyk": 1, &"strzelec": 1, &"szturmowiec": 1}, {})
	var y := {}
	for u in sim.units:
		y[u.data.id] = u.y
	# Player 0 faces up: smaller y = closer to the front.
	assert_true(y[&"bastion"] < y[&"szturmowiec"], "heavy behind light")
	assert_true(y[&"szturmowiec"] < y[&"strzelec"], "light melee behind ranged")
	assert_true(y[&"strzelec"] < y[&"lancer"], "rapid behind slow")
	assert_true(y[&"lancer"] < y[&"medyk"], "special not last")


func test_regular_units_target_nearest() -> void:
	var sim := _sim({&"szturmowiec": 1}, {&"bastion": 1, &"strzelec": 1})
	var szturmowiec := sim.units[0]
	assert_eq(sim.units[sim._pick_enemy(szturmowiec)].data.id, &"bastion", "light melee skipped the front")
