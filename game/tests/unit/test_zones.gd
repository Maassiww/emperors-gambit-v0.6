extends TestCase
## Slow status and ground zones (the effect vocabulary for v0.6 traits).

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


func _spec(radius: int, duration: float, power: int = 0, stacks: int = 0, slow: int = 0) -> TraitData:
	var t := TraitData.new()
	t.radius = radius
	t.duration = duration
	t.power = power
	t.stacks = stacks
	t.slow_pct = slow
	return t


# --- slow --------------------------------------------------------------------

func test_slow_stacks_up_to_cap() -> void:
	var sim := _sim({&"bastion": 1}, {})
	var u := sim.units[0]
	sim._add_status(u, BattleSim.Effect.SLOW, 20, 40)
	sim._add_status(u, BattleSim.Effect.SLOW, 20, 10)
	assert_eq(sim.slow_of(u), 40, "two slows add up")
	assert_eq(u.statuses[BattleSim.Effect.SLOW].until, sim.tick + 40, "longer duration kept")
	sim._add_status(u, BattleSim.Effect.SLOW, 30, 10)
	assert_eq(sim.slow_of(u), GameDB.config.slow_max_pct, "capped")


func test_slow_reduces_move_and_attack_speed() -> void:
	var sim := _sim({&"szturmowiec": 1}, {})
	var u := sim.units[0]
	var speed := sim._speed_pct(u)
	var interval := sim._effective_interval(u)
	sim._add_status(u, BattleSim.Effect.SLOW, 50, 40)
	assert_eq(sim._speed_pct(u), speed / 2, "move")
	assert_eq(sim._effective_interval(u), interval * 2, "attack")


func test_slow_expires() -> void:
	var sim := _sim({&"bastion": 1}, {&"bastion": 1})
	var u := sim.units[0]
	sim._add_status(u, BattleSim.Effect.SLOW, 30, 3)
	for i in 3:
		sim.step()
	assert_eq(sim.slow_of(u), 0)


# --- zones -------------------------------------------------------------------

func test_zone_hits_enemies_inside_only() -> void:
	var sim := _sim({&"bastion": 1}, {&"szaleniec": 3})
	var src := _first(sim, &"bastion")
	var foes := sim.units.filter(func(u: BattleSim.SimUnit) -> bool: return u.owner == 1)
	_place(src, 360, 1000)
	_place(foes[0], 360, 300)
	_place(foes[1], 380, 300)
	_place(foes[2], 600, 300)
	sim._add_zone(0, 360 * BattleSim.SCALE, 300 * BattleSim.SCALE, _spec(40, 2.0, 10, 1, 20), src.uid)
	sim._place_zones()
	var hits: Array[Array] = []
	sim._pending_status.clear()
	sim.tick = sim.zones[0].until - GameDB.config.ticks_per_second  # a pulse tick
	sim._pulse_zones(hits)
	assert_eq(hits.size(), 2, "two foes inside")
	sim._apply_statuses()
	assert_eq(sim.slow_of(foes[0]), 20, "slowed")
	assert_true(sim.has_status(foes[1], BattleSim.Effect.CORROSION), "corroded")
	assert_eq(sim.slow_of(foes[2]), 0, "outside untouched")
	assert_eq(sim.slow_of(src), 0, "own side untouched")


func test_zone_ignores_flyers() -> void:
	var sim := _sim({&"bastion": 1}, {&"lotniak": 1})
	var src := _first(sim, &"bastion")
	var flyer := _first(sim, &"lotniak")
	_place(flyer, 360, 300)
	sim._add_zone(0, 360 * BattleSim.SCALE, 300 * BattleSim.SCALE, _spec(60, 2.0, 10), src.uid)
	sim._place_zones()
	var hits: Array[Array] = []
	sim.tick = sim.zones[0].until - GameDB.config.ticks_per_second
	sim._pulse_zones(hits)
	assert_eq(hits.size(), 0)


func test_zone_damage_credited_to_source_side_and_expires() -> void:
	var sim := _sim({&"lancer": 1}, {&"bastion": 1})
	var src := _first(sim, &"lancer")
	var foe := _first(sim, &"bastion")
	_place(src, 360, 1200)
	_place(foe, 360, 100)
	foe.speed = 0
	sim._add_zone(0, foe.x, foe.y, _spec(50, 1.0, 30), src.uid)
	sim._place_zones()
	var hp := foe.hp
	for i in GameDB.config.ticks_per_second:
		sim.step()
	assert_true(foe.hp < hp, "no zone damage")
	assert_true(sim.result.damage_dealt[0] > 0, "damage not credited to the zone owner")
	sim.step()
	assert_eq(sim.zones.size(), 0, "zone should expire")


func test_zone_limit_per_side_drops_oldest() -> void:
	var sim := _sim({&"bastion": 1}, {&"bastion": 1})
	var src := sim.units[0].uid
	var cap := GameDB.config.max_zones_per_side
	for i in cap + 2:
		sim._add_zone(0, i * 100, 0, _spec(20, 5.0), src)
		sim._place_zones()
		sim._pending_zones.clear()
	sim._add_zone(1, 0, 0, _spec(20, 5.0), sim.units[1].uid)
	sim._place_zones()
	var own := sim.zones.filter(func(z: BattleSim.Zone) -> bool: return z.owner == 0)
	assert_eq(own.size(), cap, "capped")
	assert_eq(own[0].x, 200, "oldest dropped first")
	assert_eq(sim.zones.size(), cap + 1, "other side unaffected")
