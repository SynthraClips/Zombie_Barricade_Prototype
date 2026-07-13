extends SceneTree

func _initialize() -> void:
	call_deferred("_start_test")

func _start_test() -> void:
	var scene: PackedScene = load("res://tests/SafehouseUpgradeTreeTests.tscn")
	if scene == null:
		push_error("Could not load Safehouse upgrade tree tests")
		quit(1)
		return
	root.add_child(scene.instantiate())
