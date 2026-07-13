extends Node

const OUTPUT_DIR := "res://reports/safehouse_tree_screenshots"

func _ready() -> void:
	call_deferred("_capture_all")

func _capture_all() -> void:
	var original: Dictionary = SaveManager.save_data.duplicate(true)
	SaveManager.save_data = SaveManager._default_save_data()
	SaveManager.save_data["banked_coins"] = 1000
	for upgrade_id in UpgradeManager.upgrade_defs:
		SaveManager.save_data["upgrades"][upgrade_id] = 0
	SaveManager.save_game()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: PackedScene = load("res://scenes/ui/UpgradeScreen.tscn")
	var screen: Control = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	if screen.tree_view != null:
		screen.tree_view.camera.set_camera_zoom(0.4)
		screen.tree_view.main_container.offset_transform_position = Vector2.ZERO
		# Evidence overview: fit the root and all five nodes in every branch into
		# the portrait tree viewport. Runtime controls remain clamped to 0.4.
		screen.tree_view.main_container.offset_transform_scale = Vector2(0.22, 0.22)
	await _capture("01_complete_tree.png")
	if screen.tree_view != null:
		screen.tree_view.main_container.offset_transform_scale = Vector2(0.4, 0.4)

	screen._select_upgrade("arsenal_critical_chance_01")
	await _capture("02_locked_node.png")

	screen._select_upgrade("arsenal_fire_rate_01")
	await _capture("03_available_node.png")

	SaveManager.save_data["permanent_upgrade_ids"] = ["arsenal_fire_rate_01"]
	SaveManager.save_data["upgrades"]["fire_rate"] = 1
	screen._refresh_all()
	await get_tree().process_frame
	await get_tree().process_frame
	_reset_detail_view(screen)
	await get_tree().process_frame
	await _capture("04_purchased_node.png")

	SaveManager.save_data["permanent_upgrade_ids"] = []
	SaveManager.save_data["upgrades"]["fire_rate"] = 0
	screen._refresh_all()
	screen._select_upgrade("arsenal_fire_rate_01")
	screen._request_purchase()
	await get_tree().process_frame
	await _capture("05_purchase_confirmation.png")

	SaveManager.save_data = original
	SaveManager.save_game()
	print("SAFEHOUSE_SCREENSHOTS_COMPLETE=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	get_tree().quit(0)

func _capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, filename])
	if error != OK:
		push_error("Could not save Safehouse screenshot %s: %s" % [filename, error_string(error)])

func _reset_detail_view(screen: Control) -> void:
	if screen.tree_view == null:
		return
	screen.tree_view.camera.set_camera_zoom(0.4)
	screen.tree_view.main_container.offset_transform_position = Vector2.ZERO
	screen.tree_view.main_container.offset_transform_scale = Vector2(0.4, 0.4)
