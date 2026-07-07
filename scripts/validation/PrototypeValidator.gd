extends SceneTree

func _initialize() -> void:
	var validation_scene: Node = load("res://scenes/validation/ValidationScene.tscn").instantiate()
	root.add_child(validation_scene)
