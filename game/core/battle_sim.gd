class_name BattleSim
extends RefCounted
## Deterministic auto-battle between two armies.
## Fixed tick, integer positions (0.1 px), two-phase updates so unit order never matters.
## Player 0 starts at the bottom of the arena, player 1 at the top.

const SCALE := 10
const RETARGET_TICKS := 10

enum Outcome { ELIMINATION, HP, DAMAGE, COIN }


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
## Events of the last step, for the UI: {type, src, dst, amount} / {type, owner}.
var events: Array[Dictionary] = []

var _cfg: GameConfig
var _bases: Array[BaseData] = []
var _rng: RandomNumberGenerator
var _max_ticks: int
var _ability_used: Array[bool] = [false, false]
var _ability_until: Array[int] = [0, 0]


func _init(armies: Array[Army], bases: Array[BaseData], cfg: GameConfig, rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_bases = bases
	_rng = rng
	_max_ticks = int(cfg.battle_max_seconds * cfg.ticks_per_second)
	for owner in 2:
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
	var hits: Array[Array] = []
	for u in units:
		if u.alive:
			_act(u, hits)
	for u in units:
		u.x = u.next_x
		u.y = u.next_y
	_apply_hits(hits)
	_check_end()


func alive_count(owner: int) -> int:
	var n := 0
	for u in units:
		if u.alive and u.owner == owner:
			n += 1
	return n


func ability_active(owner: int) -> bool:
	return _ability_used[owner] and tick < _ability_until[owner]


# --- setup -------------------------------------------------------------------

func _spawn(owner: int, army: Army) -> void:
	var rows: Array[Array] = [[], [], []]
	for id in army.ids_sorted():
		var data := GameDB.unit(id)
		for i in army.count(id):
			rows[data.unit_class].append(data)
	for row in 3:
		var list: Array = rows[row]
		var lines := ceili(list.size() / float(_cfg.units_per_line))
		for line in lines:
			var start := line * _cfg.units_per_line
			var n := mini(_cfg.units_per_line, list.size() - start)
			var dist := _cfg.row_distance[row] + line * _cfg.row_line_spacing
			var y := _cfg.arena_height / 2 + (dist if owner == 0 else -dist)
			for i in n:
				var x := _cfg.arena_width * (i + 1) / (n + 1)
				_add_unit(owner, list[start + i], army.level(list[start + i].id), x, y)


func _add_unit(owner: int, data: UnitData, level: int, x: int, y: int) -> void:
	var u := SimUnit.new()
	var mult := 100 + _cfg.evolution_bonus_pct * (level - 1)
	u.uid = units.size()
	u.owner = owner
	u.data = data
	u.x = x * SCALE
	u.y = y * SCALE
	u.next_x = u.x
	u.next_y = u.y
	u.max_hp = data.hp * mult / 100
	u.hp = u.max_hp
	u.damage = data.damage * mult / 100
	u.armor = data.armor
	var base := _bases[owner]
	if base.passive == BaseData.Passive.ARMOR_BONUS and data.faction == base.faction:
		u.armor += base.passive_value
	u.interval = maxi(1, _seconds_to_ticks(data.attack_interval))
	u.attack_range = data.attack_range * SCALE
	u.speed = data.speed * SCALE / _cfg.ticks_per_second
	units.append(u)


# --- per-unit behaviour ------------------------------------------------------

func _act(u: SimUnit, hits: Array[Array]) -> void:
	u.next_x = u.x
	u.next_y = u.y
	if u.cooldown > 0:
		u.cooldown -= 1
	u.retarget_in -= 1
	if u.data.is_healer():
		_act_healer(u, hits)
		return
	if u.target < 0 or not units[u.target].alive or u.retarget_in <= 0:
		u.target = _pick_enemy(u)
		u.retarget_in = RETARGET_TICKS
	if u.target < 0:
		return
	var t := units[u.target]
	if _dist_sq(u, t) > u.attack_range * u.attack_range:
		_move_towards(u, t)
	elif u.cooldown == 0:
		u.cooldown = _effective_interval(u)
		var dmg := _damage_after_armor(u, t)
		hits.append([u.uid, t.uid, dmg])
		if u.data.splash_radius > 0:
			var r := u.data.splash_radius * SCALE
			for e in units:
				if e.alive and e.owner != u.owner and e.uid != t.uid and not e.data.is_flying() and _dist_sq(t, e) <= r * r:
					hits.append([u.uid, e.uid, _damage_after_armor(u, e) / 2])


func _act_healer(u: SimUnit, hits: Array[Array]) -> void:
	var patient := _pick_patient(u)
	if patient >= 0:
		var p := units[patient]
		if _dist_sq(u, p) > u.attack_range * u.attack_range:
			_move_towards(u, p)
		elif u.cooldown == 0:
			u.cooldown = _effective_interval(u)
			hits.append([u.uid, p.uid, -u.damage])
		return
	# Nobody to heal: follow the army, staying at own range from the nearest enemy.
	var enemy := _pick_enemy(u)
	if enemy >= 0 and _dist_sq(u, units[enemy]) > u.attack_range * u.attack_range:
		_move_towards(u, units[enemy])


func _pick_enemy(u: SimUnit) -> int:
	# Flankers go for ranged/special units first, everyone else takes the nearest.
	if u.data.is_flanker():
		var back := _nearest(u, func(e: SimUnit) -> bool: return e.data.unit_class != UnitData.UnitClass.MELEE)
		if back >= 0:
			return back
	return _nearest(u, func(_e: SimUnit) -> bool: return true)


func _nearest(u: SimUnit, filter: Callable) -> int:
	var best := -1
	var best_d := 0
	for e in units:
		if not e.alive or e.owner == u.owner:
			continue
		if e.data.is_flying() and not u.data.can_hit_air():
			continue
		if not filter.call(e):
			continue
		var d := _dist_sq(u, e)
		if best < 0 or d < best_d:
			best = e.uid
			best_d = d
	return best


func _pick_patient(u: SimUnit) -> int:
	var best := -1
	var best_ratio := 1000
	for a in units:
		if not a.alive or a.owner != u.owner or a.hp >= a.max_hp:
			continue
		var ratio := a.hp * 1000 / a.max_hp
		if ratio < best_ratio:
			best = a.uid
			best_ratio = ratio
	return best


func _move_towards(u: SimUnit, t: SimUnit) -> void:
	var dx := t.x - u.x
	var dy := t.y - u.y
	var dist := int(sqrt(float(dx * dx + dy * dy)))
	if dist == 0:
		return
	var step := mini(u.speed * _speed_pct(u) / 100, maxi(0, dist - u.attack_range + SCALE))
	u.next_x = u.x + dx * step / dist
	u.next_y = u.y + dy * step / dist


func _damage_after_armor(u: SimUnit, t: SimUnit) -> int:
	var dmg := u.damage * (100 + u.rage * _bases[u.owner].rage_pct_per_stack) / 100
	if u.data.armor_pierce:
		return dmg
	return maxi(dmg - t.armor, maxi(1, dmg / 5))


# --- buffs -------------------------------------------------------------------

func _speed_pct(u: SimUnit) -> int:
	var base := _bases[u.owner]
	if base.ability == BaseData.Ability.WAR_DRUMS and ability_active(u.owner):
		return 100 + base.ability_power
	return 100


func _effective_interval(u: SimUnit) -> int:
	var base := _bases[u.owner]
	var bonus := 0
	if ability_active(u.owner):
		match base.ability:
			BaseData.Ability.WAR_DRUMS:
				bonus = base.ability_power / 2
			BaseData.Ability.RALLY_BANNER:
				bonus = base.ability_power
	return maxi(1, u.interval * 100 / (100 + bonus))


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
	for h in hits:
		var src := units[h[0]]
		var t := units[h[1]]
		var amount: int = h[2]
		if amount < 0:
			var healed := mini(-amount, t.max_hp - t.hp)
			t.hp += healed
			events.append({"type": "heal", "src": src.uid, "dst": t.uid, "amount": healed})
		elif t.hp > 0:
			var dealt := mini(amount, t.hp)
			t.hp -= dealt
			result.damage_dealt[src.owner] += dealt
			events.append({"type": "hit", "src": src.uid, "dst": t.uid, "amount": dealt})
	for u in units:
		if u.alive and u.hp <= 0:
			u.alive = false
			events.append({"type": "death", "dst": u.uid})
			_on_death(u)


func _on_death(dead: SimUnit) -> void:
	var base := _bases[dead.owner]
	if base.passive != BaseData.Passive.RAGE_ON_ALLY_DEATH or dead.data.faction != base.faction:
		return
	for u in units:
		if u.alive and u.owner == dead.owner and u.data.faction == base.faction:
			u.rage = mini(u.rage + 1, base.passive_value)


func _check_end() -> void:
	var a0 := alive_count(0)
	var a1 := alive_count(1)
	if a0 > 0 and a1 > 0 and tick < _max_ticks:
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
