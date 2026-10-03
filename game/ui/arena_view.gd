class_name ArenaView
extends Node2D
## Draws a BattleSim: units (placeholder shapes), bases, attack effects and the fog of war.
## Player 0 (the local player) is always at the bottom.

const MY_OUTLINE := Color(1, 1, 1, 0.9)
const ENEMY_OUTLINE := Color(0.9, 0.2, 0.2, 0.9)
const BASE_H := 34.0

var sim: BattleSim
## 0..1, interpolation between the previous and current tick.
var interp := 1.0
var fog_alpha := 0.0
var base_names: Array[String] = ["", ""]
var base_colors: Array[Color] = [Color.GRAY, Color.GRAY]
var width := 720.0
var height := 900.0

var _prev := {}
var _effects: Array[Dictionary] = []
var _base_flash: Array[float] = [0.0, 0.0]
var _base_glow: Array[float] = [0.0, 0.0]
var _shake := 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func show_sim(s: BattleSim) -> void:
	sim = s
	_effects.clear()
	_snapshot()
	interp = 1.0


func before_step() -> void:
	_snapshot()


## Turns the sim's last-step events into short-lived visual effects.
func after_step() -> void:
	for e in sim.events:
		match e.type:
			"hit":
				var src := sim.units[e.src]
				var ranged := src.data.unit_class != UnitData.UnitClass.MELEE or src.data.is_flying()
				_effects.append({"type": "tracer" if ranged else "spark", "src": e.src, "dst": e.dst, "t": 0.12})
			"heal":
				_effects.append({"type": "heal", "src": e.src, "dst": e.dst, "t": 0.25})
			"death":
				_effects.append({"type": "death", "pos": _pos(sim.units[e.dst]), "t": 0.5,
					"color": GameDB.faction(sim.units[e.dst].data.faction).color})
			"ability":
				var names := {BaseData.Ability.RALLY_BANNER: "SZTANDAR!", BaseData.Ability.WAR_DRUMS: "BĘBNY WOJENNE!"}
				_effects.append({"type": "text", "owner": e.owner, "text": names.get(e.ability, ""), "t": 1.5})


func base_hit(owner: int) -> void:
	_base_flash[owner] = 1.2
	_shake = 0.5


func base_win(owner: int) -> void:
	_base_glow[owner] = 1.6


func _process(delta: float) -> void:
	for e in _effects:
		e.t -= delta
	_effects = _effects.filter(func(e: Dictionary) -> bool: return e.t > 0.0)
	for i in 2:
		_base_flash[i] = maxf(0.0, _base_flash[i] - delta)
		_base_glow[i] = maxf(0.0, _base_glow[i] - delta)
	_shake = maxf(0.0, _shake - delta)
	queue_redraw()


func _draw() -> void:
	var off := Vector2(randf_range(-6, 6), randf_range(-6, 6)) * _shake if _shake > 0.0 else Vector2.ZERO
	draw_set_transform(off)
	draw_rect(Rect2(0, 0, width, height), Color("23262f"))
	draw_line(Vector2(0, height / 2), Vector2(width, height / 2), Color(1, 1, 1, 0.07), 2.0)
	_draw_base(0, Rect2(0, height - BASE_H, width, BASE_H))
	_draw_base(1, Rect2(0, 0, width, BASE_H))
	if sim != null:
		for u in sim.units:
			if u.alive:
				_draw_unit(u)
		_draw_effects()
	if fog_alpha > 0.0:
		draw_rect(Rect2(0, BASE_H, width, height / 2 - BASE_H), Color(0.06, 0.07, 0.09, fog_alpha))
		var c := Color(1, 1, 1, 0.35 * fog_alpha)
		draw_string(_font, Vector2(0, height / 4 + 30), "?", HORIZONTAL_ALIGNMENT_CENTER, width, 96, c)
		draw_string(_font, Vector2(0, height / 4 + 80), "Mgła wojny", HORIZONTAL_ALIGNMENT_CENTER, width, 22, c)


func _draw_base(owner: int, r: Rect2) -> void:
	var col := base_colors[owner].darkened(0.45)
	if _base_flash[owner] > 0.0 and fmod(_base_flash[owner], 0.24) > 0.12:
		col = Color(0.85, 0.15, 0.15)
	if _base_glow[owner] > 0.0:
		col = col.lerp(Color(1.0, 0.82, 0.3), 0.6 * _base_glow[owner] / 1.6)
	draw_rect(r, col)
	draw_string(_font, r.position + Vector2(0, r.size.y * 0.7), base_names[owner], HORIZONTAL_ALIGNMENT_CENTER, width, 18, Color(1, 1, 1, 0.8))


func _draw_unit(u: BattleSim.SimUnit) -> void:
	var p := _pos(u)
	var s := float(u.data.size)
	var fill := GameDB.faction(u.data.faction).color
	var outline := MY_OUTLINE if u.owner == 0 else ENEMY_OUTLINE
	if u.data.is_flying():
		draw_circle(p + Vector2(0, s * 1.4), s * 0.7, Color(0, 0, 0, 0.35))
	var pts: PackedVector2Array
	match u.data.unit_class:
		UnitData.UnitClass.MELEE:
			pts = PackedVector2Array([p + Vector2(-s, -s), p + Vector2(s, -s), p + Vector2(s, s), p + Vector2(-s, s)])
		UnitData.UnitClass.RANGED:
			var dir := -1.0 if u.owner == 0 else 1.0
			pts = PackedVector2Array([p + Vector2(0, s * 1.2 * dir), p + Vector2(s, -s * 0.8 * dir), p + Vector2(-s, -s * 0.8 * dir)])
		_:
			pts = PackedVector2Array([p + Vector2(0, -s * 1.2), p + Vector2(s * 1.2, 0), p + Vector2(0, s * 1.2), p + Vector2(-s * 1.2, 0)])
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, outline, 2.0)
	if u.hp < u.max_hp:
		var w := s * 2.0
		draw_rect(Rect2(p + Vector2(-s, -s - 7), Vector2(w, 3)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(p + Vector2(-s, -s - 7), Vector2(w * u.hp / u.max_hp, 3)), Color(0.3, 0.9, 0.3))
	if u.damage != u.data.damage:
		draw_circle(p, 3.0, Color(1.0, 0.82, 0.3))


func _draw_effects() -> void:
	for e in _effects:
		match e.type:
			"tracer":
				draw_line(_pos(sim.units[e.src]), _pos(sim.units[e.dst]), Color(1.0, 0.9, 0.5, 0.8), 2.0)
			"spark":
				draw_circle(_pos(sim.units[e.dst]), 5.0, Color(1, 1, 1, 0.8))
			"heal":
				draw_line(_pos(sim.units[e.src]), _pos(sim.units[e.dst]), Color(0.4, 1.0, 0.5, 0.7), 3.0)
			"death":
				var a: float = e.t / 0.5
				var c: Color = e.color
				draw_circle(e.pos, 14.0 * (2.0 - a), Color(c.r, c.g, c.b, 0.4 * a))
			"text":
				var y := height - BASE_H - 30 if e.owner == 0 else BASE_H + 40
				draw_string(_font, Vector2(0, y), e.text, HORIZONTAL_ALIGNMENT_CENTER, width, 30, Color(1.0, 0.85, 0.3, minf(1.0, e.t)))


func _snapshot() -> void:
	_prev.clear()
	if sim == null:
		return
	for u in sim.units:
		_prev[u.uid] = Vector2(u.x, u.y) / BattleSim.SCALE


func _pos(u: BattleSim.SimUnit) -> Vector2:
	var cur := Vector2(u.x, u.y) / BattleSim.SCALE
	return (_prev.get(u.uid, cur) as Vector2).lerp(cur, interp)
