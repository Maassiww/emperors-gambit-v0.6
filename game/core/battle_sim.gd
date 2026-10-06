class_name BattleSim
extends RefCounted
## Deterministic auto-battle between two armies.
## Fixed tick, integer positions (0.1 px), two-phase updates so unit order never matters:
## units first collect hits, statuses and summons, then everything is applied at once.
## Player 0 starts at the bottom of the arena, player 1 at the top.

const SCALE := 10
const RETARGET_TICKS := 10
## Zabójca lands this far behind its victim.
const TELEPORT_BEHIND := 25

enum Outcome { ELIMINATION, HP, DAMAGE, COIN }
enum Effect { STUN, STUN_IMMUNE, CORROSION, MARK, SLOW }


class StatusEffect:
	var power: int
	var until: int
	var length: int


## Ground effect: every zone_pulse_seconds hits enemy ground units inside with the spec's
## power (damage), stacks (corrosion) and slow_pct (slow lasting until the next pulse and a bit).
class Zone:
	var owner: int
	var x: int
	var y: int
	## Sim units (px * SCALE).
	var radius: int
	var until: int
	var length: int
	var spec: TraitData
	var source: int


class SimUnit:
	var uid: int
	var owner: int
	var data: UnitData
	var x: int
	var y: int
	var hp: int
	var max_hp: int
	var armor: int
	var damage: int
	var interval: int
	var attack_range: int
	var speed: int
	var cooldown: int = 0
	var target: int = -1
	var retarget_in: int = 0
	var rage: int = 0
	var alive := true
	var next_x: int
	var next_y: int
	## Traits active in this battle (contract levels already resolved) and their countdowns.
	var traits: Array[TraitData] = []
	var timers: Array[int] = []
	var statuses: Dictionary = {}
	## Recomputed every tick from allied auras.
	var buff_damage := 0
	var buff_attack_speed := 0
	var buff_move := 0
	var buff_armor := 0
	var teleported := false
	var exploded := false
	## Recomputed every tick: Shield wall damage reduction and Crowd attack speed (%).
	var wall_pct := 0
	var crowd_pct := 0
	var kills := 0
	var leaps := 0
	## Last breath: tick at which the unit (already at 0 HP) finally dies; 0 = not dying.
	var breath_until := 0
	## Flank: x the unit walks out to before fighting.
	var flank_x := 0
	var summoner := -1
	## Cached data flags (hot loops).
	var flying := false
	var hits_air := false

	func get_trait(kind: TraitData.Kind) -> TraitData:
		for t in traits:
			if t.kind == kind:
				return t
		return null


class Result:
	var winner: int = -1
	var outcome: Outcome = Outcome.ELIMINATION
	var ticks: int = 0
	var survivors: Array[int] = [0, 0]
	var hp_left: Array[int] = [0, 0]
	var hp_start: Array[int] = [0, 0]
	var damage_dealt: Array[int] = [0, 0]

	func hp_fraction(player: int) -> float:
		return 0.0 if hp_start[player] == 0 else float(hp_left[player]) / hp_start[player]


var units: Array[SimUnit] = []
var tick := 0
var finished := false
var result := Result.new()
## Events of the last step, for the UI: hit / heal / death / ability / teleport / pulse / explode / blast / build.
## Hits are [src, dst, amount] or [src, dst, amount, true] for area damage.
var events: Array[Dictionary] = []

var _cfg: GameConfig
var _bases: Array[BaseData] = []
var _rng: RandomNumberGenerator
var _max_ticks: int
var _overtime_tick: int
var _ability_used: Array[bool] = [false, false]
var _ability_until: Array[int] = [0, 0]
## Distinct factions on each side (neutral excluded).
var _factions: Array[int] = [0, 0]
var _purity: Array[int] = [100, 100]
var _taunters: Array[SimUnit] = []
var _pending_status: Array[Array] = []
var _pending_spawn: Array[Array] = []
var zones: Array[Zone] = []
var _pending_zones: Array[Zone] = []


## purity: base passive strength (%) per side, from BaseData.purity_pct() of each deck.
func _init(armies: Array[Army], bases: Array[BaseData], cfg: GameConfig, rng: RandomNumberGenerator,
		purity: Array[int] = [100, 100]) -> void:
	_cfg = cfg
	_bases = bases
	_purity = purity
	_rng = rng
	_max_ticks = int(cfg.battle_max_seconds * cfg.ticks_per_second)
	_overtime_tick = int(cfg.overtime_after_seconds * cfg.ticks_per_second)
	for owner in 2:
		_read_board(owner, armies[owner])
		_spawn(owner, armies[owner])
		result.hp_start[owner] = _hp_total(owner)
	for owner in 2:
		if _bases[owner].ability == BaseData.Ability.WAR_DRUMS:
			_ability_used[owner] = true
			_ability_until[owner] = _seconds_to_ticks(_bases[owner].ability_duration)


func run() -> Result:
	while not finished:
		step()
	return result


func step() -> void:
	if finished:
		return
	tick += 1
	events.clear()
	if tick == 1:
		for owner in 2:
			if _ability_used[owner]:
				events.append({"type": "ability", "owner": owner, "ability": _bases[owner].ability})
	_update_rally_banner()
	_prepare_tick()
	var hits: Array[Array] = []
	_pending_status.clear()
	_pending_spawn.clear()
	_pending_zones.clear()
	_pulse_zones(hits)
	for u in units:
		if u.alive:
			_act(u, hits)
	_separate()
	for u in units:
		u.x = u.next_x
		u.y = u.next_y
	_apply_hits(hits)
	_apply_statuses()
	_spawn_pending()
	_place_zones()
	_expire_statuses()
	_expire_zones()
	_check_end()


func alive_count(owner: int) -> int:
	var n := 0
	for u in units:
		if u.alive and u.owner == owner:
			n += 1
	return n


## 100 normally; grows every second after overtime starts.
func overtime_pct() -> int:
	if tick <= _overtime_tick:
		return 100
	return 100 + (tick - _overtime_tick) * _cfg.overtime_damage_pct_per_second / _cfg.ticks_per_second


func ability_active(owner: int) -> bool:
	return _ability_used[owner] and tick < _ability_until[owner]


## Distinct factions on the owner's board (neutral excluded): the level of neutral contracts.
func factions_on_board(owner: int) -> int:
	return _factions[owner]


func has_status(u: SimUnit, effect: Effect) -> bool:
	return u.statuses.has(effect) and tick < u.statuses[effect].until


## Current slow in % (0..slow_max_pct).
func slow_of(u: SimUnit) -> int:
	return u.statuses[Effect.SLOW].power if has_status(u, Effect.SLOW) else 0


func armor_of(u: SimUnit) -> int:
	var corrosion: int = u.statuses[Effect.CORROSION].power if has_status(u, Effect.CORROSION) else 0
	return maxi(0, u.armor + u.buff_armor - corrosion)


# --- setup -------------------------------------------------------------------

func _read_board(owner: int, army: Army) -> void:
	var factions := {}
	for id in army.ids_sorted():
		if army.counts[id] <= 0:
			continue
		var f := GameDB.unit(id).faction
		if f != UnitData.NEUTRAL:
			factions[f] = true
	_factions[owner] = factions.size()


func _spawn(owner: int, army: Army) -> void:
	var rows: Array[Array] = [[], [], [], [], []]
	for id in army.ids_sorted():
		var data := GameDB.unit(id)
		for i in army.counts[id]:
			rows[data.formation_row()].append(data)
	var max_dist := _cfg.arena_height / 2 - 50
	var dist := _cfg.first_row_distance
	for list in rows:
		if list.is_empty():
			continue
		var lines := ceili(list.size() / float(_cfg.units_per_line))
		for line in lines:
			var start := line * _cfg.units_per_line
			var n := mini(_cfg.units_per_line, list.size() - start)
			var d := mini(dist, max_dist)
			var y := _cfg.arena_height / 2 + (d if owner == 0 else -d)
			for i in n:
				_add_unit(owner, list[start + i], _cfg.arena_width * (i + 1) / (n + 1) * SCALE, y * SCALE)
			dist += _cfg.row_line_spacing
		dist += _cfg.row_gap


## x, y in sim units (px * SCALE).
func _add_unit(owner: int, data: UnitData, x: int, y: int) -> SimUnit:
	var u := SimUnit.new()
	u.uid = units.size()
	u.owner = owner
	u.data = data
	u.x = x
	u.y = y
	u.next_x = u.x
	u.next_y = u.y
	u.flying = data.is_flying()
	u.hits_air = data.can_hit_air()
	u.max_hp = data.hp
	u.hp = u.max_hp
	u.damage = data.damage
	u.armor = data.armor
	var base := _bases[owner]
	u.interval = maxi(1, _seconds_to_ticks(data.attack_interval))
	u.attack_range = data.attack_range * SCALE
	u.speed = data.speed * SCALE / _cfg.ticks_per_second
	for t in data.traits:
		if t.active_for(_factions[owner]):
			u.traits.append(t)
			u.timers.append(_seconds_to_ticks(t.delay))
	if u.get_trait(TraitData.Kind.FLANK) != null:
		var w := _cfg.arena_width * SCALE
		var left := x < w / 2 or (x == w / 2 and u.uid % 2 == 0)
		u.flank_x = w * 15 / 100 if left else w * 85 / 100
	units.append(u)
	return u


# --- per tick ----------------------------------------------------------------

## Collects taunters and recomputes aura buffs from current positions.
func _prepare_tick() -> void:
	_taunters.clear()
	for u in units:
		u.buff_damage = 0
		u.buff_attack_speed = 0
		u.buff_move = 0
		u.buff_armor = 0
		u.wall_pct = 0
		u.crowd_pct = 0
	for s in units:
		if not s.alive:
			continue
		for t in s.traits:
			match t.kind:
				TraitData.Kind.TAUNT:
					_taunters.append(s)
				TraitData.Kind.AURA:
					_apply_aura(s, t)
				TraitData.Kind.SHIELD_WALL:
					if _allies_with(s, t.kind, t.radius) > 0:
						s.wall_pct = t.power
				TraitData.Kind.CROWD:
					s.crowd_pct = mini(t.threshold_pct, _allies_with(s, t.kind, t.radius) * t.power)


## Alive allies of u (not u) within radius px that have a trait of this kind.
func _allies_with(u: SimUnit, kind: TraitData.Kind, radius: int) -> int:
	var r := radius * SCALE
	var n := 0
	for a in units:
		if a.alive and a.owner == u.owner and a.uid != u.uid and _dist_sq(u, a) <= r * r and a.get_trait(kind) != null:
			n += 1
	return n


func _apply_aura(s: SimUnit, t: TraitData) -> void:
	var r := t.radius * SCALE
	for a in units:
		if not a.alive or a.owner != s.owner or _dist_sq(s, a) > r * r:
			continue
		match t.affects:
			TraitData.Affects.FACTION:
				if a.data.faction != s.data.faction:
					continue
			TraitData.Affects.MELEE:
				if a.data.unit_class != UnitData.UnitClass.MELEE:
					continue
		a.buff_damage = maxi(a.buff_damage, t.buff_damage_pct)
		a.buff_attack_speed = maxi(a.buff_attack_speed, t.buff_attack_speed_pct)
		a.buff_move = maxi(a.buff_move, t.buff_move_pct)
		a.buff_armor = maxi(a.buff_armor, t.buff_armor)


func _act(u: SimUnit, hits: Array[Array]) -> void:
	u.next_x = u.x
	u.next_y = u.y
	if u.cooldown > 0:
		u.cooldown -= 1
	if has_status(u, Effect.STUN):
		return
	u.retarget_in -= 1
	if _tick_traits(u, hits):
		return
	if u.data.is_healer():
		_act_healer(u, hits)
		return
	if u.target < 0 or not units[u.target].alive or u.retarget_in <= 0:
		u.target = _pick_enemy(u)
		u.retarget_in = RETARGET_TICKS
	if u.target < 0:
		return
	var t := units[u.target]
	var in_range := _dist_sq(u, t) <= u.attack_range * u.attack_range
	var kamikaze := u.get_trait(TraitData.Kind.KAMIKAZE)
	if kamikaze != null:
		if in_range:
			_explode(u, kamikaze, hits)
		else:
			_move_towards(u, t)
		return
	if not in_range:
		_move_towards(u, t)
	elif u.cooldown == 0:
		u.cooldown = _effective_interval(u)
		_fire(u, t, hits)


func _fire(u: SimUnit, t: SimUnit, hits: Array[Array]) -> void:
	var scatter := u.get_trait(TraitData.Kind.SCATTER)
	if scatter != null:
		_fire_scattered(u, t, scatter, hits)
		return
	hits.append([u.uid, t.uid, _damage(u, t, u.damage)])
	_on_hit_effects(u, t)
	if u.get_trait(TraitData.Kind.RANDOM_TARGET) != null:
		u.retarget_in = 0
	var sniper := u.get_trait(TraitData.Kind.SNIPER)
	if sniper != null and sniper.cast_range > 0:
		_pierce(u, t, sniper, hits)
	if u.data.splash_radius > 0:
		var r := u.data.splash_radius * SCALE
		for e in units:
			if e.alive and e.owner != u.owner and e.uid != t.uid and not e.flying and _dist_sq(t, e) <= r * r:
				hits.append([u.uid, e.uid, _damage(u, e, u.damage) / 2, true])


func _on_hit_effects(u: SimUnit, t: SimUnit) -> void:
	var mark := u.get_trait(TraitData.Kind.MARK_ON_HIT)
	if mark != null:
		_pending_status.append([t.uid, Effect.MARK, mark.power, _seconds_to_ticks(mark.duration)])
	var slow := u.get_trait(TraitData.Kind.SLOW_ON_HIT)
	if slow != null:
		_pending_status.append([t.uid, Effect.SLOW, slow.power, _seconds_to_ticks(slow.duration), slow.threshold_pct])


## Shell lands up to scatter.radius px off target. Enemies near the impact take full damage,
## farther ones in the splash half; own ground units in the splash take scatter.threshold_pct% of it.
func _fire_scattered(u: SimUnit, t: SimUnit, scatter: TraitData, hits: Array[Array]) -> void:
	var off := scatter.radius * SCALE
	var ix := t.x + _rng.randi_range(-off, off)
	var iy := t.y + _rng.randi_range(-off, off)
	var r := maxi(1, u.data.splash_radius) * SCALE
	for e in units:
		if not e.alive or e.flying or e.uid == u.uid:
			continue
		var dx := e.x - ix
		var dy := e.y - iy
		var d := dx * dx + dy * dy
		if d > r * r:
			continue
		var dmg := _damage(u, e, u.damage)
		if d * 4 > r * r:
			dmg /= 2
		if e.owner == u.owner:
			dmg = dmg * scatter.threshold_pct / 100
			if dmg > 0:
				hits.append([u.uid, e.uid, dmg, true])
		else:
			hits.append([u.uid, e.uid, dmg, true])
			_on_hit_effects(u, e)
	var zone := u.get_trait(TraitData.Kind.ZONE_ON_HIT)
	if zone != null:
		_add_zone(u.owner, ix, iy, zone, u.uid)
	events.append({"type": "shell", "src": u.uid, "pos": Vector2i(ix, iy), "r": u.data.splash_radius})


## Piercing shot: enemies near the line u->t, up to t.cast_range behind t, take t.power% damage.
func _pierce(u: SimUnit, t: SimUnit, spec: TraitData, hits: Array[Array]) -> void:
	var dx := t.x - u.x
	var dy := t.y - u.y
	var len := int(sqrt(float(dx * dx + dy * dy)))
	if len == 0:
		return
	var reach := spec.cast_range * SCALE
	var width := spec.radius * SCALE
	for e in units:
		if not e.alive or e.owner == u.owner or e.uid == t.uid or e.flying:
			continue
		var ex := e.x - t.x
		var ey := e.y - t.y
		var along := (ex * dx + ey * dy) / len
		var across := absi(ex * dy - ey * dx) / len
		if along > 0 and along <= reach and across <= width:
			hits.append([u.uid, e.uid, _damage(u, e, u.damage) * spec.power / 100, true])


## Timed traits. Returns true when the trait used up the unit's turn (teleport).
func _tick_traits(u: SimUnit, hits: Array[Array]) -> bool:
	for i in u.traits.size():
		var t := u.traits[i]
		match t.kind:
			TraitData.Kind.TELEPORT_BACKLINE:
				u.timers[i] -= 1
				if not u.teleported and u.timers[i] <= 0 and _teleport(u):
					return true
			TraitData.Kind.STUN_PULSE:
				u.timers[i] -= 1
				if u.timers[i] <= 0 and _stun_pulse(u, t, hits):
					u.timers[i] = _seconds_to_ticks(t.period)
			TraitData.Kind.BUILD:
				u.timers[i] -= 1
				if u.timers[i] <= 0:
					_build(u, t)
					u.timers[i] = _seconds_to_ticks(t.period)
			TraitData.Kind.ZONE_DROP:
				u.timers[i] -= 1
				if u.timers[i] <= 0:
					_add_zone(u.owner, u.x, u.y, t, u.uid)
					u.timers[i] = _seconds_to_ticks(t.period)
			TraitData.Kind.LEAP:
				u.timers[i] -= 1
				if u.leaps < maxi(1, t.max_count) and u.timers[i] <= 0 and _leap(u, t, hits):
					u.leaps += 1
					u.timers[i] = _seconds_to_ticks(t.period)
					return true
			TraitData.Kind.FLANK:
				if u.timers[i] > 0:
					u.timers[i] -= 1
					var step := u.speed * _speed_pct(u) / 100
					if absi(u.flank_x - u.x) > step:
						u.next_x = u.x + signi(u.flank_x - u.x) * step
						return true
					u.timers[i] = 0
	return false


func _act_healer(u: SimUnit, hits: Array[Array]) -> void:
	var patient := _pick_patient(u)
	if patient >= 0:
		var p := units[patient]
		if _dist_sq(u, p) > u.attack_range * u.attack_range:
			_move_towards(u, p)
		elif u.cooldown == 0:
			u.cooldown = _effective_interval(u)
			var heal := u.damage
			if p.get_trait(TraitData.Kind.TAUNT) != null:
				heal = heal * _cfg.taunt_heal_pct / 100
			hits.append([u.uid, p.uid, -heal])
			var multi := u.get_trait(TraitData.Kind.MULTI_HEAL)
			if multi != null:
				var done: Array[int] = [p.uid]
				for k in multi.max_count - 1:
					var extra := _pick_patient(u, done, u.attack_range)
					if extra < 0:
						break
					done.append(extra)
					var h := u.damage
					if units[extra].get_trait(TraitData.Kind.TAUNT) != null:
						h = h * _cfg.taunt_heal_pct / 100
					hits.append([u.uid, extra, -h])
		return
	# Nobody to heal: follow the army, staying at own range from the nearest enemy.
	var enemy := _pick_enemy(u)
	if enemy >= 0 and _dist_sq(u, units[enemy]) > u.attack_range * u.attack_range:
		_move_towards(u, units[enemy])


# --- targeting ---------------------------------------------------------------

## Priority: committed bomb / hunter > Taunt > the unit's own trait (bomb: densest group,
## hunter: backline) > nearest.
func _pick_enemy(u: SimUnit) -> int:
	# Bombs and teleported hunters commit to their victim until it dies; Taunt cannot pull them off.
	var sticky := u.get_trait(TraitData.Kind.KAMIKAZE) != null or (u.teleported and u.data.targets_backline)
	if sticky and u.target >= 0 and units[u.target].alive and units[u.target].owner != u.owner and units[u.target].hp > 0:
		return u.target
	var taunter := _taunter_for(u)
	if taunter >= 0:
		return taunter
	if u.get_trait(TraitData.Kind.KAMIKAZE) != null:
		return _densest_enemy(u, u.get_trait(TraitData.Kind.KAMIKAZE).radius * SCALE, -1)
	if u.data.targets_backline:
		var back := _nearest(u, true)
		if back >= 0:
			return back
	if u.get_trait(TraitData.Kind.SNIPER) != null:
		var prize := _most_valuable_in_range(u)
		if prize >= 0:
			return prize
	if u.get_trait(TraitData.Kind.RANDOM_TARGET) != null:
		var pick := _random_in_range(u)
		if pick >= 0:
			return pick
	if u.get_trait(TraitData.Kind.SKIP_HEAVY) != null:
		var light := _nearest(u, false, true)
		if light >= 0:
			return light
	return _nearest(u, false)


## Value: evolution 2, heavy 1, then more max HP, then nearer.
func _most_valuable_in_range(u: SimUnit) -> int:
	var best := -1
	var best_key := -1
	var best_d := 0
	var r2 := u.attack_range * u.attack_range
	for e in units:
		if not e.alive or e.owner == u.owner or not _can_target(u, e):
			continue
		var d := _dist_sq(u, e)
		if d > r2:
			continue
		var key := (2 if e.data.is_evolution else 0) + (1 if e.data.role == UnitData.Role.HEAVY else 0)
		key = key * 100000 + e.max_hp
		if key > best_key or (key == best_key and d < best_d):
			best = e.uid
			best_key = key
			best_d = d
	return best


func _random_in_range(u: SimUnit) -> int:
	var r2 := u.attack_range * u.attack_range
	var pool: Array[int] = []
	for e in units:
		if e.alive and e.owner != u.owner and _can_target(u, e) and _dist_sq(u, e) <= r2:
			pool.append(e.uid)
	if pool.is_empty():
		return -1
	return pool[_rng.randi_range(0, pool.size() - 1)]


## Nearest enemy taunter that has u inside its taunt radius, or -1.
func _taunter_for(u: SimUnit) -> int:
	var best := -1
	var best_d := 0
	for s in _taunters:
		if s.owner == u.owner or not s.alive or not _can_target(u, s):
			continue
		var r := s.get_trait(TraitData.Kind.TAUNT).radius * SCALE
		var d := _dist_sq(u, s)
		if d <= r * r and (best < 0 or d < best_d):
			best = s.uid
			best_d = d
	return best


func _can_target(u: SimUnit, e: SimUnit) -> bool:
	return (not e.flying or u.hits_air) and e.hp > 0


func _nearest(u: SimUnit, backline_only: bool, skip_heavy: bool = false) -> int:
	var best := -1
	var best_d := 0
	var air := u.hits_air
	for e in units:
		if not e.alive or e.owner == u.owner or (not air and e.flying) or e.hp <= 0:
			continue
		if backline_only and e.data.unit_class == UnitData.UnitClass.MELEE:
			continue
		if skip_heavy and e.data.role == UnitData.Role.HEAVY and e.data.unit_class == UnitData.UnitClass.MELEE:
			continue
		var d := _dist_sq(u, e)
		if best < 0 or d < best_d:
			best = e.uid
			best_d = d
	return best


## Enemy (ground) with the most enemies around it within r, optionally only within max_range of u.
func _densest_enemy(u: SimUnit, r: int, max_range: int) -> int:
	var best := -1
	var best_n := 0
	for e in units:
		if not e.alive or e.owner == u.owner or not _can_target(u, e):
			continue
		if max_range >= 0 and _dist_sq(u, e) > max_range * max_range:
			continue
		var n := 0
		for o in units:
			if o.alive and o.owner == e.owner and _can_target(u, o) and _dist_sq(e, o) <= r * r:
				n += 1
		if n > best_n:
			best = e.uid
			best_n = n
	return best


## Most injured ally (dying units excluded); skip = uids to leave out, max_range = sim units or -1.
func _pick_patient(u: SimUnit, skip: Array[int] = [], max_range: int = -1) -> int:
	var best := -1
	var best_ratio := 1000
	for a in units:
		if not a.alive or a.owner != u.owner or a.hp >= a.max_hp or a.hp <= 0 or a.uid in skip:
			continue
		if max_range >= 0 and _dist_sq(u, a) > max_range * max_range:
			continue
		var ratio := a.hp * 1000 / a.max_hp
		if ratio < best_ratio:
			best = a.uid
			best_ratio = ratio
	return best


# --- trait actions -----------------------------------------------------------

## Jumps behind the rearmost enemy ranged/special ground unit (closest to own x on ties).
func _teleport(u: SimUnit) -> bool:
	var best := -1
	var best_row := -1
	var best_dx := 0
	for e in units:
		if not e.alive or e.owner == u.owner or e.data.is_flying() or e.data.unit_class == UnitData.UnitClass.MELEE:
			continue
		var row := e.data.formation_row()
		var dx := absi(e.x - u.x)
		if row > best_row or (row == best_row and dx < best_dx):
			best = e.uid
			best_row = row
			best_dx = dx
	if best < 0:
		return false
	var t := units[best]
	var behind := -1 if u.owner == 0 else 1
	var y := clampi(t.y + behind * TELEPORT_BEHIND * SCALE, 20 * SCALE, (_cfg.arena_height - 20) * SCALE)
	events.append({"type": "teleport", "src": u.uid, "from": Vector2i(u.x, u.y), "to": Vector2i(t.x, y)})
	u.next_x = t.x
	u.next_y = y
	u.teleported = true
	u.target = best
	u.retarget_in = RETARGET_TICKS
	return true


## Lands next to the nearest ground enemy within cast_range and stuns enemies around the landing.
func _leap(u: SimUnit, t: TraitData, hits: Array[Array]) -> bool:
	var best := -1
	var best_d := 0
	var reach := t.cast_range * SCALE
	for e in units:
		if not e.alive or e.owner == u.owner or e.flying or e.hp <= 0:
			continue
		var d := _dist_sq(u, e)
		if d <= reach * reach and (best < 0 or d < best_d):
			best = e.uid
			best_d = d
	if best < 0:
		return false
	var target := units[best]
	var dist := maxi(1, int(sqrt(float(best_d))))
	var gap := mini(dist, (u.data.size + target.data.size) * SCALE)
	var lx := target.x - (target.x - u.x) * gap / dist
	var ly := target.y - (target.y - u.y) * gap / dist
	var r := t.radius * SCALE
	for e in units:
		if not e.alive or e.owner == u.owner or e.flying:
			continue
		var dx := e.x - lx
		var dy := e.y - ly
		if dx * dx + dy * dy <= r * r:
			if t.power > 0:
				hits.append([u.uid, e.uid, _damage(u, e, t.power), true])
			_pending_status.append([e.uid, Effect.STUN, 0, _seconds_to_ticks(t.duration)])
	events.append({"type": "teleport", "src": u.uid, "from": Vector2i(u.x, u.y), "to": Vector2i(lx, ly)})
	events.append({"type": "pulse", "src": u.uid, "pos": Vector2i(lx, ly), "r": t.radius})
	u.next_x = lx
	u.next_y = ly
	u.target = best
	u.retarget_in = RETARGET_TICKS
	return true


func _stun_pulse(u: SimUnit, t: TraitData, hits: Array[Array]) -> bool:
	var r := t.radius * SCALE
	var center_id := _densest_enemy(u, r, t.cast_range * SCALE)
	if center_id < 0:
		return false
	var center := units[center_id]
	for e in units:
		if e.alive and e.owner != u.owner and _dist_sq(center, e) <= r * r:
			if t.power > 0:
				hits.append([u.uid, e.uid, _damage(u, e, t.power), true])
			_pending_status.append([e.uid, Effect.STUN, 0, _seconds_to_ticks(t.duration)])
	events.append({"type": "pulse", "src": u.uid, "pos": Vector2i(center.x, center.y), "r": t.radius})
	return true


func _build(u: SimUnit, t: TraitData) -> void:
	var alive := 0
	for s in units:
		if s.alive and s.summoner == u.uid:
			alive += 1
	if alive >= t.max_count:
		return
	var forward := -1 if u.owner == 0 else 1
	_pending_spawn.append([u.owner, t.summon, u.x, u.y + forward * 12 * SCALE, u.uid])


func _explode(u: SimUnit, t: TraitData, hits: Array[Array]) -> void:
	var r := t.radius * SCALE
	for e in units:
		if e.alive and e.owner != u.owner and not e.data.is_flying() and _dist_sq(u, e) <= r * r:
			hits.append([u.uid, e.uid, _damage(u, e, u.damage), true])
			if t.stacks > 0:
				_pending_status.append([e.uid, Effect.CORROSION, t.stacks, _seconds_to_ticks(t.duration)])
	u.exploded = true
	events.append({"type": "explode", "src": u.uid, "pos": Vector2i(u.x, u.y), "r": t.radius})


# --- movement ----------------------------------------------------------------

func _move_towards(u: SimUnit, t: SimUnit) -> void:
	var dx := t.x - u.x
	var dy := t.y - u.y
	var dist := int(sqrt(float(dx * dx + dy * dy)))
	if dist == 0:
		return
	var step := mini(u.speed * _speed_pct(u) / 100, maxi(0, dist - u.attack_range + SCALE))
	u.next_x = u.x + dx * step / dist
	u.next_y = u.y + dy * step / dist


## Pushes overlapping allies apart (same layer only: flyers pass over ground units).
## Reads current positions, writes next positions, so unit order does not matter.
func _separate() -> void:
	# Hot loop: plain packed arrays and early rejects instead of object access.
	var n := units.size()
	var xs := PackedInt32Array()
	var ys := PackedInt32Array()
	var rs := PackedInt32Array()
	var groups := PackedInt32Array()
	xs.resize(n)
	ys.resize(n)
	rs.resize(n)
	groups.resize(n)
	for i in n:
		var u := units[i]
		xs[i] = u.x
		ys[i] = u.y
		rs[i] = u.data.size * SCALE
		groups[i] = (u.owner * 2 + (1 if u.flying else 0)) if u.alive else -1
	for i in n:
		var g := groups[i]
		if g < 0:
			continue
		var xi := xs[i]
		var yi := ys[i]
		var ri := rs[i]
		for j in range(i + 1, n):
			if groups[j] != g:
				continue
			var min_d := ri + rs[j]
			var dx := xs[j] - xi
			if dx >= min_d or dx <= -min_d:
				continue
			var dy := ys[j] - yi
			if dy >= min_d or dy <= -min_d:
				continue
			_push_apart(units[i], units[j])


func _push_apart(a: SimUnit, b: SimUnit) -> void:
	var min_d := (a.data.size + b.data.size) * SCALE
	var dx := b.x - a.x
	var dy := b.y - a.y
	var d2 := dx * dx + dy * dy
	if d2 >= min_d * min_d:
		return
	var d := int(sqrt(float(d2)))
	if d == 0:
		# Same spot: split sideways, direction fixed by uid order.
		dx = SCALE
		dy = 0
		d = SCALE
	var push := (min_d - d) / 2
	# Stationary units (turrets, artillery) are not shoved around.
	var a_fixed := a.data.speed == 0
	var b_fixed := b.data.speed == 0
	if not a_fixed:
		a.next_x -= dx * push / d * (2 if b_fixed else 1)
		a.next_y -= dy * push / d * (2 if b_fixed else 1)
	if not b_fixed:
		b.next_x += dx * push / d * (2 if a_fixed else 1)
		b.next_y += dy * push / d * (2 if a_fixed else 1)


# --- damage and buffs --------------------------------------------------------

## Final damage of one hit: buffs, rage, overtime, execute, armor (unless pierce), mark.
func _damage(u: SimUnit, t: SimUnit, base_damage: int) -> int:
	var dmg := base_damage * (100 + rage_pct(u) + u.buff_damage) / 100
	dmg = dmg * overtime_pct() / 100
	var execute := u.get_trait(TraitData.Kind.EXECUTE)
	if execute != null and t.hp * 100 < t.max_hp * execute.threshold_pct:
		dmg = dmg * (100 + execute.power) / 100
	if not u.data.armor_pierce:
		dmg = dmg * UnitData.armor_pass_pct(armor_of(t), _cfg) / 100
	if has_status(t, Effect.MARK):
		dmg = dmg * (100 + t.statuses[Effect.MARK].power) / 100
	if t.wall_pct > 0 and u.data.unit_class == UnitData.UnitClass.RANGED:
		dmg = dmg * (100 - t.wall_pct) / 100
	dmg = dmg * (100 - damage_reduction_pct(t.owner)) / 100
	return maxi(1, dmg)


## Base passive DAMAGE_REDUCTION of a side, scaled by deck purity.
func damage_reduction_pct(owner: int) -> int:
	var base := _bases[owner]
	if base.passive != BaseData.Passive.DAMAGE_REDUCTION:
		return 0
	return base.passive_value * _purity[owner] / 100


## Rage bonus damage (%) of a unit, scaled by its side's deck purity.
func rage_pct(u: SimUnit) -> int:
	return u.rage * _bases[u.owner].rage_pct_per_stack * _purity[u.owner] / 100


func _speed_pct(u: SimUnit) -> int:
	var pct := 100 + u.buff_move
	var base := _bases[u.owner]
	if base.ability == BaseData.Ability.WAR_DRUMS and ability_active(u.owner):
		pct += base.ability_power
	return pct * (100 - slow_of(u)) / 100


func _effective_interval(u: SimUnit) -> int:
	var base := _bases[u.owner]
	var bonus := u.buff_attack_speed + u.crowd_pct
	var frenzy := u.get_trait(TraitData.Kind.FRENZY_ON_KILL)
	if frenzy != null:
		bonus += mini(u.kills, frenzy.stacks) * frenzy.power
	if ability_active(u.owner):
		match base.ability:
			BaseData.Ability.WAR_DRUMS:
				bonus += base.ability_power / 2
			BaseData.Ability.RALLY_BANNER:
				bonus += base.ability_power
	return maxi(1, u.interval * 100 / (100 + bonus) * 100 / (100 - slow_of(u)))


func _update_rally_banner() -> void:
	for owner in 2:
		var base := _bases[owner]
		if base.ability != BaseData.Ability.RALLY_BANNER or _ability_used[owner]:
			continue
		if _hp_total(owner) * 100 < result.hp_start[owner] * base.ability_trigger_hp_pct:
			_ability_used[owner] = true
			_ability_until[owner] = tick + _seconds_to_ticks(base.ability_duration)
			events.append({"type": "ability", "owner": owner, "ability": base.ability})


# --- resolution --------------------------------------------------------------

func _apply_hits(hits: Array[Array]) -> void:
	_deal(hits)
	for u in units:
		if u.alive and u.exploded:
			u.hp = 0
	# Deaths can trigger more damage (death blasts), which can kill more units.
	while true:
		var dead: Array[SimUnit] = []
		for u in units:
			if u.alive and u.hp <= 0 and not _last_breath(u):
				u.alive = false
				events.append({"type": "death", "dst": u.uid})
				dead.append(u)
		if dead.is_empty():
			break
		var extra: Array[Array] = []
		for d in dead:
			_on_death(d, extra)
		_deal(extra)


## True while a unit at 0 HP still fights on its Last breath (starts it on first call).
func _last_breath(u: SimUnit) -> bool:
	if u.exploded:
		return false
	if u.breath_until == 0:
		var t := u.get_trait(TraitData.Kind.LAST_BREATH)
		if t == null:
			return false
		u.breath_until = tick + maxi(1, _seconds_to_ticks(t.duration))
		events.append({"type": "breath", "dst": u.uid})
		return true
	return tick < u.breath_until


func _deal(hits: Array[Array]) -> void:
	for h in hits:
		var src := units[h[0]]
		var t := units[h[1]]
		var amount: int = h[2]
		if amount < 0:
			if t.hp <= 0:
				continue
			var healed := mini(-amount, t.max_hp - t.hp)
			t.hp += healed
			events.append({"type": "heal", "src": src.uid, "dst": t.uid, "amount": healed})
		elif t.hp > 0:
			var dealt := mini(amount, t.hp)
			t.hp -= dealt
			if t.hp <= 0:
				src.kills += 1
			result.damage_dealt[src.owner] += dealt
			# Area hits (splash, blasts, pulses) are drawn by their own effect, not as shots.
			events.append({"type": "hit", "src": src.uid, "dst": t.uid, "amount": dealt, "area": h.size() > 3})


func _on_death(dead: SimUnit, extra: Array[Array]) -> void:
	var puddle := dead.get_trait(TraitData.Kind.DEATH_ZONE)
	if puddle != null:
		_add_zone(dead.owner, dead.x, dead.y, puddle, dead.uid)
	var blast := dead.get_trait(TraitData.Kind.DEATH_BLAST)
	if blast != null:
		var r := blast.radius * SCALE
		for e in units:
			if e.alive and e.owner != dead.owner and _dist_sq(dead, e) <= r * r:
				extra.append([dead.uid, e.uid, _damage(dead, e, blast.power), true])
		events.append({"type": "blast", "src": dead.uid, "pos": Vector2i(dead.x, dead.y), "r": blast.radius})
	var base := _bases[dead.owner]
	if base.passive != BaseData.Passive.RAGE_ON_ALLY_DEATH or _purity[dead.owner] <= 0:
		return
	for u in units:
		if u.alive and u.owner == dead.owner:
			u.rage = mini(u.rage + 1, base.passive_value)


func _apply_statuses() -> void:
	for p in _pending_status:
		var u := units[p[0]]
		if u.alive:
			_add_status(u, p[1], p[2], p[3], p[4] if p.size() > 4 else 0)


## cap: for SLOW, the most this application may push the total to (0 = slow_max_pct).
func _add_status(u: SimUnit, effect: Effect, power: int, ticks: int, cap: int = 0) -> void:
	match effect:
		Effect.STUN:
			# Immunity starts with the stun and lasts until stun_immunity_seconds after it.
			if has_status(u, Effect.STUN_IMMUNE):
				return
			_set_status(u, Effect.STUN, 0, ticks)
			_set_status(u, Effect.STUN_IMMUNE, 0, ticks + _seconds_to_ticks(_cfg.stun_immunity_seconds))
		Effect.CORROSION:
			var stacks: int = u.statuses[effect].power if has_status(u, effect) else 0
			_set_status(u, effect, mini(_cfg.corrosion_max_stacks, stacks + power), ticks)
		Effect.MARK:
			var cur: int = u.statuses[effect].power if has_status(u, effect) else 0
			_set_status(u, effect, maxi(cur, power), ticks)
		Effect.SLOW:
			# Slows from every source add up to slow_max_pct; the longer duration wins.
			var limit := _cfg.slow_max_pct if cap <= 0 else mini(cap, _cfg.slow_max_pct)
			if has_status(u, effect):
				var s: StatusEffect = u.statuses[effect]
				s.power = maxi(s.power, mini(limit, s.power + power))
				if tick + ticks > s.until:
					s.until = tick + ticks
					s.length = ticks
			else:
				_set_status(u, effect, mini(limit, power), ticks)


func _set_status(u: SimUnit, effect: Effect, power: int, ticks: int) -> void:
	var s := StatusEffect.new()
	s.power = power
	s.until = tick + ticks
	s.length = ticks
	u.statuses[effect] = s


func _expire_statuses() -> void:
	for u in units:
		if u.statuses.is_empty():
			continue
		for effect in u.statuses.keys():
			if tick >= u.statuses[effect].until:
				u.statuses.erase(effect)


# --- zones -------------------------------------------------------------------

## Queues a zone at x, y (sim units); it appears after this tick's hits, like spawns.
## source: uid of the unit that made it (may be dead by now); damage is credited to its owner.
func _add_zone(owner: int, x: int, y: int, spec: TraitData, source: int) -> void:
	var z := Zone.new()
	z.owner = owner
	z.x = x
	z.y = y
	z.radius = spec.radius * SCALE
	z.length = _seconds_to_ticks(spec.duration)
	z.spec = spec
	z.source = source
	_pending_zones.append(z)


func _place_zones() -> void:
	for z in _pending_zones:
		z.until = tick + z.length
		zones.append(z)
		events.append({"type": "zone", "owner": z.owner, "x": z.x, "y": z.y, "r": z.spec.radius})
		var own := zones.filter(func(o: Zone) -> bool: return o.owner == z.owner)
		if own.size() > _cfg.max_zones_per_side:
			zones.erase(own[0])


func _expire_zones() -> void:
	zones = zones.filter(func(z: Zone) -> bool: return tick < z.until)


func _pulse_zones(hits: Array[Array]) -> void:
	var period := maxi(1, _seconds_to_ticks(_cfg.zone_pulse_seconds))
	for z in zones:
		if (z.until - tick) % period != 0:
			continue
		for e in units:
			if not e.alive or e.owner == z.owner or e.flying:
				continue
			var dx := e.x - z.x
			var dy := e.y - z.y
			if dx * dx + dy * dy > z.radius * z.radius:
				continue
			if z.spec.power > 0:
				hits.append([z.source, e.uid, _zone_damage(z, e), true])
			if z.spec.stacks > 0:
				_pending_status.append([e.uid, Effect.CORROSION, z.spec.stacks, period * 3])
			if z.spec.slow_pct > 0:
				_pending_status.append([e.uid, Effect.SLOW, z.spec.slow_pct, period + 2])


## Zone damage ignores the source's buffs (the source may be dead) but not armor or mark.
func _zone_damage(z: Zone, e: SimUnit) -> int:
	var dmg := z.spec.power * overtime_pct() / 100
	dmg = dmg * UnitData.armor_pass_pct(armor_of(e), _cfg) / 100
	if has_status(e, Effect.MARK):
		dmg = dmg * (100 + e.statuses[Effect.MARK].power) / 100
	dmg = dmg * (100 - damage_reduction_pct(e.owner)) / 100
	return maxi(1, dmg)


func _spawn_pending() -> void:
	for s in _pending_spawn:
		var u := _add_unit(s[0], GameDB.unit(s[1]), s[2], s[3])
		u.summoner = s[4]
		events.append({"type": "build", "src": s[4], "dst": u.uid})


func _check_end() -> void:
	var a0 := alive_count(0)
	var a1 := alive_count(1)
	if a0 > 0 and a1 > 0 and tick < _max_ticks and _anyone_can_attack():
		return
	finished = true
	result.ticks = tick
	for owner in 2:
		result.survivors[owner] = alive_count(owner)
		result.hp_left[owner] = _hp_total(owner)
	if (a0 == 0) != (a1 == 0):
		result.outcome = Outcome.ELIMINATION
		result.winner = 0 if a1 == 0 else 1
	elif result.hp_left[0] != result.hp_left[1]:
		result.outcome = Outcome.HP
		result.winner = 0 if result.hp_left[0] > result.hp_left[1] else 1
	elif result.damage_dealt[0] != result.damage_dealt[1]:
		result.outcome = Outcome.DAMAGE
		result.winner = 0 if result.damage_dealt[0] > result.damage_dealt[1] else 1
	else:
		result.outcome = Outcome.COIN
		result.winner = _rng.randi_range(0, 1)


## False when no living unit can damage any enemy (e.g. only healers left, or melee vs flyers only).
func _anyone_can_attack() -> bool:
	for u in units:
		if not u.alive or u.data.is_healer():
			continue
		for e in units:
			if e.alive and e.owner != u.owner and _can_target(u, e):
				return true
	return false


# --- helpers -----------------------------------------------------------------

func _hp_total(owner: int) -> int:
	var sum := 0
	for u in units:
		if u.alive and u.owner == owner:
			sum += u.hp
	return sum


func _dist_sq(a: SimUnit, b: SimUnit) -> int:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return dx * dx + dy * dy


func _seconds_to_ticks(seconds: float) -> int:
	return roundi(seconds * _cfg.ticks_per_second)
