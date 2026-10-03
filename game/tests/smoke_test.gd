extends SceneTree
## Headless smoke test: main scene loads, runs a few frames, starts a match and plays a round.
## Any engine/script error fails it. Run: godot --headless --path game --script res://tests/smoke_test.gd


func _initialize() -> void:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("main.tscn failed to load")
		quit(1)
		return
	var main := scene.instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	# Start a match from the deck screen and click through one draft round.
	var deck: Array[StringName] = [&"bastion", &"zabojca", &"najemnik", &"siekacz", &"lancer"]
	main._start(deck, &"citadel")
	var m: MatchScreen = main._match
	for i in GameDB.config.moves_per_round:
		await process_frame
		m._on_pick(0)
	# Reveal + a few seconds of battle (arena draws rings, statuses, effects).
	await create_timer(MatchScreen.REVEAL_TIME + 4.0).timeout
	if m.state != MatchScreen.State.BATTLE and m.state != MatchScreen.State.RESULT:
		catcher.errors.append("match did not reach the battle (state %d)" % m.state)
	if not catcher.errors.is_empty():
		for e in catcher.errors:
			print("ERROR ", e)
		quit(1)
		return
	print("SMOKE OK")
	quit(0)
