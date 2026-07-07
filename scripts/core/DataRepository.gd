extends RefCounted
class_name DataRepository

static func load_json(path: String, default_value):
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return default_value
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open data file: %s" % path)
		return default_value
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Invalid JSON in %s" % path)
		return default_value
	return parsed

