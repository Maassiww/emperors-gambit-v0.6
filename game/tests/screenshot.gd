extends SceneTree
## Renders a scene for N frames and saves a PNG (needs a display, e.g. xvfb-run).
## Usage: godot --path game --script res://tests/screenshot.gd -- <scene> <out.png> [frames]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://scenes/main.tscn"
	var out := args[1] if args.size() > 1 else "/tmp/shot.png"
	var frames := int(args[2]) if args.size() > 2 else 60
	root.add_child((load(scene_path) as PackedScene).instantiate())
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("SAVED ", out)
	quit(0)
