extends TestCase
## v0.6 traits of the regular units (docs/plan-v0.6.md, stage 3).

const BASES := [&"citadel", &"citadel"]


func _sim(a: Dictionary, b: Dictionary) -> BattleSim:
	GameDB.ensure_loaded()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var armies: Array[Army] = [Army.new(), Army.new()]
	for id in a:
		armies[0].add(id, a[id])
	for id in b:
		armies[1].add(id, b[id])
	var bases: Array[BaseData] = [GameDB.base(BASES[0]), GameDB.base(BASES[1])]
	return BattleSim.new(armies, bases, GameDB.config, rng)


func _all(sim: BattleSim, id: StringName, owner: int = -1) -> Array:
	return sim.units.filter(func(u: BattleSim.SimUnit) -> bool:
		return u.data.id == id and (owner < 0 or u.owner == owner))


func _first(sim: BattleSim, id: StringName, owner: int = -1) -> BattleSim.SimUnit:
	var list := _all(sim, id, owner)
	return list[0] if not list.is_empty() else null


func _place(u: BattleSim.SimUnit, x: int, y: int) -> void:
	u.x = x * BattleSim.SCALE
	u.y = y * BattleSim.SCALE
	u.next_x = u.x
	u.next_y = u.y


func _steps(sim: BattleSim, seconds: float) -> void:
	for i in roundi(seconds * GameDB.config.ticks_per_second):
		sim.step()


func _freeze(sim: BattleSim) -> void:
	for u in sim.units:
		u.speed = 0


# --- Bastion -----------------------------------------------------------------

func test_shield_wall_needs_a_second_bastion_and_stops_only_shots() -> void:
	var sim := _sim({&"strzelec": 1, &"szturmowiec": 1}, {&"bastion": 2})
	var walls := _all(sim, &"bastion")
	_place(walls[0], 300, 300)
	_place(walls[1], 340, 300)
	sim._prepare_tick()
	var wall: int = GameDB.unit(&"bastion").get_trait(TraitData.Kind.SHIELD_WALL).power
	assert_eq(walls[0].wall_pct, wall, "paired")
	var shooter := _first(sim, &"strzelec")
	var blade := _first(sim, &"szturmowiec")
	var shot := sim._damage(shooter, walls[0], 100)
	var cut := sim._damage(blade, walls[0], 100)
	_place(walls[1], 600, 300)
	sim._prepare_tick()
	assert_eq(walls[0].wall_pct, 0, "alone")
	assert_true(sim._damage(shooter, walls[0], 100) > shot, "wall did not reduce shots")
	assert_eq(sim._damage(blade, walls[0], 100), cut, "wall reduced melee")


# --- Szturmowiec -------------------------------------------------------------

func test_leap_lands_at_the_front_and_stuns() -> void:
	var sim := _sim({&"szturmowiec": 1}, {&"pancerniak": 1})
	var s := _first(sim, &"szturmowiec")
	var p := _first(sim, &"pancerniak")
	_place(s, 360, 900)
	_place(p, 360, 550)
	_freeze(sim)
	_steps(sim, 0.6)
	assert_eq(s.leaps, 1, "no leap")
	assert_true(absi(s.y - p.y) < 40 * BattleSim.SCALE, "did not land next to the target")
	assert_true(sim.has_status(p, BattleSim.Effect.STUN), "landing did not stun")
	_steps(sim, 3.0)
	assert_eq(s.leaps, 1, "basic Szturmowiec leaps once")


# --- Strzelec ----------------------------------------------------------------

func test_suppressing_fire_slow_is_capped_by_the_trait() -> void:
	var sim := _sim({&"strzelec": 1}, {&"bastion": 1})
	var s := _first(sim, &"strzelec")
	var b := _first(sim, &"bastion")
	var t := s.get_trait(TraitData.Kind.SLOW_ON_HIT)
	for i in 10:
		sim._on_hit_effects(s, b)
	sim._apply_statuses()
	assert_eq(sim.slow_of(b), t.threshold_pct)


func test_flank_walks_out_before_fighting() -> void:
	var sim := _sim({&"strzelec": 1}, {&"bastion": 1})
	var s := _first(sim, &"strzelec")
	_place(s, 300, 900)
	_place(_first(sim, &"bastion"), 300, 100)
	_steps(sim, 1.0)
	assert_true(s.x < 300 * BattleSim.SCALE, "did not move to the left flank")
	assert_eq(s.y, 900 * BattleSim.SCALE, "advanced while flanking")


# --- Lancer ------------------------------------------------------------------

func test_sniper_prefers_heavy_over_nearer_light() -> void:
	var sim := _sim({&"lancer": 1}, {&"szaleniec": 1, &"pancerniak": 1})
	var l := _first(sim, &"lancer")
	_place(l, 360, 900)
	for u in _all(sim, &"szaleniec"):
		_place(u, 360, 800)
	for u in _all(sim, &"pancerniak"):
		_place(u, 360, 600)
	assert_eq(sim.units[sim._pick_enemy(l)].data.id, &"pancerniak")


func test_sniper_shot_pierces_the_line_behind() -> void:
	var sim := _sim({&"lancer": 1}, {&"pancerniak": 1, &"szaleniec": 2})
	var l := _first(sim, &"lancer")
	var p := _first(sim, &"pancerniak")
	var behind := _all(sim, &"szaleniec")
	_place(l, 360, 900)
	_place(p, 360, 700)
	_place(behind[0], 362, 650)
	_place(behind[1], 500, 650)
	var hits: Array[Array] = []
	sim._fire(l, p, hits)
	var hit_ids := hits.map(func(h: Array) -> int: return h[1])
	assert_true(behind[0].uid in hit_ids, "unit behind the target not pierced")
	assert_true(not (behind[1].uid in hit_ids), "unit off the line pierced")


# --- Pancerniak --------------------------------------------------------------

func test_mud_puddles_while_alive_and_on_death() -> void:
	var sim := _sim({&"pancerniak": 2}, {&"bastion": 1})
	var p := _all(sim, &"pancerniak")
	_freeze(sim)
	_steps(sim, 2.1)
	assert_eq(sim.zones.size(), 2, "each Pancerniak should drop a puddle after the delay")
	p[0].hp = 0
	sim._apply_hits([] as Array[Array])
	sim._place_zones()
	assert_eq(sim.zones.size(), 3, "no death puddle")


# --- Szaleniec ---------------------------------------------------------------

func test_through_the_ranks_skips_heavy_unless_taunted() -> void:
	var sim := _sim({&"szaleniec": 1}, {&"pancerniak": 1, &"siekacz": 1})
	var s := _first(sim, &"szaleniec")
	assert_eq(sim.units[sim._pick_enemy(s)].data.id, &"siekacz")
	var t := _sim({&"szaleniec": 1}, {&"bastion": 1, &"strzelec": 1})
	var s2 := _first(t, &"szaleniec")
	_place(s2, 300, 400)
	_place(_first(t, &"bastion"), 300, 380)
	_place(_first(t, &"strzelec"), 300, 200)
	t._prepare_tick()
	assert_eq(t.units[t._pick_enemy(s2)].data.id, &"bastion", "taunt must still hold")


func test_last_breath_keeps_fighting_then_dies() -> void:
	var sim := _sim({&"szaleniec": 1}, {&"bastion": 1})
	var s := _first(sim, &"szaleniec")
	var b := _first(sim, &"bastion")
	s.hp = 0
	sim._apply_hits([] as Array[Array])
	assert_true(s.alive, "died at once")
	assert_true(not (sim._can_target(b, s)), "dying unit can be targeted")
	_steps(sim, 1.1)
	assert_true(not (s.alive), "never died")


func test_frenzy_speeds_up_attacks_per_kill() -> void:
	var sim := _sim({&"berserker": 1}, {&"bastion": 1})
	var b := _first(sim, &"berserker")
	var before := sim._effective_interval(b)
	b.kills = 3
	assert_true(sim._effective_interval(b) < before)


# --- Siekacz -----------------------------------------------------------------

func test_blind_fire_spreads_over_targets_in_range() -> void:
	var sim := _sim({&"siekacz": 1}, {&"szaleniec": 4})
	var s := _first(sim, &"siekacz")
	_place(s, 360, 900)
	var foes := _all(sim, &"szaleniec")
	for i in foes.size():
		_place(foes[i], 200 + i * 60, 800)
	var seen := {}
	for i in 30:
		seen[sim._pick_enemy(s)] = true
	assert_true(seen.size() >= 3, "always the same target")


func test_crowd_bonus_per_neighbour_with_cap() -> void:
	var sim := _sim({&"siekacz": 8}, {})
	var list := _all(sim, &"siekacz")
	for i in list.size():
		_place(list[i], 300 + i * 5, 900)
	sim._prepare_tick()
	var t: TraitData = list[0].get_trait(TraitData.Kind.CROWD)
	assert_eq(list[0].crowd_pct, mini(t.threshold_pct, (list.size() - 1) * t.power))
	_place(list[0], 700, 200)
	sim._prepare_tick()
	assert_eq(list[0].crowd_pct, 0, "alone")


# --- Rakieciarz --------------------------------------------------------------

func test_scatter_hurts_own_units_less_and_sets_fire() -> void:
	var sim := _sim({&"rakieciarz": 1, &"szaleniec": 1}, {&"szaleniec": 1})
	var r := _first(sim, &"rakieciarz", 0)
	var own := _first(sim, &"szaleniec", 0)
	var foe := _first(sim, &"szaleniec", 1)
	_place(r, 360, 900)
	_place(foe, 360, 600)
	_place(own, 360, 600)
	var hits: Array[Array] = []
	sim._fire(r, foe, hits)
	sim._place_zones()
	var to_own := 0
	var to_foe := 0
	for h in hits:
		if h[1] == own.uid:
			to_own = h[2]
		elif h[1] == foe.uid:
			to_foe = h[2]
	var ff: int = r.get_trait(TraitData.Kind.SCATTER).threshold_pct
	if to_foe > 0:
		assert_eq(to_own, sim._damage(r, own, r.damage) * ff / 100 / (1 if to_foe == sim._damage(r, foe, r.damage) else 2))
	assert_eq(sim.zones.size(), 1, "no burning zone")


# --- Medyk -------------------------------------------------------------------

func test_archimedyk_heals_two() -> void:
	var sim := _sim({&"archimedyk": 1, &"bastion": 1, &"strzelec": 1}, {})
	for u in sim.units:
		_place(u, 360, 900)
		u.hp = u.max_hp / 2
	var hits: Array[Array] = []
	var a := _first(sim, &"archimedyk")
	a.hp = a.max_hp
	sim._act(a, hits)
	assert_eq(hits.size(), 2)
