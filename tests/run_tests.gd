extends SceneTree
## Runs every test_ method in tests/unit. Use: godot --headless --path . -s tests/run_tests.gd

const FOLDER := "res://tests/unit/"


func _init() -> void:
	var ran := 0
	var failed := 0
	for file in DirAccess.get_files_at(FOLDER):
		if not file.begins_with("test_") or not file.ends_with(".gd"):
			continue
		var script: GDScript = load(FOLDER + file)
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var test: RefCounted = script.new()
			test.call(name)
			ran += 1
			for failure: String in test.failures:
				failed += 1
				print("FAIL %s %s: %s" % [file, name, failure])
	print("%d tests ran, %d checks failed" % [ran, failed])
	quit(1 if failed > 0 or ran == 0 else 0)
