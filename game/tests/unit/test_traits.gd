extends TestCase
## Specials, neutral contracts and the shared effect vocabulary.

const BASES := [&"war_camp", &"war_camp"]


func _army(counts: Dictionary) -> Army:
	var a := Army.new()
	for id in counts:
		a.add(id, counts[id])
	return a


func _sim(a: Dictionary, b: Dictionary, bases: Array = BASES) -> BattleSim:
	GameDB.ensure_loaded()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var armies: Array[Army] = [_army(a), _army(b)]
	var b2: Array[BaseData] = [GameDB.base(bases[0]), GameDB.base(bases[1])]
	return BattleSim.new(armies, b2, GameDB.config, rng)


func _first(sim: BattleSim, id: StringName, owner: int = -1) -> BattleSim.SimUnit:
	for u in sim.units:
		if u.data.id == id and (owner < 0 or u.owner == owner):
			return u
	return null


func _place(u: BattleSim.SimUnit, x: int, y: int) -> void:
	u.x = x * BattleSim.SCALE
	u.y = y * BattleSim.SCALE
	u.next_x = u.x
	u.next_y = u.y


func _steps(sim: BattleSim, seconds: float) -> void:
	for i in roundi(seconds * GameDB.config.ticks_per_second):
		sim.step()


# --- data integrity ----------------------------------------------------------

func test_every_card_has_an_evolution_of_its_faction() -> void:
	for id in GameDB.card_ids_sorted():
		var u := GameDB.unit(id)
		assert_true(u.evolves_to != &"", "%s has no evolution" % id)
		if u.evolves_to != &"":
			var e := GameDB.unit(u.evolves_to)
			assert_true(e.is_evolution, "%s evolution flag" % id)
			assert_eq(e.faction, u.faction, "%s evolution faction" % id)
		assert_true(u.blurb != "", "%s blurb" % id)


func test_summons_and_evolutions_are_not_cards() -> void:
	var cards := GameDB.card_ids_sorted()
	assert_true(not (&"wiezyczka" in cards), "turret drafted")
	assert_true(not (&"mistrz_ostrzy" in cards), "evolution drafted")
	assert_true(&"najemnik" in cards, "neutral card missing")


func test_deck_rules() -> void:
	assert_eq(GameDB.deck_error([&"bastion", &"strzelec", &"medyk", &"najemnik", &"lancer"]), "")
	assert_true(GameDB.deck_error([&"bastion", &"strzelec", &"medyk", &"zabojca", &"lancer"]) != "", "2 specials")
	assert_true(GameDB.deck_error([&"bastion", &"bastion", &"medyk", &"zabojca", &"lancer"]) != "", "duplicate")
	assert_true(GameDB.deck_error([&"bastion", &"strzelec"]) != "", "too small")
	assert_true(GameDB.deck_error([&"bastion", &"strzelec", &"medyk", &"zabojca", &"wiezyczka"]) != "", "summon")


# --- taunt -------------------------------------------------------------------

func test_taunt_overrides_nearest() -> void:
	var sim := _sim({&"szaleniec": 1}, {&"bastion": 1, &"strzelec": 1})
	var sz := _first(sim, &"szaleniec")
	var bastion := _first(sim, &"bastion")
	var strzelec := _first(sim, &"strzelec")
	_place(sz, 300, 400)
	_place(strzelec, 300, 380)
	_place(bastion, 300 + 60, 400)
	sim._prepare_tick()
	assert_eq(sim._pick_enemy(sz), bastion.uid, "taunt ignored")
	_place(bastion, 300 + 200, 400)
	sim._prepare_tick()
	assert_eq(sim._pick_enemy(sz), strzelec.uid, "taunt beyond radius")


func test_taunt_pulls_backline_hunter() -> void:
	var sim := _sim({&"lotniak": 1}, {&"bastion": 1, &"lancer": 1})
	var flyer := _first(sim, &"lotniak")
	_place(flyer, 300, 400)
	_place(_first(sim, &"bastion"), 330, 400)
	_place(_first(sim, &"lancer"), 300, 200)
	sim._prepare_tick()
	assert_eq(sim.units[sim._pick_enemy(flyer)].data.id, &"bastion")


func test_taunting_units_get_less_healing() -> void:
	var sim := _sim({&"medyk": 1, &"bastion": 1}, {&"siekacz": 1}, [&"citadel", &"war_camp"])
	var bastion := _first(sim, &"bastion")
	bastion.hp -= 200
	var medyk := _first(sim, &"medyk")
	_place(medyk, bastion.x / BattleSim.SCALE, bastion.y / BattleSim.SCALE + 40)
	var hits: Array[Array] = []
	sim._act_healer(medyk, hits)
	assert_eq(hits[0][2], -GameDB.unit(&"medyk").damage * GameDB.config.taunt_heal_pct / 100)


# --- assassin ----------------------------------------------------------------

func test_assassin_teleports_behind_artillery() -> void:
	var sim := _sim({&"zabojca": 1}, {&"pancerniak": 2, &"rakieciarz": 2})
	var z := _first(sim, &"zabojca")
	_steps(sim, GameDB.unit(&"zabojca").get_trait(TraitData.Kind.TELEPORT_BACKLINE).delay + 0.1)
	assert_true(z.teleported, "no teleport")
	var rak := _first(sim, &"rakieciarz", 1)
	# Player 0 attacks upward: landing spot is above (behind) the artillery.
	assert_true(z.y < rak.y, "not behind the target")
	assert_eq(sim.units[z.target].data.id, &"rakieciarz", "not hunting the artillery")


func test_execute_bonus_below_threshold() -> void:
	var sim := _sim({&"zabojca": 1}, {&"siekacz": 1})
	var z := _first(sim, &"zabojca")
	var t := _first(sim, &"siekacz")
	var full := sim._damage(z, t, z.damage)
	t.hp = t.max_hp / 5
	assert_eq(sim._damage(z, t, z.damage), full * 150 / 100)


# --- psionic -----------------------------------------------------------------

func test_stun_pulse_hits_group_and_grants_immunity() -> void:
	var sim := _sim({&"psionik": 1}, {&"szaleniec": 5})
	var p := _first(sim, &"psionik")
	_place(p, 360, 600)
	var i := 0
	for u in sim.units:
		if u.owner == 1:
			_place(u, 330 + i * 15, 420)
			i += 1
	var hits: Array[Array] = []
	sim._pending_status.clear()
	var t := p.get_trait(TraitData.Kind.STUN_PULSE)
	assert_true(sim._stun_pulse(p, t, hits), "no target in range")
	sim._apply_statuses()
	var stunned := 0
	for u in sim.units:
		if u.owner == 1 and sim.has_status(u, BattleSim.Effect.STUN):
			stunned += 1
	assert_eq(stunned, 5, "whole group stunned")
	# Right after the stun ends the unit is immune.
	sim.tick += roundi(t.duration * GameDB.config.ticks_per_second) + 1
	var any := _first(sim, &"szaleniec", 1)
	assert_true(not sim.has_status(any, BattleSim.Effect.STUN), "stun too long")
	sim._add_status(any, BattleSim.Effect.STUN, 0, 20)
	assert_true(not sim.has_status(any, BattleSim.Effect.STUN), "stun chain")


func test_stunned_unit_does_not_act() -> void:
	var sim := _sim({&"szaleniec": 1}, {&"szaleniec": 1})
	var u := sim.units[0]
	sim._add_status(u, BattleSim.Effect.STUN, 0, 40)
	var x := u.x
	var y := u.y
	_steps(sim, 1.0)
	assert_eq([u.x, u.y], [x, y], "stunned unit moved")


# --- builder -----------------------------------------------------------------

func test_constructor_builds_up_to_limit() -> void:
	var sim := _sim({&"konstruktor": 1}, {&"bastion": 1})
	# A harmless, immobile target keeps the battle going.
	_first(sim, &"bastion").speed = 0
	var k := _first(sim, &"konstruktor")
	var t := k.get_trait(TraitData.Kind.BUILD)
	_steps(sim, t.delay + t.period * (t.max_count + 1) + 0.2)
	var turrets := 0
	for u in sim.units:
		if u.alive and u.summoner == k.uid:
			turrets += 1
			assert_eq(u.owner, 0)
	assert_eq(turrets, t.max_count)


# --- bomber ------------------------------------------------------------------

func test_bomber_explodes_with_corrosion() -> void:
	var sim := _sim({&"bombowiec": 1}, {&"pancerniak": 4})
	var bomb := _first(sim, &"bombowiec")
	var i := 0
	for u in sim.units:
		if u.owner == 1:
			_place(u, 330 + (i % 2) * 25, 300 + (i / 2) * 25)
			u.speed = 0
			i += 1
	var exploded := false
	for k in 400:
		sim.step()
		for e in sim.events:
			if e.type == "explode":
				exploded = true
		if exploded or sim.finished:
			break
	assert_true(exploded, "no explosion")
	assert_true(not bomb.alive, "bomber survived its explosion")
	var corroded := 0
	for u in sim.units:
		if u.owner == 1 and u.alive and sim.has_status(u, BattleSim.Effect.CORROSION):
			corroded += 1
			assert_eq(sim.armor_of(u), u.armor - 2, "corrosion stacks")
	assert_true(corroded >= 2, "corrosion spread %d" % corroded)


func test_corrosion_is_capped() -> void:
	var sim := _sim({&"pancerniak": 1}, {})
	var u := sim.units[0]
	for i in 5:
		sim._add_status(u, BattleSim.Effect.CORROSION, 2, 100)
	assert_eq(sim.armor_of(u), u.armor - GameDB.config.corrosion_max_stacks)


func test_bomber_is_pulled_by_taunt() -> void:
	var sim := _sim({&"bombowiec": 1}, {&"bastion": 1, &"strzelec": 6})
	var bomb := _first(sim, &"bombowiec")
	var bastion := _first(sim, &"bastion")
	_place(bomb, 360, 470)
	_place(bastion, 360, 420)
	sim._prepare_tick()
	assert_eq(sim._pick_enemy(bomb), bastion.uid)


func test_bomber_cannot_hit_flyers() -> void:
	assert_true(not GameDB.unit(&"bombowiec").can_hit_air())


# --- flyer death blast -------------------------------------------------------

func test_flyer_death_blast() -> void:
	var sim := _sim({&"lotniak": 1}, {&"siekacz": 2})
	var flyer := _first(sim, &"lotniak")
	_place(flyer, 300, 300)
	for u in sim.units:
		if u.owner == 1:
			_place(u, 310, 310)
	var hp_before := _first(sim, &"siekacz", 1).hp
	flyer.hp = 0
	sim._apply_hits([] as Array[Array])
	assert_true(_first(sim, &"siekacz", 1).hp < hp_before, "blast did no damage")


# --- auras --------------------------------------------------------------------

func test_banner_aura_ignores_foreign_cards() -> void:
	var t := GameDB.unit(&"chorazy").get_trait(TraitData.Kind.AURA)
	assert_eq(t.label, "Chorągiew")
	var mixed := _sim({&"chorazy": 1, &"bastion": 1, &"siekacz": 1, &"szaleniec": 1}, {})
	mixed._prepare_tick()
	assert_eq(_first(mixed, &"bastion").buff_damage, t.buff_damage_pct, "aura weakened by foreign cards")


func test_aura_only_for_own_faction() -> void:
	var sim := _sim({&"szaman": 1, &"szaleniec": 1, &"szturmowiec": 1}, {})
	for u in sim.units:
		_place(u, 360, 600)
	sim._prepare_tick()
	assert_true(_first(sim, &"szaleniec").buff_attack_speed > 0, "ork not buffed")
	assert_eq(_first(sim, &"szturmowiec").buff_attack_speed, 0, "human buffed by ork aura")


func test_mercenary_contract_levels() -> void:
	var t1 := GameDB.unit(&"najemnik").traits[0]
	var t2 := GameDB.unit(&"najemnik").traits[1]
	var lone := _sim({&"najemnik": 1}, {})
	assert_eq(_first(lone, &"najemnik").traits.size(), 0, "level 0 should have no contract")
	var one := _sim({&"najemnik": 1, &"szaleniec": 1, &"siekacz": 1}, {})
	for u in one.units:
		_place(u, 360, 600)
	assert_eq(one.factions_on_board(0), 1)
	assert_eq(_first(one, &"najemnik").traits.size(), 1, "level 1")
	one._prepare_tick()
	assert_eq(_first(one, &"szaleniec").buff_damage, t1.buff_damage_pct, "melee at level 1")
	assert_eq(_first(one, &"siekacz").buff_damage, 0, "ranged buffed by a melee contract")
	var two := _sim({&"najemnik": 1, &"szaleniec": 1, &"siekacz": 1, &"lancer": 1}, {})
	for u in two.units:
		_place(u, 360, 600)
	assert_eq(two.factions_on_board(0), 2)
	two._prepare_tick()
	assert_eq(_first(two, &"szaleniec").buff_damage, t2.buff_damage_pct, "melee at level 2")
	assert_eq(_first(two, &"siekacz").buff_damage, 0, "ranged buffed at level 2")
	assert_true(t2.buff_damage_pct > t1.buff_damage_pct, "level 2 should be stronger")


func test_bounty_hunter_mark_grows_with_contract() -> void:
	var one := _sim({&"lowca": 1, &"szaleniec": 1}, {})
	var two := _sim({&"lowca": 1, &"szaleniec": 1, &"lancer": 1}, {})
	var m1 := _first(one, &"lowca").get_trait(TraitData.Kind.MARK_ON_HIT)
	var m2 := _first(two, &"lowca").get_trait(TraitData.Kind.MARK_ON_HIT)
	assert_true(m1 != null and m2 != null, "mark missing")
	assert_true(m2.power > m1.power and m2.duration > m1.duration, "level 2 should mark harder and longer")
	assert_eq(_first(_sim({&"lowca": 1}, {}), &"lowca").traits.size(), 0, "level 0 should have no contract")


func test_presets_and_random_decks_are_legal() -> void:
	for p in Bot.PRESETS:
		assert_eq(GameDB.deck_error(p.deck), "", p.name)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var deck := Bot.random_deck(rng)
		assert_eq(GameDB.deck_error(deck), "", str(deck))


func test_mark_raises_damage_taken() -> void:
	var sim := _sim({&"siekacz": 1}, {&"szaleniec": 1})
	var s := sim.units[0]
	var t := sim.units[1]
	var base := sim._damage(s, t, 100)
	sim._add_status(t, BattleSim.Effect.MARK, 20, 40)
	assert_eq(sim._damage(s, t, 100), base * 120 / 100)


func test_specials_battle_is_deterministic() -> void:
	var a := {&"bastion": 2, &"zabojca": 1, &"psionik": 1, &"najemnik": 2, &"strzelec": 4}
	var b := {&"pancerniak": 4, &"konstruktor": 2, &"bombowiec": 2, &"szaman": 1, &"lotniak": 3}
	var r1 := _sim(a, b).run()
	var r2 := _sim(a, b).run()
	assert_eq([r1.ticks, r1.winner, r1.hp_left, r1.damage_dealt], [r2.ticks, r2.winner, r2.hp_left, r2.damage_dealt])
