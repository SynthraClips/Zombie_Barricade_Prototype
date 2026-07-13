extends SceneTree

func _initialize() -> void:
	var game_manager: Node = root.get_node("/root/GameManager")
	var save_manager: Node = root.get_node("/root/SaveManager")
	var mission_manager: Node = root.get_node("/root/MissionManager")
	var report: Array[String] = []

	var original_config: Dictionary = game_manager.game_config.duplicate(true)

	report.append("pressure_test")
	game_manager.current_run_context = {}
	var pressure_field: Node = _make_battlefield(game_manager, {
		"target_distance": 240,
		"base_scroll_speed": 100.0,
		"base_enemy_spawn_interval": 1.8,
		"obstacle_spawn_interval": 99.0,
		"horde_pressure": {
			"enabled": true,
			"start_value": 5.0,
			"max_pressure": 100.0,
			"gain_per_second": 0.0,
			"gain_per_distance": 0.0,
			"thresholds": {"medium": 20.0, "high": 45.0, "surge": 75.0},
			"warnings": {"medium": "The horde is gaining!", "high": "Pressure High!", "surge": "Horde Surge!"},
			"spawn_interval_multiplier_at_max": 0.5,
			"runner_weight_multiplier_at_max": 3.0,
			"mutation_interval_scale_at_max": 0.65,
			"reward_multiplier_at_max": 1.5,
			"high_value_event_chance_bonus_at_max": 0.2,
			"reduction_values": {"boss_defeated": 25.0, "barricade_deployed": 8.0, "survivor_rescue_completed": 10.0, "armoury_cache_destroyed": 12.0, "special_event_completed": 6.0}
		}
	})
	await process_frame
	pressure_field.set_horde_pressure(80.0, "debug")
	var before_coins: int = pressure_field.coins
	var added: int = pressure_field.add_coins(10)
	report.append("pressure coins_before=%s added=%s after=%s reward_mult=%s" % [before_coins, added, pressure_field.coins, pressure_field.get_pressure_reward_multiplier()])
	_dispose_battlefield(game_manager, pressure_field, original_config)
	await process_frame

	report.append("pickup_test")
	var pickup_field: Node = _make_battlefield(game_manager, {
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await process_frame
	pickup_field.reward_manager.spawn_reward("damage_boost", pickup_field.squad_manager.get_anchor_position())
	await physics_frame
	await process_frame
	report.append("pickup damage_bonus=%s rewards=%s children=%s" % [pickup_field.squad_manager.temporary_damage_bonus, pickup_field.reward_manager.rewards.size(), pickup_field.reward_manager.get_children().size()])
	_dispose_battlefield(game_manager, pickup_field, original_config)
	await process_frame

	report.append("double_collect_test")
	var double_field: Node = _make_battlefield(game_manager, {
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await process_frame
	double_field.reward_manager.spawn_reward("coins_small", Vector2(360.0, 220.0))
	var reward: Node = double_field.reward_manager.rewards[0]
	var coins_before: int = double_field.coins
	reward.collect()
	reward.collect()
	await process_frame
	report.append("double_collect before=%s after=%s expected=%s last=%s" % [coins_before, double_field.coins, int(game_manager.reward_data["rewards"]["coins_small"]["value"]), JSON.stringify(double_field.reward_manager.last_collected_reward)])
	_dispose_battlefield(game_manager, double_field, original_config)
	await process_frame

	report.append("overcap_test")
	var overcap_field: Node = _make_battlefield(game_manager, {
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0,
		"max_squad_size": 4,
		"allow_pickup_soldier_overcap": true,
		"pickup_soldier_overcap_limit": 6
	})
	await process_frame
	var add_one: int = overcap_field.squad_manager.add_soldiers(1)
	var add_two: int = overcap_field.squad_manager.add_soldiers(1)
	overcap_field.reward_manager.spawn_reward("add_soldier", overcap_field.squad_manager.get_anchor_position())
	await physics_frame
	await process_frame
	var removed: int = overcap_field.squad_manager.remove_soldiers(2)
	report.append("overcap add_one=%s add_two=%s count=%s removed=%s label=%s" % [add_one, add_two, overcap_field.squad_manager.get_soldier_count(), removed, overcap_field.ui_manager.squad_label.text])
	_dispose_battlefield(game_manager, overcap_field, original_config)
	await process_frame

	report.append("repeatable_test")
	var repeatable_id := ""
	for row in mission_manager.get_mission_rows():
		if String(row.get("category", "")) == "repeatable":
			repeatable_id = String(row.get("id", ""))
			break
	if repeatable_id != "":
		var mission_def: Dictionary = mission_manager.get_mission_definition(repeatable_id)
		mission_manager.set_progress_to_max(String(mission_def.get("target_type", "")), int(mission_def.get("target_value", 1)))
		var before_state: Dictionary = mission_manager.get_mission_rows().filter(func(row): return String(row.get("id", "")) == repeatable_id)[0]
		var claimed: bool = mission_manager.claim_mission(repeatable_id)
		var after_state: Dictionary = mission_manager.get_mission_rows().filter(func(row): return String(row.get("id", "")) == repeatable_id)[0]
		report.append("repeatable id=%s before=%s claimed=%s after=%s" % [repeatable_id, JSON.stringify(before_state), claimed, JSON.stringify(after_state)])
	else:
		report.append("repeatable id missing")

	var file := FileAccess.open("user://debug_failures.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(report))
		file.close()
	quit()

func _make_battlefield(game_manager: Node, config_overrides: Dictionary = {}) -> Node:
	var validation_rescue_config: Dictionary = game_manager.game_config.get("survivor_rescue", {}).duplicate(true)
	validation_rescue_config["enabled"] = false
	game_manager.game_config["survivor_rescue"] = validation_rescue_config
	var validation_pressure_config: Dictionary = game_manager.game_config.get("horde_pressure", {}).duplicate(true)
	validation_pressure_config["enabled"] = false
	game_manager.game_config["horde_pressure"] = validation_pressure_config
	for key in config_overrides.keys():
		if key == "survivor_rescue":
			var merged_rescue: Dictionary = validation_rescue_config.duplicate(true)
			for rescue_key in config_overrides[key].keys():
				merged_rescue[rescue_key] = config_overrides[key][rescue_key]
			game_manager.game_config[key] = merged_rescue
			continue
		if key == "horde_pressure":
			var merged_pressure: Dictionary = validation_pressure_config.duplicate(true)
			for pressure_key in config_overrides[key].keys():
				merged_pressure[pressure_key] = config_overrides[key][pressure_key]
			game_manager.game_config[key] = merged_pressure
			continue
		game_manager.game_config[key] = config_overrides[key]
	var field: Node = load("res://scenes/gameplay/Battlefield.tscn").instantiate()
	root.add_child(field)
	return field

func _dispose_battlefield(game_manager: Node, field: Node, original: Dictionary) -> void:
	game_manager.game_config = original.duplicate(true)
	field.queue_free()
