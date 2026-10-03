extends Control
## M0 placeholder: title screen with two squads marching at each other.
## Proves the build pipeline (web + Android) end to end.

const HUMAN_COLOR := Color("4a90d9")
const ORK_COLOR := Color("6abf4b")
const MARCH_SPEED := 60.0

var _humans: Array[Vector2] = []
var _orks: Array[Vector2] = []


func _ready() -> void:
	var title := Label.new()
	title.text = "EMPEROR'S GAMBIT"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stretch_horizontally(title, 160.0, false)
	add_child(title)

	var version := Label.new()
	version.text = "v%s - prototyp" % ProjectSettings.get_setting("application/config/version")
	version.modulate = Color(1, 1, 1, 0.5)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stretch_horizontally(version, -60.0, true)
	add_child(version)
	resized.connect(_reset_squads)
	_reset_squads()


func _stretch_horizontally(label: Label, offset_y: float, from_bottom: bool) -> void:
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0 if from_bottom else 0.0
	label.anchor_bottom = label.anchor_top
	label.offset_left = 0.0
	label.offset_right = 0.0
	label.offset_top = offset_y
	label.offset_bottom = offset_y


func _reset_squads() -> void:
	var w := size.x
	var h := size.y
	_humans.clear()
	_orks.clear()
	# Humans: few, big. Orks: many, small.
	for i in 3:
		_humans.append(Vector2(w * (0.3 + 0.2 * i), h * 0.85))
	for i in 10:
		_orks.append(Vector2(w * (0.15 + 0.075 * i), h * 0.3 + (i % 2) * 30.0))


func _process(delta: float) -> void:
	for i in _humans.size():
		_humans[i].y -= MARCH_SPEED * delta
	for i in _orks.size():
		_orks[i].y += MARCH_SPEED * 1.3 * delta
	if _humans[0].y - _orks[0].y < 40.0:
		_reset_squads()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1b1d24"))
	draw_line(Vector2(0, size.y * 0.55), Vector2(size.x, size.y * 0.55), Color(1, 1, 1, 0.08), 2.0)
	for p in _humans:
		draw_rect(Rect2(p - Vector2(22, 22), Vector2(44, 44)), HUMAN_COLOR)
	for p in _orks:
		draw_circle(p, 13.0, ORK_COLOR)
