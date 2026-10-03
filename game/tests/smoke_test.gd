extends SceneTree
## Headless smoke test: main scene loads and runs a few frames.
## Run: godot --headless --path game --script res://tests/smoke_test.gd


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("main.tscn failed to load")
		quit(1)
		return
	root.add_child(scene.instantiate())
	for i in 10:
		await process_frame
	print("SMOKE OK")
	quit(0)
