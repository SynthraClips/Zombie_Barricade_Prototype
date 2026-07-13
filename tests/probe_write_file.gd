extends SceneTree

func _initialize() -> void:
	var path := "C:/Users/scott/Documents/Small Game/project/reports/probe_write_file.txt"
	DirAccess.make_dir_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("probe_ok")
		file.close()
	quit()
