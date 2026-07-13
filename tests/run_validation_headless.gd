extends SceneTree

func _initialize() -> void:
	call_deferred("_start_validation")

func _start_validation() -> void:
	var saves: Node = root.get_node("SaveManager")
	saves.load_profile_index()
	if not saves.profile_exists(0):
		saves.create_profile(0, "Validation")
	saves.select_profile(0)
	root.get_node("GameManager").initialize_active_profile()
	var validation_scene: Node = load("res://scenes/validation/ValidationScene.tscn").instantiate()
	root.add_child(validation_scene)
