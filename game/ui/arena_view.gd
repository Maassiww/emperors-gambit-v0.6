class_name ArenaView
extends Node2D
## Draws a BattleSim: units (placeholder shapes), bases, attack effects and the fog of war.
## Player 0 (the local player) is always at the bottom.

const MY_OUTLINE := Color(1, 1, 1, 0.9)
const ENEMY_OUTLINE := Color(0.9, 0.2, 0.2, 0.9)
const BASE_H := 34.0
const TAUNT_RING := Color(1, 1, 1, 0.55)
const PSI := Color(0.75, 0.45, 1.0)
const FIRE := Color(1.0, 0.55, 0.15)
const STATUS_NAMES := {
	BattleSim.Effect.STUN: "ogłuszenie",
	BattleSim.Effect.CORROSION: "korozja",
	BattleSim.Effect.MARK: "oznaczenie",
}
const CONTRACT_LEVELS := ["Kontrakt: brak", "Kontrakt I", "Kontrakt II"]

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
				if e.area:
					continue
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
			"teleport":
				var from := Vector2(e.from) / BattleSim.SCALE
				var to := Vector2(e.to) / BattleSim.SCALE
				_prev[e.src] = to
				_effects.append({"type": "teleport", "from": from, "to": to, "t": 0.4})
			"pulse":
				_effects.append({"type": "ring", "pos": Vector2(e.pos) / BattleSim.SCALE, "r": float(e.r), "color": PSI, "t": 0.5, "len": 0.5})
			"explode", "blast":
				_effects.append({"type": "boom", "pos": Vector2(e.pos) / BattleSim.SCALE, "r": float(e.r), "t": 0.45})
			"build":
				_effects.append({"type": "ring", "pos": _pos(sim.units[e.dst]), "r": 18.0, "color": Color(1.0, 0.85, 0.3), "t": 0.4, "len": 0.4})


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
		_draw_rings()
		for u in sim.units:
			if u.alive:
				_draw_unit(u)
		for u in sim.units:
			if u.alive:
				_draw_unit_labels(u)
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
	if u.data.is_summon:
		draw_circle(p, s, fill.darkened(0.25))
		draw_arc(p, s, 0, TAU, 20, outline, 2.0)
		draw_line(p, p + Vector2(0, -s * 1.4 if u.owner == 0 else s * 1.4), outline, 3.0)
		_draw_hp(u, p, s)
		return
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
	# Subclass marks: armored core for heavy melee, dot for stationary artillery.
	if u.data.role == UnitData.Role.HEAVY:
		draw_rect(Rect2(p - Vector2(s, s) * 0.45, Vector2(s, s) * 0.9), fill.darkened(0.45))
	elif u.data.role == UnitData.Role.SLOW:
		draw_circle(p, s * 0.32, fill.darkened(0.55))
	if u.data.glyph != "":
		var fs := int(s * 1.3)
		draw_string(_font, p + Vector2(-s * 2, fs * 0.36), u.data.glyph, HORIZONTAL_ALIGNMENT_CENTER, s * 4, fs, Color(0.05, 0.05, 0.08, 0.9))
	if sim.has_status(u, BattleSim.Effect.STUN):
		draw_arc(p, s + 3, 0, TAU, 16, PSI, 2.0)
	_draw_hp(u, p, s)
	if u.data.is_evolution:
		draw_circle(p + Vector2(s * 0.7, -s * 0.7), 3.0, Color(1.0, 0.82, 0.3))


func _draw_hp(u: BattleSim.SimUnit, p: Vector2, s: float) -> void:
	if u.hp < u.max_hp:
		var w := s * 2.0
		draw_rect(Rect2(p + Vector2(-s, -s - 7), Vector2(w, 3)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(p + Vector2(-s, -s - 7), Vector2(w * u.hp / u.max_hp, 3)), Color(0.3, 0.9, 0.3))


## Above the unit: timed effects (name + white bar of the time left).
## Below: standing state worth knowing (contract level, weakened aura).
func _draw_unit_labels(u: BattleSim.SimUnit) -> void:
	var p := _pos(u)
	var s := float(u.data.size)
	var y := p.y - s - 10
	for effect in STATUS_NAMES:
		if not sim.has_status(u, effect):
			continue
		var st: BattleSim.StatusEffect = u.statuses[effect]
		var text: String = STATUS_NAMES[effect]
		if effect == BattleSim.Effect.CORROSION:
			text += " ×%d" % st.power
		draw_string(_font, Vector2(p.x - 40, y), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(1, 1, 1, 0.85))
		var left := clampf((st.until - sim.tick - interp + 1.0) / maxf(1.0, st.length), 0.0, 1.0)
		draw_rect(Rect2(p.x - 12, y + 2, 24 * left, 2), Color(1, 1, 1, 0.9))
		y -= 15
	# Standing notes matter while drafting and at the reveal; in battle they would only clutter.
	if sim.tick > 0:
		return
	var note := ""
	if u.data.faction == UnitData.NEUTRAL and not u.data.is_summon:
		note = CONTRACT_LEVELS[mini(sim.factions_on_board(u.owner), 2)]
	else:
		for t in u.data.traits:
			if t.kind == TraitData.Kind.AURA and t.scales_with_purity and u.aura_pct < 100:
				note = "%s %d%%" % [t.label, u.aura_pct]
	if note != "":
		draw_string(_font, Vector2(p.x - 60, p.y + s + 13), note, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(1, 0.9, 0.6, 0.85))


## Taunt and aura ranges. Rings of the same effect and side merge into one outline:
## only the arcs of each circle that lie outside every other circle of its group are drawn.
func _draw_rings() -> void:
	var groups := {}
	for u in sim.units:
		if not u.alive:
			continue
		for t in u.traits:
			var key := ""
			var color: Color
			if t.kind == TraitData.Kind.TAUNT:
				key = "taunt%d" % u.owner
				color = TAUNT_RING
			elif t.kind == TraitData.Kind.AURA and (not t.scales_with_purity or u.aura_pct > 0):
				key = "aura%d%s" % [u.owner, u.data.faction]
				color = GameDB.faction(u.data.faction).color.lightened(0.3)
				color.a = 0.45
			else:
				continue
			if not groups.has(key):
				groups[key] = {"color": color, "circles": []}
			groups[key].circles.append(Vector3(_pos(u).x, _pos(u).y, t.radius))
	for key in groups:
		_draw_union_outline(groups[key].circles, groups[key].color)


func _draw_union_outline(circles: Array, color: Color) -> void:
	for i in circles.size():
		var c: Vector3 = circles[i]
		var center := Vector2(c.x, c.y)
		var n := maxi(24, int(c.z / 4.0))
		var prev_ok := false
		var prev := Vector2.ZERO
		for k in n + 1:
			var pt := center + Vector2.from_angle(TAU * k / n) * c.z
			var ok := true
			for j in circles.size():
				var o: Vector3 = circles[j]
				if j != i and pt.distance_squared_to(Vector2(o.x, o.y)) < o.z * o.z - 1.0:
					ok = false
					break
			if ok and prev_ok:
				draw_line(prev, pt, color, 2.0)
			prev_ok = ok
			prev = pt


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
			"teleport":
				var a: float = e.t / 0.4
				draw_line(e.from, e.to, Color(PSI.r, PSI.g, PSI.b, 0.5 * a), 2.0)
				draw_circle(e.from, 14.0 * a, Color(PSI.r, PSI.g, PSI.b, 0.5 * a))
				draw_circle(e.to, 18.0 * (1.5 - a), Color(PSI.r, PSI.g, PSI.b, 0.4 * a))
			"ring":
				var a: float = e.t / e.len
				var c: Color = e.color
				draw_arc(e.pos, e.r * (1.2 - 0.4 * a), 0, TAU, 32, Color(c.r, c.g, c.b, a), 3.0)
			"boom":
				var a: float = e.t / 0.45
				draw_circle(e.pos, e.r * (1.1 - 0.3 * a), Color(FIRE.r, FIRE.g, FIRE.b, 0.45 * a))
				draw_arc(e.pos, e.r * (1.1 - 0.3 * a), 0, TAU, 32, Color(1, 0.85, 0.4, a), 2.0)
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
