extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/validation/ValidationScene.tscn").instantiate()
	scene.set_meta("external_probe", true)
	root.add_child(scene)
	await scene.validation_completed
	var snapshot: Dictionary = scene.call("get_validation_snapshot")
	var path := _get_output_path()
	DirAccess.make_dir_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("passed=%s\nfailed=%s\n\n" % [str(snapshot.get("passed", "<missing>")), str(snapshot.get("failed", "<missing>"))])
		file.store_string("\n".join(snapshot.get("report_lines", [])))
		file.close()
	quit()

func _get_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-output="):
			return argument.trim_prefix("--probe-output=")
	return "C:/Users/scott/Documents/Small Game/project/reports/probe_validation_state.txt"
