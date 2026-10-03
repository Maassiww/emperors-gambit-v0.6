extends TestCase

var decks := [
	[&"bastion", &"szturmowiec", &"strzelec", &"lancer", &"medyk"],
	[&"pancerniak", &"szaleniec", &"siekacz", &"rakieciarz", &"lotniak"],
]
var bases: Array[StringName] = [&"citadel", &"war_camp"]


func _draft_all(m: Match, choice: int = 0) -> void:
	for i in m.cfg.moves_per_round:
		for p in 2:
			m.submit(p, choice)


func test_hold_gives_favor_and_no_units() -> void:
	var m := Match.new(decks, bases, 1)
	m.submit(0, Match.HOLD)
	assert_eq(m.players[0].favor, m.cfg.favor_per_hold)
	assert_eq(m.players[0].army.total(), 0)


func test_fog_hides_current_draft() -> void:
	var m := Match.new(decks, bases, 2)
	_draft_all(m)
	assert_true(m.players[0].army.total() > 0, "player 0 drafted nothing")
	assert_eq((m.view_for(1).opponent.army as Army).total(), 0, "opponent draft visible before battle")
	m.play_battle()
	assert_eq((m.view_for(1).opponent.army as Army).total(), m.players[0].army.total(), "army not revealed after battle")


func test_battle_only_after_all_moves() -> void:
	var m := Match.new(decks, bases, 3)
	m.submit(0, 0)
	m.submit(1, 0)
	assert_eq(m.phase, Match.Phase.DRAFT)
	_draft_all(m)
	assert_eq(m.phase, Match.Phase.BATTLE)
	assert_true(not m.submit(0, 0), "move accepted during battle")


func test_loser_loses_one_hp() -> void:
	var m := Match.new(decks, bases, 4)
	_draft_all(m)
	var r := m.play_battle()
	assert_eq(m.players[1 - r.winner].hp, m.cfg.start_hp - 1)
	assert_eq(m.players[r.winner].hp, m.cfg.start_hp)


func test_match_ends_within_five_rounds() -> void:
	for s in 20:
		var m := Match.new(decks, bases, 100 + s)
		while m.phase != Match.Phase.FINISHED:
			_draft_all(m)
			m.play_battle()
		assert_true(m.round_number <= 5, "too many rounds: %d" % m.round_number)
		assert_eq(m.players[1 - m.winner].hp, 0)


func test_sudden_death_mode() -> void:
	GameDB.ensure_loaded()
	var cfg: GameConfig = GameDB.config.duplicate()
	cfg.draw_mode = GameConfig.DrawMode.DRAW_SUDDEN_DEATH
	var m := Match.new(decks, bases, 5, cfg)
	for i in cfg.max_rounds:
		_draft_all(m)
		var draw := BattleSim.Result.new()
		draw.outcome = BattleSim.Outcome.COIN
		draw.winner = 0
		m.finish_round(draw)
	assert_true(m.sudden_death, "no sudden death after 5 draws")
	assert_eq(m.players[0].hp, 3, "draw cost HP")
	_draft_all(m)
	var win := BattleSim.Result.new()
	win.outcome = BattleSim.Outcome.ELIMINATION
	win.winner = 1
	m.finish_round(win)
	assert_eq(m.phase, Match.Phase.FINISHED)
	assert_eq(m.winner, 1)


func test_whole_match_deterministic() -> void:
	var logs := []
	for run in 2:
		var m := Match.new(decks, bases, 77)
		var bots := [Bot.new(1), Bot.new(2)]
		while m.phase != Match.Phase.FINISHED:
			while m.phase == Match.Phase.DRAFT:
				for p in 2:
					if m.moves_left(p) > 0:
						m.submit(p, bots[p].choose(m.view_for(p)))
			m.play_battle()
		logs.append(str(m.history))
	assert_eq(logs[0], logs[1], "same seed, different match")
