extends SceneTree
## Screenshot of zones and slow labels. Needs xvfb-run.
## godot --path game --script res://tests/shot_zones.gd -- <out.png>


func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	GameDB.ensure_loaded()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var armies: Array[Army] = [Army.new(), Army.new()]
	armies[0].add(&"pancerniak", 2)
	armies[0].add(&"rakieciarz", 2)
	armies[1].add(&"szturmowiec", 4)
	armies[1].add(&"strzelec", 2)
	var bases: Array[BaseData] = [GameDB.base(&"war_camp"), GameDB.base(&"citadel")]
	var sim := BattleSim.new(armies, bases, GameDB.config, rng)
	var mud := TraitData.new()
	mud.radius = 45
	mud.duration = 30.0
	mud.slow_pct = 20
	mud.stacks = 1
	var src := sim.units[0].uid
	for p in [Vector2(260, 380), Vector2(320, 400), Vector2(500, 420)]:
		sim._add_zone(0, int(p.x) * BattleSim.SCALE, int(p.y) * BattleSim.SCALE, mud, src)
	sim._place_zones()
	for u in sim.units:
		if u.owner == 1:
			sim._add_status(u, BattleSim.Effect.SLOW, 30, 200)
	var arena := ArenaView.new()
	arena.width = 720
	arena.height = 1280
	root.add_child(arena)
	arena.show_sim(sim)
	for i in 30:
		sim.step()
	arena.queue_redraw()
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit(0)
