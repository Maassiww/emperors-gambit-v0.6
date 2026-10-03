extends SceneTree
## Screenshots of the match screen: draft (fog) and mid-battle. Needs xvfb-run.
## godot --path game --script res://tests/shot_match.gd -- <out_dir>


func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	GameDB.ensure_loaded()
	var t := Theme.new()
	t.default_font_size = 24
	var holder := Control.new()
	holder.theme = t
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var m := MatchScreen.new()
	var bases: Array[StringName] = [&"citadel", &"war_camp"]
	m.setup([
		[&"bastion", &"szturmowiec", &"strzelec", &"lancer", &"medyk"],
		[&"pancerniak", &"szaleniec", &"siekacz", &"rakieciarz", &"lotniak"],
	], bases, 3)
	holder.add_child(m)
	# Round 1 straight to round 2 draft, so both sides have units on screen.
	for i in 3:
		await _frames(5)
		m._on_pick(0)
	while m.state != MatchScreen.State.DRAFT or m.game.round_number < 2:
		await process_frame
	m._on_pick(0)
	await _frames(20)
	await _save(out + "/draft.png")
	m._on_pick(1)
	m._on_pick(0)
	await _frames(int(60 * (MatchScreen.REVEAL_TIME + 1.2)))
	await _save(out + "/battle.png")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("SAVED ", path)
