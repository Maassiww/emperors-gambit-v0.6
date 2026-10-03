extends Control
## Root: deck builder as the menu, then a match against a bot playing one of the preset loadouts.

var _deck_screen: DeckScreen
var _match: MatchScreen


func _ready() -> void:
	GameDB.ensure_loaded()
	var t := Theme.new()
	t.default_font_size = 24
	theme = t
	_deck_screen = DeckScreen.new()
	_deck_screen.play_requested.connect(_start)
	add_child(_deck_screen)


func _start(deck: Array[StringName], base: StringName) -> void:
	var opponent: Dictionary = Bot.PRESETS[randi() % Bot.PRESETS.size()]
	_match = MatchScreen.new()
	var bases: Array[StringName] = [base, opponent.base]
	_match.setup([deck, opponent.deck], bases, randi())
	_match.exit_requested.connect(_back_to_menu)
	_deck_screen.visible = false
	add_child(_match)


func _back_to_menu() -> void:
	_match.queue_free()
	_match = null
	_deck_screen.visible = true
