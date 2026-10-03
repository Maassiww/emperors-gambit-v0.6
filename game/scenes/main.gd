extends Control
## Main menu (prototype): pick a faction, play against the bot.

const DECKS := {
	&"humans": [&"bastion", &"szturmowiec", &"strzelec", &"lancer", &"medyk"],
	&"orks": [&"pancerniak", &"szaleniec", &"siekacz", &"rakieciarz", &"lotniak"],
}
const BASES := {&"humans": &"citadel", &"orks": &"war_camp"}

var _menu: VBoxContainer
var _match: MatchScreen


func _ready() -> void:
	GameDB.ensure_loaded()
	var t := Theme.new()
	t.default_font_size = 24
	theme = t
	var bg := ColorRect.new()
	bg.color = Color("16181e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_menu = VBoxContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.offset_left = 80
	_menu.offset_right = -80
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_theme_constant_override("separation", 24)
	add_child(_menu)

	var title := Label.new()
	title.text = "EMPEROR'S GAMBIT"
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(title)
	var sub := Label.new()
	sub.text = "Prototyp: mecz z botem\nWybierz frakcję"
	sub.modulate = Color(1, 1, 1, 0.6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(sub)
	_menu.add_child(_faction_button(&"humans", "Graj: Ludzie"))
	_menu.add_child(_faction_button(&"orks", "Graj: Orkowie"))
	var version := Label.new()
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version")
	version.modulate = Color(1, 1, 1, 0.4)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(version)


func _faction_button(faction: StringName, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 90
	var style := StyleBoxFlat.new()
	style.bg_color = GameDB.faction(faction).color.darkened(0.4)
	style.set_corner_radius_all(12)
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, style)
	b.pressed.connect(_start.bind(faction))
	return b


func _start(faction: StringName) -> void:
	var enemy: StringName = &"orks" if faction == &"humans" else &"humans"
	_match = MatchScreen.new()
	var bases: Array[StringName] = [BASES[faction], BASES[enemy]]
	_match.setup([DECKS[faction], DECKS[enemy]], bases, randi())
	_match.exit_requested.connect(_back_to_menu)
	_menu.visible = false
	add_child(_match)


func _back_to_menu() -> void:
	_match.queue_free()
	_match = null
	_menu.visible = true
