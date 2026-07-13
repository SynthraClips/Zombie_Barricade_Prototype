extends SceneTree

const OUTPUT_PATH := "res://reports/expansion_runtime_overview.png"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1080, 1280)
	root.content_scale_size = Vector2i(1080, 1280)
	for resize_frame in 3:
		await process_frame
	var saves: Node = root.get_node("SaveManager")
	var game: Node = root.get_node("GameManager")
	saves.load_profile_index()
	if not saves.profile_exists(0):
		saves.create_profile(0, "Runtime Capture")
	saves.select_profile(0)
	saves.save_data["heroes"]["unlocked"] = ["captain_rhodes", "rook"]
	saves.save_data["selected_hero"] = "rook"
	saves.save_data["weapon_inventory"] = ["rifle", "tesla_cannon"]
	game.initialize_active_profile()
	game.current_run_context = {"mode": "standard", "hero_id": "rook", "run_seed": 29071}
	var field: Node = load("res://scenes/gameplay/Battlefield.tscn").instantiate()
	root.add_child(field)
	await process_frame
	field.scroll_speed = 0.0
	field.distance_travelled = 620.0
	field.road.request_night_section()
	field.road.night_blend = 1.0
	var building_ids: Array = game.environment_data.get("buildings", {}).get("definitions", {}).keys()
	for index in mini(6, building_ids.size()):
		field.road.buildings.append({"id": String(building_ids[index]), "side": -1 if index % 2 == 0 else 1, "y": 90.0 + float(index / 2) * 310.0, "scale": 0.86})
	var enemy_ids: Array[String] = ["mutated_dog", "mutated_boar", "rat_swarm", "carrion_bird", "mutated_bear", "night_stalker"]
	for index in enemy_ids.size():
		field.enemy_manager.spawn_enemy(enemy_ids[index], Vector2(340.0 + float(index % 3) * 200.0, 170.0 + float(index / 3) * 245.0), 1.0)
	field.reward_manager.spawn_reward("weapon::shotgun", Vector2(390.0, 790.0))
	field.reward_manager.spawn_reward("ammo_cache", Vector2(690.0, 790.0))
	var gates: Array[Node2D] = field.gate_manager.spawn_gate_row([{"type": "weapon_pickup", "weapon_id": "grenade_launcher"}, {"type": "supplies", "value": 8}, {"type": "night_section", "value": 1}])
	for index in gates.size():
		gates[index].global_position.y = 500.0
	field.call_selected_hero()
	for frame_index in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Could not save expansion runtime capture: %s" % error_string(error))
		quit(1)
		return
	print("EXPANSION_RUNTIME_CAPTURE=%s" % ProjectSettings.globalize_path(OUTPUT_PATH))
	root.get_node("AudioManager").clear_sfx()
	field.free()
	game.current_run_context = {}
	quit(0)
