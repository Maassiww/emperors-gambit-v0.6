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


func test_purity_by_foreign_cards() -> void:
	var cfg := GameDB.config
	var citadel := GameDB.base(&"citadel")
	var pure: Array[StringName] = [&"bastion", &"szturmowiec", &"strzelec", &"lancer", &"medyk"]
	assert_eq(citadel.purity_pct(pure, cfg), cfg.purity_pct_by_foreign[0])
	var one := pure.duplicate()
	one[0] = &"najemnik"
	assert_eq(citadel.purity_pct(one, cfg), cfg.purity_pct_by_foreign[1], "neutral counts as foreign")
	var two := one.duplicate()
	two[1] = &"pancerniak"
	assert_eq(citadel.purity_pct(two, cfg), cfg.purity_pct_by_foreign[2])
	var three := two.duplicate()
	three[2] = &"siekacz"
	assert_eq(citadel.purity_pct(three, cfg), 0)


func test_citadel_reduction_whole_army_scaled_by_purity() -> void:
	var armies: Array[Army] = [_army({&"szaleniec": 1}), _army({&"pancerniak": 1, &"bastion": 1})]
	var bases: Array[BaseData] = [GameDB.base(&"war_camp"), GameDB.base(&"citadel")]
	var full := BattleSim.new(armies, bases, GameDB.config, RandomNumberGenerator.new(), [100, 100] as Array[int])
	var part := BattleSim.new(armies, bases, GameDB.config, RandomNumberGenerator.new(), [100, 40] as Array[int])
	var v := GameDB.base(&"citadel").passive_value
	assert_eq(full.damage_reduction_pct(1), v)
	assert_eq(part.damage_reduction_pct(1), v * 40 / 100)
	var ork := full.units[1] if full.units[1].data.id == &"pancerniak" else full.units[2]
	assert_true(full._damage(full.units[0], ork, 1000) < part._damage(part.units[0], part.units[ork.uid], 1000),
		"foreign units protected too, more at full purity")


func test_rage_from_any_ally_scaled_by_purity() -> void:
	var armies: Array[Army] = [_army({&"szaleniec": 2, &"bastion": 1}), _army({})]
	var bases: Array[BaseData] = [GameDB.base(&"war_camp"), GameDB.base(&"citadel")]
	var sim := BattleSim.new(armies, bases, GameDB.config, RandomNumberGenerator.new(), [70, 100] as Array[int])
	var bastion: BattleSim.SimUnit = sim.units.filter(func(u: BattleSim.SimUnit) -> bool: return u.data.id == &"bastion")[0]
	var dead: BattleSim.SimUnit = sim.units.filter(func(u: BattleSim.SimUnit) -> bool: return u.data.id == &"szaleniec")[0]
	dead.hp = 0
	sim.tick = 5
	dead.breath_until = 1  # last breath already over
	sim._apply_hits([] as Array[Array])
	assert_eq(bastion.rage, 1, "human under ork base gets rage too")
	assert_eq(sim.rage_pct(bastion), GameDB.base(&"war_camp").rage_pct_per_stack * 70 / 100)


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
