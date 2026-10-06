extends SceneTree
## Screenshot of the deck screen. Needs xvfb-run.
## godot --path game --script res://tests/shot_deck.gd -- <out.png> [scroll_px]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	GameDB.ensure_loaded()
	var t := Theme.new()
	t.default_font_size = 24
	var holder := Control.new()
	holder.theme = t
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var d := DeckScreen.new()
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(d)
	for i in 10:
		await process_frame
	if args.size() > 1:
		var scroll := d.find_children("*", "ScrollContainer", true, false)
		if not scroll.is_empty():
			(scroll[0] as ScrollContainer).scroll_vertical = int(args[1])
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(args[0])
	quit(0)
