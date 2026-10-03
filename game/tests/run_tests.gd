extends SceneTree
## Runs every test_* method in res://tests/unit/test_*.gd. Prints one summary line.
## godot --headless --path game --script res://tests/run_tests.gd


func _initialize() -> void:
	var passed := 0
	var failures: Array[String] = []
	var files := Array(DirAccess.get_files_at("res://tests/unit/"))
	files.sort()
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/unit/" + f)
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			var tc: TestCase = script.new()
			tc._current = "%s::%s" % [f, name]
			tc.call(name)
			if tc.failures.is_empty():
				passed += 1
			else:
				failures.append_array(tc.failures)
	for msg in failures:
		print("FAIL ", msg)
	print("TESTS: %d passed, %d failed" % [passed, failures.size()])
	quit(0 if failures.is_empty() else 1)
