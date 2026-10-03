class_name DeckScreen
extends Control
## Menu + deck builder: pick a base and a legal deck, then play the bot.
## The last loadout is saved to user:// and restored on the next start.

signal play_requested(deck: Array[StringName], base: StringName)

const SAVE_PATH := "user://loadout.cfg"
const SECTIONS := [[&"humans", "Ludzie"], [&"orks", "Orkowie"], [&"neutral", "Bezfrakcyjni"]]
const DEFAULT_DECK: Array[StringName] = [&"bastion", &"szturmowiec", &"strzelec", &"lancer", &"medyk"]

var cfg: GameConfig
var _deck: Array[StringName] = []
var _base: StringName = &"citadel"
var _info: Label
var _play: Button
var _card_buttons := {}
var _base_buttons := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cfg = GameDB.config
	_rng.randomize()
	_load()
	_build()
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("16181e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = "EMPEROR'S GAMBIT  ·  v%s" % ProjectSettings.get_setting("application/config/version")
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(1, 1, 1, 0.5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	root.add_child(_header("Baza"))
	var bases := HBoxContainer.new()
	bases.add_theme_constant_override("separation", 10)
	root.add_child(bases)
	for id in GameDB.base_ids_sorted():
		var base := GameDB.base(id)
		var b := _tile(GameDB.faction(base.faction).color, 92)
		var labels := MatchScreen.card_labels(b, [[18, Color.WHITE], [12, Color(1, 1, 1, 0.75)]])
		labels[0].text = base.display_name
		labels[1].text = base.blurb
		b.pressed.connect(func() -> void:
			_base = id
			_refresh())
		bases.add_child(b)
		_base_buttons[id] = b

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_info)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for section in SECTIONS:
		list.add_child(_header(section[1]))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		list.add_child(grid)
		for id in GameDB.card_ids_sorted():
			var u := GameDB.unit(id)
			if u.faction != section[0]:
				continue
			var b := _tile(GameDB.faction(u.faction).color, 128)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var labels := MatchScreen.card_labels(b, [[17, Color.WHITE], [12, Color(1, 1, 1, 0.6)], [11, Color(1, 1, 1, 0.85)]])
			labels[0].text = u.display_name
			labels[1].text = "×%d · %s" % [u.count_per_pick, UnitData.ROLE_NAMES[u.role]]
			labels[2].text = u.blurb
			b.pressed.connect(_toggle.bind(id))
			grid.add_child(b)
			_card_buttons[id] = b

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)
	var random := Button.new()
	random.text = "Losuj"
	random.custom_minimum_size = Vector2(180, 76)
	random.pressed.connect(func() -> void:
		_deck = Bot.random_deck(_rng)
		_refresh())
	actions.add_child(random)
	_play = Button.new()
	_play.text = "GRAJ  ▶"
	_play.custom_minimum_size.y = 76
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.add_theme_font_size_override("font_size", 28)
	_play.pressed.connect(func() -> void:
		_save()
		play_requested.emit(_deck.duplicate(), _base))
	actions.add_child(_play)


func _toggle(id: StringName) -> void:
	if id in _deck:
		_deck.erase(id)
	elif _deck.size() < cfg.deck_size:
		_deck.append(id)
	_refresh()


func _refresh() -> void:
	var specials := _deck.filter(func(id: StringName) -> bool: return GameDB.unit(id).is_special()).size()
	var error := GameDB.deck_error(_deck)
	_info.text = "Deck %d/%d  ·  speciale %d/%d" % [_deck.size(), cfg.deck_size, specials, cfg.max_specials_in_deck]
	if error != "" and _deck.size() == cfg.deck_size:
		_info.text += "  ·  " + error
	_info.add_theme_color_override("font_color", Color(1, 0.5, 0.45) if specials > cfg.max_specials_in_deck else Color.WHITE)
	_play.disabled = error != ""
	for id in _card_buttons:
		_style(_card_buttons[id], GameDB.faction(GameDB.unit(id).faction).color, id in _deck)
	for id in _base_buttons:
		_style(_base_buttons[id], GameDB.faction(GameDB.base(id).faction).color, id == _base)


func _tile(color: Color, height: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	_style(b, color, false)
	return b


func _style(b: Button, color: Color, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.35 if selected else 0.7)
	style.border_color = Color(1.0, 0.82, 0.3) if selected else Color(1, 1, 1, 0.15)
	style.set_border_width_all(4 if selected else 1)
	style.set_corner_radius_all(10)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, style)


func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.modulate = Color(1, 1, 1, 0.7)
	return l


func _load() -> void:
	var f := ConfigFile.new()
	var deck: Array[StringName] = DEFAULT_DECK.duplicate()
	if f.load(SAVE_PATH) == OK:
		var saved: Array[StringName] = []
		for id in f.get_value("loadout", "deck", []):
			saved.append(StringName(id))
		if GameDB.deck_error(saved) == "":
			deck = saved
		var base := StringName(f.get_value("loadout", "base", "citadel"))
		if GameDB.bases.has(base):
			_base = base
	_deck = deck


func _save() -> void:
	var f := ConfigFile.new()
	var ids: Array[String] = []
	for id in _deck:
		ids.append(String(id))
	f.set_value("loadout", "deck", ids)
	f.set_value("loadout", "base", String(_base))
	f.save(SAVE_PATH)
