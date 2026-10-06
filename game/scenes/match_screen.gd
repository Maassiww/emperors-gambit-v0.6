class_name MatchScreen
extends Control
## Prototype match: local player (index 0, bottom) vs Bot (index 1, top).
## Drives Match + BattleSim and renders them; all rules live in core/.

signal exit_requested

enum State { DRAFT, REVEAL, BATTLE, RESULT, END }

const TOP_BAR_H := 96
const BOTTOM_H := 300
const REVEAL_TIME := 1.8
const RESULT_TIME := 2.6
const TIER_COLORS := [Color(0.45, 0.47, 0.52), Color(0.75, 0.8, 0.9), Color(1.0, 0.8, 0.3)]

var decks := []
var base_ids: Array[StringName] = []
var seed_value := 0

var game: Match
var bot: Bot
var sim: BattleSim
var state := State.DRAFT
var cfg: GameConfig

var _timer := 0.0
var _tick_acc := 0.0

var arena: ArenaView
var _round_label: Label
var _opp_label: Label
var _opp_info: Label
var _opp_hp: HBoxContainer
var _my_hp: HBoxContainer
var _favor_bar: ProgressBar
var _favor_label: Label
var _status: Label
var _cards: Array[Button] = []
var _gambit_btn: Button
var _timer_bar: ProgressBar
var _banner: Label
var _end_panel: PanelContainer
var _end_label: Label


func setup(p_decks: Array, p_bases: Array[StringName], p_seed: int) -> void:
	decks = p_decks
	base_ids = p_bases
	seed_value = p_seed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cfg = GameDB.config
	_build_ui()
	_start_match()


func _start_match() -> void:
	game = Match.new(decks, base_ids, seed_value)
	bot = Bot.new(seed_value + 7)
	_end_panel.visible = false
	for p in 2:
		arena.base_names[p] = game.players[p].base.display_name
		arena.base_colors[p] = GameDB.faction(game.players[p].base.faction).color
	_favor_label.text = GameDB.faction(game.players[0].base.faction).favor_name
	_start_draft()


# --- flow --------------------------------------------------------------------

func _start_draft() -> void:
	state = State.DRAFT
	# The bot drafts at once; its picks stay hidden by the fog until the reveal.
	while game.moves_left(1) > 0:
		game.submit(1, bot.choose(game.view_for(1)))
	arena.fog_alpha = 0.8
	_gambit_btn.visible = true
	_refresh_preview()
	_next_move()


func _next_move() -> void:
	_timer = cfg.move_time_seconds
	_refresh_hud()
	_refresh_cards()


func _on_pick(choice: int) -> void:
	if state != State.DRAFT or not game.submit(0, choice):
		return
	_refresh_preview()
	if game.moves_left(0) > 0:
		_next_move()
	else:
		_start_reveal()


func _start_reveal() -> void:
	state = State.REVEAL
	_timer = REVEAL_TIME
	_set_cards_visible(false)
	_gambit_btn.visible = false
	_status.text = "Odsłonięcie!"
	sim = game.create_battle()
	arena.show_sim(sim)
	create_tween().tween_property(arena, "fog_alpha", 0.0, 0.8)
	_refresh_hud()


func _start_battle() -> void:
	state = State.BATTLE
	_tick_acc = 0.0
	_status.text = "Walka!"


func _end_battle() -> void:
	state = State.RESULT
	_timer = RESULT_TIME
	game.finish_round(sim.result)
	var h: Dictionary = game.history.back()
	if h.winner == -1:
		_show_banner("REMIS", Color(0.8, 0.8, 0.8))
	elif h.winner == 0:
		arena.base_hit(1)
		arena.base_win(0)
		_show_banner("RUNDA WYGRANA", Color(0.5, 0.9, 0.5))
	else:
		arena.base_hit(0)
		arena.base_win(1)
		_show_banner("RUNDA PRZEGRANA", Color(0.95, 0.4, 0.4))
	_refresh_hud()


func _after_result() -> void:
	_banner.visible = false
	if game.phase == Match.Phase.FINISHED:
		state = State.END
		_end_label.text = "ZWYCIĘSTWO!" if game.winner == 0 else "PORAŻKA"
		_end_panel.visible = true
	else:
		_start_draft()


func _process(delta: float) -> void:
	match state:
		State.DRAFT:
			var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 150.0)
			for b in _cards:
				b.self_modulate = Color(pulse + 0.25, pulse + 0.25, pulse, 1) if b.has_meta("blessed") else Color.WHITE
			_timer -= delta
			_timer_bar.value = _timer / cfg.move_time_seconds * 100.0
			if _timer <= 0.0:
				_on_pick(0)
		State.REVEAL:
			_timer -= delta
			if _timer <= 0.0:
				_start_battle()
		State.BATTLE:
			_tick_acc += delta * cfg.ticks_per_second
			while _tick_acc >= 1.0 and not sim.finished:
				arena.before_step()
				sim.step()
				arena.after_step()
				_tick_acc -= 1.0
			arena.interp = clampf(_tick_acc, 0.0, 1.0)
			if sim.overtime_pct() > 100:
				_status.text = "DOGRYWKA! Obrażenia +%d%%" % (sim.overtime_pct() - 100)
			if sim.finished:
				arena.interp = 1.0
				_end_battle()
		State.RESULT:
			_timer -= delta
			if _timer <= 0.0:
				_after_result()


# --- view refresh ------------------------------------------------------------

## Layout preview while drafting: my real army vs what I know about the opponent.
func _refresh_preview() -> void:
	var view := game.view_for(0)
	var armies: Array[Army] = [view.me.army, view.opponent.army]
	var bases: Array[BaseData] = [game.players[0].base, game.players[1].base]
	arena.show_sim(BattleSim.new(armies, bases, cfg, RandomNumberGenerator.new(), game.purity()))


func _refresh_hud() -> void:
	var view := game.view_for(0)
	_round_label.text = "Runda %d%s" % [view.round, "  NAGŁA ŚMIERĆ" if view.sudden_death else ""]
	_opp_label.text = "Przeciwnik: %s" % game.players[1].base.display_name
	var deck_names: Array[String] = []
	for id in view.opponent.deck:
		deck_names.append(GameDB.unit(id).display_name)
	_opp_info.text = "Talia: %s\nŁaska (ostatnio): %d" % [", ".join(deck_names), view.opponent.favor]
	_set_pips(_opp_hp, view.opponent.hp)
	_set_pips(_my_hp, view.me.hp)
	_favor_bar.value = view.me.favor
	_favor_label.text = "%s  %d/%d" % [GameDB.faction(game.players[0].base.faction).favor_name, view.me.favor, cfg.favor_max]
	_favor_bar.modulate = Color(1.3, 1.2, 0.8) if view.me.favor >= cfg.bless_cost else Color.WHITE
	if state == State.DRAFT:
		_status.text = "Ruch %d/%d: wybierz kartę albo zagraj Gambit" % [cfg.moves_per_round - view.me.moves_left + 1, cfg.moves_per_round]


func _refresh_cards() -> void:
	var offers := game.offers(0)
	var army := game.players[0].army
	_set_cards_visible(true)
	for i in _cards.size():
		var b := _cards[i]
		if i >= offers.size():
			b.visible = false
			continue
		var o: DraftOffer = offers[i]
		var u := GameDB.unit(o.unit_id)
		var tier_text: String = ["", "★ ŁASKA −%d" % cfg.bless_cost, "★★ EWOLUCJA −%d" % cfg.favor_max][o.tier]
		var info: Array[Label] = []
		info.assign(b.get_meta("labels"))
		info[0].text = tier_text
		info[0].visible = o.tier > 0
		info[1].text = o.label()
		info[2].text = "%s · masz: %d" % [UnitData.ROLE_NAMES[u.role], army.count(o.unit_id)]
		(b.get_meta("chips") as TagChips).set_tags(GameDB.unit(o.produces).tags)
		var style := StyleBoxFlat.new()
		style.bg_color = GameDB.faction(u.faction).color.darkened(0.55)
		style.border_color = TIER_COLORS[o.tier]
		style.set_border_width_all(2 + o.tier * 2)
		style.set_corner_radius_all(10)
		for s in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, style)
		if o.tier > 0:
			b.set_meta("blessed", true)
		else:
			b.remove_meta("blessed")


func _set_cards_visible(v: bool) -> void:
	for b in _cards:
		b.visible = v
	_timer_bar.visible = v


func _set_pips(box: HBoxContainer, hp: int) -> void:
	for i in box.get_child_count():
		(box.get_child(i) as ColorRect).color = Color(0.9, 0.25, 0.3) if i < hp else Color(0.25, 0.25, 0.28)


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	_banner.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("16181e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var holder := Control.new()
	holder.position = Vector2(0, TOP_BAR_H)
	add_child(holder)
	arena = ArenaView.new()
	arena.width = cfg.arena_width
	arena.height = cfg.arena_height
	holder.add_child(arena)

	_build_top_bar()
	_build_bottom_panel()

	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 52)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(0, TOP_BAR_H + cfg.arena_height / 2.0 - 40)
	_banner.size = Vector2(cfg.arena_width, 80)
	_banner.pivot_offset = _banner.size / 2
	_banner.visible = false
	add_child(_banner)

	_build_end_panel()


func _build_top_bar() -> void:
	var bar := ColorRect.new()
	bar.color = Color("1e2129")
	bar.position = Vector2.ZERO
	bar.size = Vector2(cfg.arena_width, TOP_BAR_H)
	add_child(bar)
	_opp_label = _label(bar, Vector2(16, 6), 22)
	_opp_info = _label(bar, Vector2(16, 38), 16)
	_opp_info.modulate = Color(1, 1, 1, 0.6)
	_round_label = _label(bar, Vector2(cfg.arena_width - 236, 6), 22)
	_round_label.size.x = 220
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_opp_hp = _pips(bar, Vector2(cfg.arena_width - 100, 46))


func _build_bottom_panel() -> void:
	var panel := ColorRect.new()
	panel.color = Color("1e2129")
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_right = 1.0
	panel.offset_top = -BOTTOM_H
	add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_right = -12
	box.offset_top = 8
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_my_hp = _pips(row, Vector2.ZERO)
	var favor_stack := Control.new()
	favor_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	favor_stack.custom_minimum_size.y = 30
	row.add_child(favor_stack)
	_favor_bar = ProgressBar.new()
	_favor_bar.show_percentage = false
	_favor_bar.max_value = cfg.favor_max
	_favor_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.65, 0.2)
	fill.set_corner_radius_all(6)
	_favor_bar.add_theme_stylebox_override("fill", fill)
	favor_stack.add_child(_favor_bar)
	_favor_label = Label.new()
	_favor_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_favor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_favor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_favor_label.add_theme_font_size_override("font_size", 18)
	_favor_label.add_theme_constant_override("outline_size", 6)
	_favor_label.add_theme_color_override("font_outline_color", Color.BLACK)
	favor_stack.add_child(_favor_label)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	box.add_child(cards)
	for i in cfg.offers_per_move:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 126)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_contents = true
		b.pressed.connect(_on_pick.bind(i))
		cards.add_child(b)
		_cards.append(b)
		var labels := card_labels(b, [[13, Color(1.0, 0.85, 0.4)], [18, Color.WHITE], [12, Color(1, 1, 1, 0.6)]])
		b.set_meta("labels", labels)
		var chips := TagChips.new()
		labels[0].get_parent().add_child(chips)
		b.set_meta("chips", chips)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	_gambit_btn = Button.new()
	_gambit_btn.text = "GAMBIT: wstrzymaj ruch (+%d łaski)" % cfg.favor_per_hold
	_gambit_btn.custom_minimum_size.y = 50
	_gambit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gambit_btn.add_theme_font_size_override("font_size", 19)
	_gambit_btn.pressed.connect(_on_pick.bind(Match.HOLD))
	actions.add_child(_gambit_btn)

	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size.y = 8
	box.add_child(_timer_bar)


func _build_end_panel() -> void:
	_end_panel = PanelContainer.new()
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.custom_minimum_size = Vector2(480, 300)
	_end_panel.position = Vector2(cfg.arena_width / 2.0 - 240, 420)
	add_child(_end_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	_end_panel.add_child(box)
	_end_label = Label.new()
	_end_label.add_theme_font_size_override("font_size", 56)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_label)
	var again := Button.new()
	again.text = "Rewanż"
	again.custom_minimum_size.y = 64
	again.pressed.connect(func() -> void:
		seed_value += 1
		_start_match())
	box.add_child(again)
	var menu := Button.new()
	menu.text = "Menu"
	menu.custom_minimum_size.y = 64
	menu.pressed.connect(func() -> void: exit_requested.emit())
	box.add_child(menu)


## Stacked labels inside a card button (the button itself has no text). specs: [[font_size, color], ...]
static func card_labels(button: Button, specs: Array) -> Array[Label]:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_right = -8
	box.offset_top = 6
	box.offset_bottom = -6
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var out: Array[Label] = []
	for spec in specs:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", spec[0])
		l.add_theme_color_override("font_color", spec[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
		out.append(l)
	return out


func _label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func _pips(parent: Node, pos: Vector2) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.position = pos
	box.add_theme_constant_override("separation", 6)
	for i in cfg.start_hp:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(24, 24)
		box.add_child(r)
	parent.add_child(box)
	return box
