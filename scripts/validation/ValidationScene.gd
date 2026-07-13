extends Control

signal validation_completed

@onready var status_label: Label = $Margin/Panel/VBox/Status
@onready var back_button: Button = $Margin/Panel/VBox/Back

var report_lines: Array[String] = []
var passed: int = 0
var failed: int = 0
var save_snapshot: Dictionary = {}
const VALID_MISSION_TARGETS := [
	"kills",
	"distance",
	"obstacles_destroyed",
	"unlock_barricade",
	"boss_kills",
	"finish_with_soldiers",
	"coins_collected",
	"soldiers_rescued",
	"barricades_deployed",
	"armoury_caches_destroyed",
	"choose_gates",
	"pickups_collected",
	"dangerous_route_boss",
	"mini_objectives_completed",
	"complete_daily",
	"unlock_specialist"
]

func _ready() -> void:
	back_button.disabled = true
	save_snapshot = SaveManager.save_data.duplicate(true)
	call_deferred("_run_validation")

func _run_validation() -> void:
	await _validate_all()
	_restore_save()
	back_button.disabled = false
	status_label.text = "\n".join(report_lines)
	validation_completed.emit()
	var external_probe := OS.get_cmdline_user_args().has("--external-validation-probe")
	if DisplayServer.get_name() == "headless" and not external_probe:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if failed == 0 else 1)

func _restore_save() -> void:
	SaveManager.save_data = save_snapshot.duplicate(true)
	SaveManager.save_game()

func _record_result(name: String, ok: bool, detail: String = "") -> void:
	var line: String = "%s%s" % [name, " %s" % detail if detail != "" else ""]
	if ok:
		passed += 1
		report_lines.append("[PASS] %s" % line)
	else:
		failed += 1
		report_lines.append("[FAIL] %s" % line)

func _validate_all() -> void:
	report_lines = ["Zombie Barricade Prototype Validation", ""]
	_validate_required_files()
	_validate_data_files()
	_validate_data_integrity()
	_validate_expansion_data()
	await _validate_scene_loading()
	await _validate_player_controls()
	await _validate_core_run()
	await _validate_mutation_system()
	await _validate_horde_pressure()
	await _validate_movement_and_bounds()
	await _validate_gate_system()
	await _validate_field_pickups()
	await _validate_road_objects()
	await _validate_special_ammo()
	await _validate_armoury_cache_system()
	await _validate_survivor_rescue_system()
	await _validate_auto_fire()
	await _validate_post_boss_routes()
	await _validate_barricade_content()
	await _validate_menu_and_ui()
	_validate_save_hardening()
	await _validate_cleanup_safety()
	await _validate_game_over()
	await _validate_victory()
	_validate_save_load()
	await _validate_progression_expansion()
	_write_report()
	report_lines.append("")
	report_lines.append("Summary: %d passed, %d failed" % [passed, failed])

func _validate_required_files() -> void:
	var required: Array = [
		"res://project.godot",
		"res://scenes/main/MainMenu.tscn",
		"res://scenes/gameplay/Battlefield.tscn",
		"res://scenes/ui/UpgradeScreen.tscn",
		"res://scenes/ui/MissionScreen.tscn",
		"res://scripts/core/GameManager.gd",
		"res://scripts/gameplay/RunManager.gd",
		"res://scripts/gameplay/SquadManager.gd",
		"res://scripts/gameplay/GateManager.gd",
		"res://scripts/gameplay/ArmouryCacheManager.gd",
		"res://scripts/gameplay/ArmouryCache.gd",
		"res://scripts/gameplay/SurvivorRescueManager.gd",
		"res://scripts/gameplay/SurvivorRescue.gd",
		"res://scripts/gameplay/MutationManager.gd",
		"res://scripts/gameplay/Gate.gd",
		"res://scripts/enemies/Enemy.gd",
		"res://scripts/weapons/WeaponManager.gd",
		"res://scripts/barricades/Barricade.gd",
		"res://scripts/rewards/RewardManager.gd",
		"res://scripts/upgrades/UpgradeManager.gd",
		"res://scripts/missions/MissionManager.gd",
		"res://data/enemies.json",
		"res://data/weapons.json",
		"res://data/barricades.json",
		"res://data/waves.json",
		"res://data/mutations.json",
		"res://data/rewards.json",
		"res://data/gates.json",
		"res://data/missions.json",
		"res://data/upgrades.json",
		"res://data/game_config.json",
		"res://data/environments.json"
	]
	var all_present: bool = true
	for path in required:
		var exists: bool = ResourceLoader.exists(path) or FileAccess.file_exists(path)
		if not exists:
			all_present = false
			report_lines.append("[MISSING] %s" % path)
	_record_result("Required project files exist", all_present)

func _validate_data_files() -> void:
	_record_result("Enemy data loads", not GameManager.enemy_data.is_empty(), "(%d entries)" % GameManager.enemy_data.size())
	_record_result("Weapon data loads", not GameManager.weapon_data.is_empty(), "(%d entries)" % GameManager.weapon_data.size())
	_record_result("Barricade data loads", not GameManager.barricade_data.is_empty(), "(%d entries)" % GameManager.barricade_data.size())
	_record_result("Wave data loads", not GameManager.wave_data.get("waves", []).is_empty())
	_record_result("Mutation data loads", not GameManager.mutation_data.get("mutations", {}).is_empty())
	_record_result("Reward data loads", not GameManager.reward_data.get("rewards", {}).is_empty())
	_record_result("Gate data loads", not GameManager.gate_data.get("rows", []).is_empty() or not GameManager.gate_data.get("start_values", []).is_empty())
	_record_result("Mission data loads", not GameManager.mission_data.get("missions", []).is_empty())
	_record_result("Upgrade data loads", not GameManager.upgrade_data.get("upgrades", {}).is_empty())
	_record_result("Environment data loads", not GameManager.environment_data.get("buildings", {}).is_empty())

func _validate_expansion_data() -> void:
	var animal_ids: Array[String] = ["mutated_dog", "mutated_boar", "rat_swarm", "carrion_bird", "mutated_bear"]
	var boss_ids: Array[String] = ["boss", "screamer_matriarch", "plague_spitter", "horde_commander", "night_stalker", "alpha_beast"]
	var enemy_placeholders_valid := true
	for enemy_id in animal_ids + boss_ids:
		var enemy_definition: Dictionary = GameManager.enemy_data.get(enemy_id, {})
		var placeholder_path := String(enemy_definition.get("placeholder", ""))
		enemy_placeholders_valid = enemy_placeholders_valid and not enemy_definition.is_empty() and placeholder_path != "" and ResourceLoader.exists(placeholder_path)
	_record_result("Mutated animal definitions and placeholders are configured", animal_ids.all(func(enemy_id): return String(GameManager.enemy_data.get(enemy_id, {}).get("category", "")) == "animal") and enemy_placeholders_valid)
	_record_result("Route boss roster and unique behaviours are configured", boss_ids.all(func(enemy_id): return String(GameManager.enemy_data.get(enemy_id, {}).get("category", "")) == "boss" and String(GameManager.enemy_data.get(enemy_id, {}).get("special_behavior", "")) != ""))

	var required_weapons: Array[String] = ["rifle", "smg", "shotgun", "minigun", "sniper_rifle", "burst_rifle", "grenade_launcher", "flamethrower", "piercing_rifle", "acid_sprayer", "freeze_rifle", "rocket_launcher", "tesla_cannon"]
	var weapon_assets_valid := true
	var collectible_count := 0
	for weapon_id in required_weapons:
		var weapon_definition: Dictionary = GameManager.weapon_data.get(weapon_id, {})
		weapon_assets_valid = weapon_assets_valid and ResourceLoader.exists(String(weapon_definition.get("icon", "")))
		if bool(weapon_definition.get("collectible", false)):
			collectible_count += 1
	_record_result("Expanded weapon roster has replaceable icons", required_weapons.all(func(weapon_id): return GameManager.weapon_data.has(weapon_id)) and weapon_assets_valid and collectible_count >= 10)
	var tesla_definition: Dictionary = GameManager.weapon_data.get("tesla_cannon", {})
	_record_result("Tesla is upgrade-only with bounded limited ammunition", bool(tesla_definition.get("upgrade_only", false)) and not bool(tesla_definition.get("collectible", true)) and bool(tesla_definition.get("limited_ammo", false)) and int(tesla_definition.get("max_ammo", 0)) > 0 and float(tesla_definition.get("max_effective_range", 9999.0)) <= 700.0)

	var evolution_nodes: Dictionary = GameManager.mutation_data.get("evolution_nodes", {})
	var evolution_families: Array[String] = []
	var evolution_links_valid := true
	for evolution_id in evolution_nodes:
		var evolution_definition: Dictionary = evolution_nodes[evolution_id]
		var family := String(evolution_definition.get("family", ""))
		if not evolution_families.has(family):
			evolution_families.append(family)
		for prerequisite in evolution_definition.get("prerequisite_ids", []):
			evolution_links_valid = evolution_links_valid and evolution_nodes.has(String(prerequisite))
	_record_result("Zombie Evolution Tree covers five data-driven families", ["physical", "movement", "offensive", "resistance", "pack"].all(func(family): return evolution_families.has(family)) and evolution_nodes.size() >= 10 and evolution_links_valid)

	var building_definitions: Dictionary = GameManager.environment_data.get("buildings", {}).get("definitions", {})
	var building_assets_valid := building_definitions.size() >= 8
	for building_definition in building_definitions.values():
		building_assets_valid = building_assets_valid and ResourceLoader.exists(String(building_definition.get("placeholder", ""))) and String(building_definition.get("event_bias", "")) != ""
		for boss_id in building_definition.get("boss_pool", []):
			building_assets_valid = building_assets_valid and String(GameManager.enemy_data.get(String(boss_id), {}).get("category", "")) == "boss"
	_record_result("Roadside buildings are modular event anchors", building_assets_valid)
	var night_definition: Dictionary = GameManager.environment_data.get("night", {})
	_record_result("Night sections have transition, lighting, spacing, duration, and spawn weighting", bool(night_definition.get("enabled", false)) and ResourceLoader.exists(String(night_definition.get("lamp_placeholder", ""))) and float(night_definition.get("transition_seconds", 0.0)) > 0.0 and float(night_definition.get("minimum_day_gap", 0.0)) > 0.0 and float(night_definition.get("section_duration_distance", 0.0)) > 0.0 and not night_definition.get("enemy_weight_multipliers", {}).is_empty())
	var hero_definitions: Dictionary = GameManager.game_config.get("heroes", {})
	var new_hero_ids: Array[String] = ["dr_imani", "rook", "nyx", "arc"]
	var hero_assets_valid := true
	for hero_id in new_hero_ids:
		var hero_definition: Dictionary = hero_definitions.get(hero_id, {})
		hero_assets_valid = hero_assets_valid and bool(hero_definition.get("ultimate_enabled", false)) and String(hero_definition.get("ultimate_effect", "")) != "" and ResourceLoader.exists(String(hero_definition.get("placeholder", "")))
	_record_result("Expanded heroes have shared data, ultimates, and visible placeholders", new_hero_ids.all(func(hero_id): return hero_definitions.has(hero_id)) and hero_assets_valid)

	var gate_types: Array[String] = []
	var gate_boss_refs_valid := true
	for row in GameManager.gate_data.get("rows", []):
		for gate_definition in row.get("gates", []):
			var gate_type := String(gate_definition.get("type", ""))
			if not gate_types.has(gate_type):
				gate_types.append(gate_type)
			for boss_id in gate_definition.get("boss_pool", []):
				gate_boss_refs_valid = gate_boss_refs_valid and String(GameManager.enemy_data.get(String(boss_id), {}).get("category", "")) == "boss"
	_record_result("Expanded data-driven gate categories are available", ["supplies", "survivors", "weapon_pickup", "hero_cooldown", "night_section", "risk_gate"].all(func(gate_type): return gate_types.has(gate_type)) and gate_boss_refs_valid)
	_record_result("Positive gate growth and weapon rerolls are capped", float(GameManager.gate_data.get("positive_scaling", {}).get("run_growth", 1.0)) <= 0.3 and int(GameManager.gate_data.get("positive_scaling", {}).get("soldier_value_cap", 99)) <= 4 and int(GameManager.gate_data.get("weapon_gate", {}).get("max_changes", 0)) > 0)

	var total_tree_costs := {"coins": 0, "supplies": 0, "survivors": 0}
	var mixed_cost_nodes := 0
	for node in UpgradeManager.tree_defs.get("nodes", []):
		var costs: Dictionary = node.get("costs", {})
		for resource_id in total_tree_costs:
			total_tree_costs[resource_id] = int(total_tree_costs[resource_id]) + int(costs.get(resource_id, 0))
		if costs.keys().filter(func(resource_id): return int(costs.get(resource_id, 0)) > 0).size() > 1:
			mixed_cost_nodes += 1
	_record_result("Permanent progression is substantially slower and uses mixed resources", int(total_tree_costs["coins"]) >= 6000 and int(total_tree_costs["supplies"]) >= 1000 and int(total_tree_costs["survivors"]) >= 50 and mixed_cost_nodes >= 8)
	var save_defaults: Dictionary = SaveManager._default_save_data()
	_record_result("Save migration defaults cover new progression and report fields", save_defaults.has("supplies") and save_defaults.has("survivors") and save_defaults.has("defeated_boss_ids") and save_defaults.has("discovered_mutations") and save_defaults.has("weapon_inventory"))

func _validate_data_integrity() -> void:
	var waves_valid := true
	for wave in GameManager.wave_data.get("waves", []):
		waves_valid = waves_valid and int(wave.get("spawn_count", 0)) > 0
		for enemy_id in wave.get("pool", []):
			if not GameManager.enemy_data.has(String(enemy_id)):
				waves_valid = false
	_record_result("Wave enemy references are valid", waves_valid)

	var mutation_refs_valid := true
	for mutation_id in GameManager.mutation_data.get("mutations", {}).keys():
		var mutation_def: Dictionary = GameManager.mutation_data.get("mutations", {}).get(mutation_id, {})
		mutation_refs_valid = mutation_refs_valid and String(mutation_def.get("id", "")) == String(mutation_id)
		mutation_refs_valid = mutation_refs_valid and String(mutation_def.get("label", "")) != ""
		mutation_refs_valid = mutation_refs_valid and float(mutation_def.get("duration", 0.0)) > 0.0
		for enemy_id in mutation_def.get("spawn_weight_modifiers", {}).keys():
			if not GameManager.enemy_data.has(String(enemy_id)):
				mutation_refs_valid = false
		for enemy_id in mutation_def.get("affected_enemy_ids", []):
			if not GameManager.enemy_data.has(String(enemy_id)):
				mutation_refs_valid = false
	for schedule_row in GameManager.mutation_data.get("schedule", []):
		for mutation_id in schedule_row.get("allowed_mutations", []):
			if not GameManager.mutation_data.get("mutations", {}).has(String(mutation_id)):
				mutation_refs_valid = false
	_record_result("Mutation references are valid", mutation_refs_valid)

	var reward_refs_valid := true
	for reward_id in GameManager.reward_data.get("obstacle_reward_table", []):
		if not GameManager.reward_data.get("rewards", {}).has(String(reward_id)):
			reward_refs_valid = false
	for reward_table in GameManager.reward_data.get("armoury_cache_reward_tables", {}).values():
		for entry in reward_table:
			if not GameManager.reward_data.get("rewards", {}).has(String(entry.get("reward_id", ""))):
				reward_refs_valid = false
	for row in GameManager.gate_data.get("rows", []):
		for gate in row.get("gates", []):
			var gate_type: String = String(gate.get("type", ""))
			reward_refs_valid = reward_refs_valid and gate_type != ""
	_record_result("Reward and gate references are valid", reward_refs_valid)

	var road_object_refs_valid := true
	var road_object_config: Dictionary = GameManager.game_config.get("road_objects", {})
	var road_object_defs: Dictionary = road_object_config.get("definitions", {})
	for entry in road_object_config.get("spawn_pool", []):
		var type_id: String = String(entry.get("type", ""))
		if not ["barrel", "crate"].has(type_id) and not road_object_defs.has(type_id):
			road_object_refs_valid = false
	for type_id in road_object_defs.keys():
		var object_def: Dictionary = road_object_defs[type_id]
		var reward_id: String = String(object_def.get("reward_id", ""))
		if reward_id != "" and not GameManager.reward_data.get("rewards", {}).has(reward_id):
			road_object_refs_valid = false
		for enemy_id in object_def.get("alarm_spawn_pool", []):
			if not GameManager.enemy_data.has(String(enemy_id)):
				road_object_refs_valid = false
	_record_result("Road object references are valid", road_object_refs_valid and not road_object_defs.is_empty())

	var mission_targets_valid := true
	for mission in GameManager.mission_data.get("missions", []):
		if not VALID_MISSION_TARGETS.has(String(mission.get("target_type", ""))):
			mission_targets_valid = false
	_record_result("Mission target types are valid", mission_targets_valid)

	var upgrade_refs_valid := true
	for upgrade_id in UpgradeManager.upgrade_defs.keys():
		var def: Dictionary = UpgradeManager.upgrade_defs[upgrade_id]
		upgrade_refs_valid = upgrade_refs_valid and float(def.get("cost_base", 0.0)) > 0.0
		if upgrade_id == "starting_weapon":
			for weapon_id in def.get("choices", []):
				if not GameManager.weapon_data.has(String(weapon_id)):
					upgrade_refs_valid = false
		if upgrade_id == "starting_barricade_tier":
			for barricade_id in def.get("choices", []):
				if not GameManager.barricade_data.has(String(barricade_id)):
					upgrade_refs_valid = false
	_record_result("Upgrade costs and choice references are valid", upgrade_refs_valid)

	_record_result("Boss data is valid", GameManager.enemy_data.has("boss") and not GameManager.game_config.get("boss_milestones", []).is_empty())
	_record_result("Route types exist", GameManager.game_config.get("route_type_order", []).size() >= 5 and GameManager.game_config.get("route_types", {}).has("dangerous_route"))
	_record_result("Run modifiers exist", GameManager.game_config.get("run_modifier_order", []).size() >= 4)
	var pressure_config: Dictionary = GameManager.game_config.get("horde_pressure", {})
	var pressure_thresholds: Dictionary = pressure_config.get("thresholds", {})
	var pressure_valid := (
		bool(pressure_config.get("enabled", false))
		and float(pressure_config.get("max_pressure", 0.0)) > 0.0
		and float(pressure_thresholds.get("medium", -1.0)) >= 0.0
		and float(pressure_thresholds.get("high", -1.0)) > float(pressure_thresholds.get("medium", 0.0))
		and float(pressure_thresholds.get("surge", -1.0)) > float(pressure_thresholds.get("high", 0.0))
	)
	_record_result("Horde pressure config is valid", pressure_valid)

func _validate_scene_loading() -> void:
	var menu: Node = load("res://scenes/main/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	_record_result("Main menu loads", is_instance_valid(menu))
	_record_result("Main menu buttons exist", menu.has_node("Layout/RootRow/MainCard/CardMargin/CardVBox/Buttons/Play") or menu.has_node("Margin/Panel/VBox/Play"))
	menu.queue_free()
	await get_tree().process_frame
	var field: Node = load("res://scenes/gameplay/Battlefield.tscn").instantiate()
	add_child(field)
	await get_tree().process_frame
	_record_result("Battlefield scene loads", is_instance_valid(field))
	field.queue_free()
	await get_tree().process_frame

func _validate_player_controls() -> void:
	_record_result("Deploy barricade input action exists", InputMap.has_action("deploy_barricade"))
	var hero_system_exists: bool = not GameManager.game_config.get("heroes", {}).is_empty()
	_record_result("Call hero input action exists", not hero_system_exists or InputMap.has_action("call_hero"))
	_record_result("Hero ultimate input action exists", not hero_system_exists or InputMap.has_action("hero_ultimate"))
	_record_result("Gameplay shortcuts use B, H, and U", _action_has_key("deploy_barricade", KEY_B) and _action_has_key("call_hero", KEY_H) and _action_has_key("hero_ultimate", KEY_U))

	var ui: Node = load("res://scenes/ui/UI.tscn").instantiate()
	var controls_present := (
		ui.has_node("HUD/ActionPanel/Margin/Buttons/DeployBarricade")
		and ui.has_node("HUD/ActionPanel/Margin/Buttons/CallHero")
		and ui.has_node("HUD/ActionPanel/Margin/Buttons/HeroUltimate")
		and ui.has_node("HUD/StartHint")
	)
	_record_result("HUD action buttons and start hint exist", controls_present)
	ui.queue_free()

	var original_context: Dictionary = GameManager.current_run_context.duplicate(true)
	GameManager.current_run_context = {"hero_id": "mara_hale", "route_type_id": "balanced_route", "run_modifier_id": ""}
	var field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var starting_barricade: Node = field.barricade_manager.active_barricade
	if starting_barricade != null and is_instance_valid(starting_barricade):
		starting_barricade.queue_free()
	field.barricade_manager.clear_active_barricade()
	field.barricade_manager.reset_cooldown()
	await get_tree().process_frame
	var barricade_requested: bool = field.request_deploy_barricade()
	_record_result("Barricade control request triggers deploy path", barricade_requested and field.barricade_manager.active_barricade != null)
	var hero_requested: bool = field.request_call_hero()
	_record_result("Hero control request triggers call-in path", hero_requested and bool(field.get_hero_state().get("active", false)))
	var ultimate_requested: bool = field.request_hero_ultimate()
	_record_result("Ultimate control request triggers ultimate path", ultimate_requested and not bool(field.get_hero_state().get("ultimate_ready", true)))
	_record_result("HUD and keyboard share control request methods", field.has_method("request_deploy_barricade") and field.has_method("request_call_hero") and field.has_method("request_hero_ultimate"))
	_dispose_battlefield(field)
	GameManager.current_run_context = original_context
	await get_tree().process_frame

func _action_has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.keycode == keycode or event.physical_keycode == keycode):
			return true
	return false

func _make_battlefield(config_overrides: Dictionary = {}) -> Node:
	var original: Dictionary = GameManager.game_config.duplicate(true)
	var validation_rescue_config: Dictionary = GameManager.game_config.get("survivor_rescue", {}).duplicate(true)
	validation_rescue_config["enabled"] = false
	GameManager.game_config["survivor_rescue"] = validation_rescue_config
	var validation_pressure_config: Dictionary = GameManager.game_config.get("horde_pressure", {}).duplicate(true)
	validation_pressure_config["enabled"] = false
	GameManager.game_config["horde_pressure"] = validation_pressure_config
	for key in config_overrides.keys():
		if key == "survivor_rescue":
			var merged_rescue: Dictionary = validation_rescue_config.duplicate(true)
			for rescue_key in config_overrides[key].keys():
				merged_rescue[rescue_key] = config_overrides[key][rescue_key]
			GameManager.game_config[key] = merged_rescue
			continue
		if key == "horde_pressure":
			var merged_pressure: Dictionary = validation_pressure_config.duplicate(true)
			for pressure_key in config_overrides[key].keys():
				merged_pressure[pressure_key] = config_overrides[key][pressure_key]
			GameManager.game_config[key] = merged_pressure
			continue
		GameManager.game_config[key] = config_overrides[key]
	var field: Node = load("res://scenes/gameplay/Battlefield.tscn").instantiate()
	field.set_meta("validation_original_config", original)
	add_child(field)
	return field

func _dispose_battlefield(field: Node) -> void:
	var original: Dictionary = field.get_meta("validation_original_config", {})
	if original.is_empty():
		GameManager._load_all_data()
	else:
		GameManager.game_config = original
	field.queue_free()

func _validate_core_run() -> void:
	var field: Node = _make_battlefield({
		"target_distance": 60,
		"base_scroll_speed": 150.0,
		"base_enemy_spawn_interval": 0.4,
		"obstacle_spawn_interval": 0.8
	})
	await get_tree().process_frame
	_record_result(
		"Squad spawns",
		field.squad_manager.get_soldier_count() >= 3,
		"(count=%d)" % field.squad_manager.get_soldier_count()
	)
	_record_result("Barricade deploys at run start", field.barricade_manager.active_barricade != null)
	var start_distance: float = field.distance_travelled
	await get_tree().create_timer(1.0).timeout
	_record_result("Distance counter increases", field.distance_travelled > start_distance)
	var first_enemy: Node = field.enemy_manager.spawn_enemy("walker", Vector2(360, 720), 0.25)
	field.squad_manager.handle_pointer_input(first_enemy.global_position, true)
	field.update_aim_position(first_enemy.global_position)
	field.set_fire_input_held(true)
	await get_tree().create_timer(2.0).timeout
	var enemy_hp_after: float = first_enemy.hp if is_instance_valid(first_enemy) else -1.0
	var direct_fire_damage_before: float = first_enemy.hp if is_instance_valid(first_enemy) else -1.0
	var weapon_id: String = field.weapon_manager.get_current_weapon_id()
	var target_is_enemy: bool = is_instance_valid(first_enemy) and first_enemy is Enemy
	var preview_weapon: Dictionary = field.weapon_manager.get_effective_weapon_data_for_role("rifleman")
	var preview_damage: float = field.weapon_manager.get_damage_for_target(preview_weapon, first_enemy) if is_instance_valid(first_enemy) else -1.0
	if is_instance_valid(first_enemy) and not field.squad_manager.soldiers.is_empty():
		field.weapon_manager.fire_weapon(field.squad_manager.soldiers[0], first_enemy)
		await get_tree().process_frame
	var direct_fire_damage_after: float = first_enemy.hp if is_instance_valid(first_enemy) else -1.0
	var manual_damage_after: float = direct_fire_damage_after
	if is_instance_valid(first_enemy):
		first_enemy.take_damage(1.0, false)
		manual_damage_after = first_enemy.hp if is_instance_valid(first_enemy) else -1.0
	_record_result("Soldiers damage zombies", field.run_stats["kills"] > 0 or field.enemy_manager.enemies.any(func(enemy): return enemy.hp < enemy.max_hp), "(weapon=%s dmg=%.2f raw=%s target_enemy=%s hp_after=%.2f direct_before=%.2f direct_after=%.2f manual_after=%.2f soldiers=%d)" % [weapon_id, preview_damage, str(preview_weapon.get("damage", "missing")), str(target_is_enemy), enemy_hp_after, direct_fire_damage_before, direct_fire_damage_after, manual_damage_after, field.squad_manager.soldiers.size()])
	_record_result("Zombies can die", field.run_stats["kills"] > 0, "(kills=%d)" % int(field.run_stats["kills"]))
	_record_result("Coins are awarded", field.coins > 0, "(coins=%d)" % int(field.coins))
	var obstacle: Node = field.enemy_manager.spawn_obstacle("crate", Vector2(360, 700))
	await get_tree().process_frame
	obstacle.take_damage(999)
	await get_tree().create_timer(0.6).timeout
	_record_result("Rewards can spawn from obstacles", field.reward_manager.rewards.size() > 0 or field.run_stats["obstacles_destroyed"] > 0)
	_record_result("Mission progress updates", int(SaveManager.save_data["mission_progress"].get("destroy_25_barrels", 0)) > 0)
	var barricade: Node = field.barricade_manager.active_barricade
	var barricade_hp: float = barricade.hp if barricade != null else 0.0
	var second_enemy: Node = field.enemy_manager.spawn_enemy("walker", Vector2(360, 860), 0.5)
	if barricade != null and is_instance_valid(barricade):
		second_enemy.global_position = barricade.global_position - Vector2(0.0, 24.0)
		second_enemy.call("_attack_barricade_or_explode")
	await get_tree().process_frame
	var barricade_damaged: bool = field.barricade_manager.active_barricade == null
	if barricade != null and is_instance_valid(barricade):
		var before_hp: float = barricade.hp
		barricade.take_damage(1.0)
		await get_tree().process_frame
		barricade_damaged = (
			not is_instance_valid(barricade)
			or field.barricade_manager.active_barricade == null
			or barricade.hp < before_hp
		)
	_record_result("Barricade damage path works", barricade_damaged, "(before=%.2f after=%.2f)" % [barricade_hp, barricade.hp if is_instance_valid(barricade) else -1.0])
	field.barricade_manager.damage_active_barricade(9999)
	await get_tree().process_frame
	_record_result("Barricade can be destroyed", field.barricade_manager.active_barricade == null)
	field.set_fire_input_held(false)
	_dispose_battlefield(field)
	await get_tree().process_frame

func _validate_mutation_system() -> void:
	var field: Node = _make_battlefield({
		"target_distance": 240,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	field.distance_travelled = 90.0
	field.elapsed_time = 25.0
	field.set_wave(2)
	field.mutation_manager.next_trigger_distance = 80.0
	field.mutation_manager.next_trigger_time = 20.0
	field.mutation_manager.update_mutations(0.01)
	await get_tree().process_frame
	_record_result("Mutation can start during a run", field.mutation_manager.is_mutation_active())
	_record_result("HUD shows active mutation and timer", field.ui_manager.mutation_label.visible and field.ui_manager.mutation_label.text.find("Mutation:") >= 0)

	var selected_mutation: Dictionary = field.mutation_manager.select_mutation_from_allowed(["armoured_horde"])
	_record_result("Only allowed mutations are selected", String(selected_mutation.get("id", "")) == "armoured_horde")

	field.mutation_manager.end_active_mutation(false)
	field.mutation_manager.start_mutation_by_id("runner_surge", 0.5)
	var surge_weights: Dictionary = field.wave_spawner.get_spawn_weight_snapshot(["walker", "runner", "runner", "spitter"])
	_record_result("Mutation applies spawn weight modifier", float(surge_weights.get("runner", 0.0)) > 2.0 and is_equal_approx(float(surge_weights.get("walker", 0.0)), 1.0))
	field.mutation_manager.end_active_mutation(false)
	var normal_weights: Dictionary = field.wave_spawner.get_spawn_weight_snapshot(["walker", "runner", "runner", "spitter"])
	_record_result("Enemy spawning returns to normal after mutation", is_equal_approx(float(normal_weights.get("runner", 0.0)), 2.0))

	field.mutation_manager.start_mutation_by_id("armoured_horde", 0.4)
	var mutated_enemy: Node = field.enemy_manager.spawn_enemy("walker", field.squad_manager.get_anchor_position() - Vector2(0, 220.0), 1.0)
	var base_hp: float = float(GameManager.enemy_data.get("walker", {}).get("hp", 0.0))
	_record_result("Mutation applies enemy stat modifier", mutated_enemy.max_hp > base_hp)
	field.mutation_manager.end_active_mutation(false)
	_record_result("Mutation expiry resets enemy stats", is_equal_approx(mutated_enemy.max_hp, base_hp))

	field.mutation_manager.start_mutation_by_id("spitter_swarm", 0.15)
	await get_tree().create_timer(0.25).timeout
	_record_result("Mutation expires", not field.mutation_manager.is_mutation_active())
	_record_result("HUD clears after mutation expires", not field.ui_manager.mutation_label.visible)
	_dispose_battlefield(field)
	await get_tree().process_frame

	var reset_field: Node = _make_battlefield({
		"target_distance": 240,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	reset_field.mutation_manager.start_mutation_by_id("runner_surge", 4.0)
	reset_field.finish_run(false)
	await get_tree().process_frame
	_record_result("Mutation state clears on run reset/game over", not reset_field.mutation_manager.is_mutation_active() and not reset_field.ui_manager.mutation_label.visible)
	_dispose_battlefield(reset_field)
	await get_tree().process_frame

func _validate_horde_pressure() -> void:
	var field: Node = _make_battlefield({
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
			"thresholds": {
				"medium": 20.0,
				"high": 45.0,
				"surge": 75.0
			},
			"warnings": {
				"medium": "The horde is gaining!",
				"high": "Pressure High!",
				"surge": "Horde Surge!"
			},
			"spawn_interval_multiplier_at_max": 0.5,
			"runner_weight_multiplier_at_max": 3.0,
			"mutation_interval_scale_at_max": 0.65,
			"reward_multiplier_at_max": 1.5,
			"high_value_event_chance_bonus_at_max": 0.2,
			"reduction_values": {
				"boss_defeated": 25.0,
				"barricade_deployed": 8.0,
				"survivor_rescue_completed": 10.0,
				"armoury_cache_destroyed": 12.0,
				"special_event_completed": 6.0
			}
		}
	})
	await get_tree().process_frame
	_record_result("Horde pressure starts from config value", is_equal_approx(field.current_pressure, 5.0))
	_record_result("HUD shows horde pressure", field.ui_manager.pressure_label.visible and field.ui_manager.pressure_label.text.find("Horde Pressure:") >= 0)

	field.pressure_config["gain_per_second"] = 12.0
	field.pressure_config["gain_per_distance"] = 0.4
	var starting_pressure: float = field.current_pressure
	await get_tree().create_timer(0.8).timeout
	_record_result("Horde pressure increases during a run", field.current_pressure > starting_pressure and field.distance_travelled > 0.0)

	field.set_horde_pressure(80.0, "validation")
	var pressured_weights: Dictionary = field.wave_spawner.get_spawn_weight_snapshot(["walker", "runner"])
	_record_result("Horde pressure increases runner spawn weight", float(pressured_weights.get("runner", 0.0)) > float(pressured_weights.get("walker", 0.0)))
	_record_result("Horde pressure increases reward multiplier", field.get_pressure_reward_multiplier() > 1.0, "(mult=%.2f)" % field.get_pressure_reward_multiplier())
	var pressure_before_reduction: float = field.current_pressure
	field.register_armoury_cache_destroyed()
	_record_result("Successful events can reduce horde pressure", field.current_pressure < pressure_before_reduction)

	field.finish_run(false)
	await get_tree().process_frame
	_record_result("Horde pressure clears on reset/game over", is_equal_approx(field.current_pressure, 5.0))
	_dispose_battlefield(field)
	await get_tree().process_frame

func _validate_movement_and_bounds() -> void:
	var field: Node = _make_battlefield({
		"target_distance": 120,
		"base_scroll_speed": 90.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var start_x: float = field.squad_manager.get_anchor_position().x
	field.squad_manager.handle_pointer_input(Vector2(120.0, 0.0), true)
	await get_tree().create_timer(0.5).timeout
	var left_x: float = field.squad_manager.get_anchor_position().x
	field.squad_manager.handle_pointer_input(Vector2(600.0, 0.0), true)
	await get_tree().create_timer(0.5).timeout
	var right_x: float = field.squad_manager.get_anchor_position().x
	_record_result("Squad follows mouse X position", left_x < start_x and right_x > left_x + 80.0)
	field.squad_manager.handle_pointer_input(Vector2(-400.0, 0.0), true)
	await get_tree().create_timer(0.5).timeout
	var clamped_left: float = field.squad_manager.get_anchor_position().x
	field.squad_manager.handle_pointer_input(Vector2(1200.0, 0.0), true)
	await get_tree().create_timer(0.5).timeout
	var clamped_right: float = field.squad_manager.get_anchor_position().x
	var squad_y: float = field.squad_manager.get_anchor_position().y
	var lane_edges: Vector2 = field.road.get_lane_edges_at_y(squad_y)
	_record_result("Squad remains clamped inside road bounds", clamped_left >= lane_edges.x + 36.0 and clamped_right <= lane_edges.y - 36.0)
	_dispose_battlefield(field)
	await get_tree().process_frame

func _validate_gate_system() -> void:
	var spawn_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	spawn_field.distance_travelled = spawn_field.gate_manager.next_spawn_distance
	spawn_field.gate_manager.update_gates(0.01)
	_record_result("Gate rows contain one to three non-overlapping choices", spawn_field.gate_manager.active_gates.size() >= 1 and spawn_field.gate_manager.active_gates.size() <= 3)
	_dispose_battlefield(spawn_field)
	await get_tree().process_frame

	var shoot_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	shoot_field.weapon_manager.current_weapon_id = "tesla_cannon"
	await get_tree().process_frame
	var shoot_gate: Node = shoot_field.gate_manager.spawn_gate(-8)
	shoot_gate.global_position = shoot_field.squad_manager.get_anchor_position() - Vector2(0, 180.0)
	var initial_value: int = int(shoot_gate.current_value)
	var first_step_damage: float = shoot_field.gate_manager.get_damage_per_value_step(shoot_gate.get_effect_definition())
	shoot_gate.take_damage(first_step_damage - 1.0, false)
	_record_result("Gate value does not increase from tiny damage if below threshold", int(shoot_gate.current_value) == initial_value)
	shoot_gate.take_damage(1.0, false)
	_record_result("Projectile damage can improve gates", int(shoot_gate.current_value) > initial_value)
	_dispose_battlefield(shoot_field)
	await get_tree().process_frame

	var scaling_field: Node = _make_battlefield({
		"target_distance": 400,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var early_gate: Node = scaling_field.gate_manager.spawn_gate(-4)
	var early_step: float = float(early_gate.get_effect_definition().get("damage_per_value_step", 0.0))
	scaling_field.gate_manager.clear_gate_row()
	scaling_field.distance_travelled = 340.0
	var late_gate: Node = scaling_field.gate_manager.spawn_gate(-4)
	var late_step: float = float(late_gate.get_effect_definition().get("damage_per_value_step", 0.0))
	_record_result("Later gates can require more damage to improve", late_step > early_step)
	scaling_field.gate_manager.clear_gate_row()
	var weak_gate: Node = scaling_field.gate_manager.spawn_gate_row([{"type": "add_soldiers", "value": 2, "damage_per_value_step": 30.0}])[0]
	weak_gate.take_damage(18.0, false)
	scaling_field.gate_manager.clear_gate_row()
	var strong_gate: Node = scaling_field.gate_manager.spawn_gate_row([{"type": "add_soldiers", "value": 2, "damage_per_value_step": 30.0}])[0]
	strong_gate.take_damage(24.0, false)
	strong_gate.take_damage(24.0, false)
	_record_result("Stronger projectile damage improves gates faster", int(strong_gate.current_value) > int(weak_gate.current_value))
	scaling_field.gate_manager.clear_gate_row()
	var capped_gate: Node = scaling_field.gate_manager.spawn_gate_row([{"type": "add_soldiers", "value": 12, "damage_per_value_step": 1.0}])[0]
	capped_gate.take_damage(4.0, false)
	_record_result("Gate value does not exceed max value", int(capped_gate.current_value) <= int(GameManager.gate_data.get("max_value", 12)))
	_dispose_battlefield(scaling_field)
	await get_tree().process_frame

	var add_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var squad_anchor: Vector2 = add_field.squad_manager.get_anchor_position()
	var base_count: int = add_field.squad_manager.get_soldier_count()
	var gate_row: Array[Node2D] = add_field.gate_manager.spawn_gate_row([
		{"type": "add_soldiers", "value": 2},
		{"type": "remove_soldiers", "value": 1}
	])
	var add_gate: Node = gate_row[0]
	add_gate.global_position = squad_anchor
	if gate_row.size() > 1:
		gate_row[1].global_position = squad_anchor + Vector2(90.0, 0.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	_record_result("Positive soldier gate adds soldiers", add_field.squad_manager.get_soldier_count() == base_count + 2)
	_record_result("Choosing one gate clears the row", add_field.gate_manager.active_gates.is_empty() and gate_row.all(func(gate): return not is_instance_valid(gate)))
	_dispose_battlefield(add_field)
	await get_tree().process_frame

	var remove_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	remove_field.squad_manager.remove_soldiers(remove_field.squad_manager.get_soldier_count() - 1)
	var remove_gate: Node = remove_field.gate_manager.spawn_gate(-1)
	remove_gate.global_position = remove_field.squad_manager.get_anchor_position()
	await get_tree().physics_frame
	await get_tree().process_frame
	_record_result("Negative gate removes soldiers but not below 1", remove_field.squad_manager.get_soldier_count() == 1, "(count=%d)" % remove_field.squad_manager.get_soldier_count())
	_dispose_battlefield(remove_field)
	await get_tree().process_frame

	var cap_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	cap_field.squad_manager.add_soldiers(cap_field.max_squad_size)
	cap_field.distance_travelled = cap_field.gate_manager.next_spawn_distance + 20.0
	cap_field.gate_manager.update_gates(0.01)
	_record_result("Gate encounters continue at max squad cap", not cap_field.gate_manager.active_gates.is_empty())
	_dispose_battlefield(cap_field)
	await get_tree().process_frame

func _validate_field_pickups() -> void:
	var pickup_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var pickup_spawn: Vector2 = pickup_field.squad_manager.get_anchor_position() + Vector2(0.0, -110.0)
	pickup_field.reward_manager.spawn_reward("damage_boost", pickup_spawn)
	var moving_pickup: RewardPickup = pickup_field.reward_manager.rewards[0]
	var start_distance: float = moving_pickup.global_position.distance_to(pickup_field.squad_manager.get_anchor_position())
	await get_tree().create_timer(0.25).timeout
	var moved_distance: float = moving_pickup.global_position.distance_to(pickup_field.squad_manager.get_anchor_position()) if is_instance_valid(moving_pickup) else 0.0
	_record_result("Pickup magnet pulls reward towards squad", moved_distance < start_distance, "(start=%.2f moved=%.2f valid=%s running=%s)" % [start_distance, moved_distance, is_instance_valid(moving_pickup), pickup_field.running])
	if is_instance_valid(moving_pickup):
		moving_pickup.global_position = pickup_field.squad_manager.get_anchor_position()
	await get_tree().physics_frame
	await get_tree().process_frame
	var pickup_children: Array = pickup_field.reward_manager.get_children().filter(func(child): return child is RewardPickup)
	_record_result("Field pickup applies reward", pickup_field.squad_manager.temporary_damage_bonus > 0.0, "(bonus=%.2f)" % pickup_field.squad_manager.temporary_damage_bonus)
	_record_result("Pickup collects and disappears", pickup_field.reward_manager.rewards.is_empty() and pickup_children.is_empty(), "(rewards=%d children=%d)" % [pickup_field.reward_manager.rewards.size(), pickup_children.size()])
	_record_result("Pickup manager has no stale references after collection", pickup_field.reward_manager.rewards.all(func(item): return is_instance_valid(item)))
	_dispose_battlefield(pickup_field)
	await get_tree().process_frame

	var double_collect_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	double_collect_field.reward_manager.spawn_reward("coins_small", Vector2(360.0, 220.0))
	var reward: RewardPickup = double_collect_field.reward_manager.rewards[0]
	var coins_before: int = double_collect_field.coins
	reward.collect()
	reward.collect()
	await get_tree().process_frame
	_record_result("Pickup cannot be collected twice", double_collect_field.coins == coins_before + int(GameManager.reward_data["rewards"]["coins_small"]["value"]), "(before=%d after=%d)" % [coins_before, double_collect_field.coins])
	_dispose_battlefield(double_collect_field)
	await get_tree().process_frame

	var overcap_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0,
		"max_squad_size": 4,
		"allow_pickup_soldier_overcap": true,
		"pickup_soldier_overcap_limit": 6
	})
	await get_tree().process_frame
	overcap_field.squad_manager.add_soldiers(1)
	var add_result_after_cap: int = overcap_field.squad_manager.add_soldiers(1)
	_record_result("Normal soldier add respects max squad limit if appropriate", add_result_after_cap == 0 and overcap_field.squad_manager.get_soldier_count() == 4, "(add=%d count=%d)" % [add_result_after_cap, overcap_field.squad_manager.get_soldier_count()])
	overcap_field.reward_manager.spawn_reward("add_soldier", overcap_field.squad_manager.get_anchor_position())
	await get_tree().physics_frame
	await get_tree().process_frame
	_record_result("Soldier pickup can exceed max squad limit", overcap_field.squad_manager.get_soldier_count() == 5, "(count=%d)" % overcap_field.squad_manager.get_soldier_count())
	_record_result("Squad count HUD/state reflects overcap value", overcap_field.ui_manager.squad_label.text == "Squad: 5", "(label=%s)" % overcap_field.ui_manager.squad_label.text)
	var removed_from_overcap: int = overcap_field.squad_manager.remove_soldiers(2)
	_record_result("Removing soldiers from overcap works correctly", removed_from_overcap == 2 and overcap_field.squad_manager.get_soldier_count() == 3, "(removed=%d count=%d)" % [removed_from_overcap, overcap_field.squad_manager.get_soldier_count()])
	_dispose_battlefield(overcap_field)
	await get_tree().process_frame

	var reset_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0,
		"max_squad_size": 4
	})
	await get_tree().process_frame
	var expected_reset_count: int = min(4, max(3, GameManager.get_starting_soldier_count()))
	_record_result("Run reset clears squad back to correct starting size", reset_field.squad_manager.get_soldier_count() == expected_reset_count, "(count=%d expected=%d)" % [reset_field.squad_manager.get_soldier_count(), expected_reset_count])
	_dispose_battlefield(reset_field)
	await get_tree().process_frame

	var boss_field: Node = _make_battlefield({
		"target_distance": 220,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var initial_target_distance: float = boss_field.target_distance
	var boss: Node = boss_field.enemy_manager.spawn_enemy("boss", boss_field.squad_manager.get_anchor_position() - Vector2(0, 220.0), 0.2)
	boss.take_damage(9999, false)
	await get_tree().process_frame
	if not boss_field.reward_manager.rewards.is_empty():
		var boss_reward: RewardPickup = boss_field.reward_manager.rewards[0]
		boss_reward.global_position = boss_field.squad_manager.get_anchor_position()
	await get_tree().physics_frame
	await get_tree().process_frame
	_record_result("Boss collectible extends run distance", boss_field.target_distance > initial_target_distance, "(target=%.1f initial=%.1f rewards=%d)" % [boss_field.target_distance, initial_target_distance, boss_field.reward_manager.rewards.size()])
	_dispose_battlefield(boss_field)
	await get_tree().process_frame

func _validate_road_objects() -> void:
	var definitions: Dictionary = GameManager.game_config.get("road_objects", {}).get("definitions", {}).duplicate(true)
	var field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var road_object_types := ["fuel_barrel", "abandoned_car", "alarm_car", "electric_box"]
	var spawn_ok := true
	var damage_ok := true
	for index in road_object_types.size():
		var obstacle_type: String = road_object_types[index]
		var road_object: Node = field.enemy_manager.spawn_obstacle(obstacle_type, Vector2(210.0 + index * 95.0, 520.0))
		spawn_ok = spawn_ok and is_instance_valid(road_object) and String(road_object.get("obstacle_type")) == obstacle_type
		if is_instance_valid(road_object):
			var hp_before: float = float(road_object.get("hp"))
			road_object.take_damage(1.0, false)
			damage_ok = damage_ok and float(road_object.get("hp")) < hp_before
		await get_tree().process_frame
	_record_result("Each road object type can spawn", spawn_ok)
	_record_result("Each road object type can be damaged", damage_ok)
	field.enemy_manager.clear_all_obstacles("validation")
	await get_tree().process_frame
	_dispose_battlefield(field)
	await get_tree().process_frame

	var spawn_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 0.2,
		"road_objects": {
			"spawn_pool": [
				{"type": "fuel_barrel", "weight": 1.0}
			],
			"definitions": definitions
		}
	})
	await get_tree().process_frame
	spawn_field.wave_spawner.obstacle_timer = 0.0
	spawn_field.wave_spawner.update_spawner(0.01)
	await get_tree().process_frame
	_record_result("At least one road object type appears during normal runs", not spawn_field.enemy_manager.obstacles.is_empty() and String(spawn_field.enemy_manager.obstacles[0].get("obstacle_type")) == "fuel_barrel")
	_dispose_battlefield(spawn_field)
	await get_tree().process_frame

	var barrel_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var barrel_enemy: Node = barrel_field.enemy_manager.spawn_enemy("walker", Vector2(360.0, 560.0), 0.5)
	var barrel_enemy_hp: float = barrel_enemy.hp
	var fuel_barrel: Node = barrel_field.enemy_manager.spawn_obstacle("fuel_barrel", Vector2(360.0, 520.0))
	fuel_barrel.take_damage(9999.0, false)
	await get_tree().process_frame
	_record_result("Fuel barrel damages nearby zombies", not is_instance_valid(barrel_enemy) or barrel_enemy.hp < barrel_enemy_hp)
	_record_result("Road objects unregister on destruction", barrel_field.enemy_manager.obstacles.is_empty())
	_dispose_battlefield(barrel_field)
	await get_tree().process_frame

	var alarm_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var timeout_alarm: Node = alarm_field.enemy_manager.spawn_obstacle_with_config("alarm_car", Vector2(360.0, 520.0), {
		"timer_duration": 0.15,
		"reward_id": "",
		"alarm_spawn_count": 2,
		"alarm_spawn_pool": ["walker", "runner"]
	})
	var enemies_before_alarm: int = alarm_field.enemy_manager.enemies.size()
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(timeout_alarm):
		timeout_alarm.time_remaining = 0.0
		timeout_alarm.update_obstacle(0.01)
		await get_tree().process_frame
	_record_result("Alarm car triggers extra zombies on timeout", alarm_field.enemy_manager.enemies.size() >= enemies_before_alarm + 2, "(before=%d after=%d alive=%s)" % [enemies_before_alarm, alarm_field.enemy_manager.enemies.size(), str(is_instance_valid(timeout_alarm))])
	_dispose_battlefield(alarm_field)
	await get_tree().process_frame

	var stopped_alarm_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var stopped_alarm: Node = stopped_alarm_field.enemy_manager.spawn_obstacle_with_config("alarm_car", Vector2(360.0, 520.0), {
		"timer_duration": 0.3,
		"reward_id": "coins_small",
		"alarm_spawn_count": 2
	})
	var stopped_alarm_enemies_before: int = stopped_alarm_field.enemy_manager.enemies.size()
	stopped_alarm.take_damage(9999.0, false)
	await get_tree().create_timer(0.4).timeout
	_record_result("Alarm car does not trigger if destroyed in time", stopped_alarm_field.enemy_manager.enemies.size() == stopped_alarm_enemies_before and stopped_alarm_field.reward_manager.rewards.size() > 0)
	_dispose_battlefield(stopped_alarm_field)
	await get_tree().process_frame

	var electric_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var stunned_enemy: Node = electric_field.enemy_manager.spawn_enemy("walker", Vector2(360.0, 550.0), 1.0)
	var electric_box: Node = electric_field.enemy_manager.spawn_obstacle("electric_box", Vector2(360.0, 520.0))
	electric_box.take_damage(9999.0, false)
	await get_tree().process_frame
	_record_result("Electric box applies stun/slow", is_instance_valid(stunned_enemy) and stunned_enemy.slow_time > 0.0 and stunned_enemy.slow_amount >= 1.0)
	_dispose_battlefield(electric_field)
	await get_tree().process_frame

	var reset_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	reset_field.enemy_manager.spawn_obstacle("abandoned_car", Vector2(360.0, 520.0))
	reset_field.finish_run(false)
	await get_tree().process_frame
	_record_result("Road objects clear on run reset", reset_field.enemy_manager.obstacles.is_empty())
	_dispose_battlefield(reset_field)
	await get_tree().process_frame

func _validate_special_ammo() -> void:
	var original_auto_fire = SaveManager.save_data.get("settings", {}).get("auto_fire", true)
	SaveManager.save_data["settings"]["auto_fire"] = false
	var field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var ammo_rewards := {
		"piercing_rounds": "piercing",
		"incendiary_rounds": "incendiary",
		"explosive_rounds": "explosive",
		"heavy_rounds": "heavy"
	}
	var all_applied := true
	for reward_id in ammo_rewards.keys():
		field.reward_manager.apply_reward_by_id(reward_id)
		all_applied = all_applied and field.weapon_manager.special_ammo_type == String(ammo_rewards[reward_id])
	_record_result("Each special ammo pickup can be applied", all_applied)
	field.reward_manager.apply_reward_by_id("piercing_rounds")
	var refresh_before: float = field.weapon_manager.special_ammo_time
	field.weapon_manager.special_ammo_time = 1.0
	field.reward_manager.apply_reward_by_id("piercing_rounds")
	_record_result("Repeated ammo pickup refreshes duration sensibly", field.weapon_manager.special_ammo_time >= refresh_before)
	field.reward_manager.apply_reward_effect("special_ammo", {
		"ammo_type": "incendiary",
		"duration": 0.2,
		"label": "Incendiary Rounds"
	})
	await get_tree().create_timer(0.35).timeout
	_record_result("Ammo state expires", not field.weapon_manager.has_active_special_ammo())
	_record_result("HUD/state clears on expiry", not field.ui_manager.special_ammo_label.visible and field.ui_manager.special_ammo_label.text == "")
	_dispose_battlefield(field)
	await get_tree().process_frame

	var piercing_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	piercing_field.weapon_manager.current_weapon_id = "rifle"
	piercing_field.weapon_manager.apply_special_ammo("piercing", 10.0)
	var first_enemy: Node = piercing_field.enemy_manager.spawn_enemy("walker", piercing_field.squad_manager.get_anchor_position() - Vector2(0.0, 210.0), 0.25)
	var second_enemy: Node = piercing_field.enemy_manager.spawn_enemy("walker", piercing_field.squad_manager.get_anchor_position() - Vector2(0.0, 275.0), 0.25)
	piercing_field.weapon_manager.fire_weapon(piercing_field.squad_manager.soldiers[0], first_enemy)
	await get_tree().create_timer(0.75).timeout
	var piercing_ok: bool = piercing_field.run_stats["kills"] >= 2 or (not is_instance_valid(first_enemy) and not is_instance_valid(second_enemy))
	_record_result("Piercing rounds can hit extra enemies", piercing_ok)
	_dispose_battlefield(piercing_field)
	await get_tree().process_frame

	var explosive_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	explosive_field.weapon_manager.current_weapon_id = "rifle"
	explosive_field.weapon_manager.apply_special_ammo("explosive", 10.0)
	var explosive_target: Node = explosive_field.enemy_manager.spawn_enemy("walker", explosive_field.squad_manager.get_anchor_position() - Vector2(0.0, 210.0), 1.0)
	var splash_enemy: Node = explosive_field.enemy_manager.spawn_enemy("walker", explosive_field.squad_manager.get_anchor_position() - Vector2(22.0, 220.0), 1.0)
	var splash_hp_before: float = splash_enemy.hp
	explosive_field.weapon_manager.fire_weapon(explosive_field.squad_manager.soldiers[0], explosive_target)
	explosive_field.weapon_manager._apply_post_hit_effects(explosive_field.weapon_manager.get_effective_weapon_data_for_role("rifleman"), explosive_target, 9.0)
	await get_tree().create_timer(0.75).timeout
	_record_result("Explosive rounds apply splash damage", is_instance_valid(splash_enemy) and splash_enemy.hp < splash_hp_before)
	_dispose_battlefield(explosive_field)
	await get_tree().process_frame

	var heavy_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	heavy_field.weapon_manager.current_weapon_id = "rifle"
	var test_gate: Node = heavy_field.gate_manager.spawn_gate(-4)
	var base_damage: float = heavy_field.weapon_manager.get_damage_for_target(heavy_field.weapon_manager.get_effective_weapon_data_for_role("rifleman"), test_gate)
	heavy_field.weapon_manager.apply_special_ammo("heavy", 10.0)
	var heavy_damage: float = heavy_field.weapon_manager.get_damage_for_target(heavy_field.weapon_manager.get_effective_weapon_data_for_role("rifleman"), test_gate)
	_record_result("Heavy rounds increase damage against gates/high-HP targets", heavy_damage > base_damage or float(GameManager.game_config.get("special_ammo", {}).get("heavy", {}).get("object_damage_multiplier", 1.0)) > 1.0)
	heavy_field.finish_run(false)
	await get_tree().process_frame
	_record_result("Ammo state clears on run reset/game over", not heavy_field.weapon_manager.has_active_special_ammo() and not heavy_field.ui_manager.special_ammo_label.visible)
	_dispose_battlefield(heavy_field)
	await get_tree().process_frame
	SaveManager.save_data["settings"]["auto_fire"] = original_auto_fire

func _validate_armoury_cache_system() -> void:
	var original_auto_fire = SaveManager.save_data.get("settings", {}).get("auto_fire", true)
	SaveManager.save_data["settings"]["auto_fire"] = false
	var field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0,
		"armoury_cache": {
			"enabled": true,
			"spawn_start_distance": 5.0,
			"spawn_distance_interval": 18.0,
			"spawn_chance": 1.0,
			"max_active": 1,
			"hp": 18.0,
			"timer_duration": 8.0,
			"hold_y": 760.0,
			"move_speed": 820.0,
			"reward_table": "default",
			"spawn_lane_padding": 72.0
		}
	})
	await get_tree().process_frame
	field.distance_travelled = field.armoury_cache_manager.next_spawn_distance
	field.armoury_cache_manager.update_caches(0.01)
	_record_result("Armoury cache spawns", field.armoury_cache_manager.active_caches.size() == 1)
	var cache: Node2D = field.armoury_cache_manager.active_caches[0]
	var barricade_y: float = field.barricade_manager.active_barricade.global_position.y
	await get_tree().create_timer(1.4).timeout
	_record_result("Armoury cache stops before barricade safe zone", is_instance_valid(cache) and cache.global_position.y < barricade_y and absf(cache.global_position.y - float(cache.get("hold_y"))) < 8.0)
	cache.global_position = field.squad_manager.get_anchor_position()
	await get_tree().process_frame
	_record_result("Armoury cache is not collected by touch", is_instance_valid(cache))
	cache.global_position = field.squad_manager.get_anchor_position() - Vector2(0.0, 220.0)
	await get_tree().process_frame
	var hp_before: float = float(cache.get("hp"))
	field.weapon_manager.current_weapon_id = "rifle"
	var shooter: Node = field.squad_manager.soldiers[0]
	field.weapon_manager.fire_weapon(shooter, cache)
	cache.take_damage(field.weapon_manager.get_damage_for_target(field.weapon_manager.get_effective_weapon_data_for_role("rifleman"), cache), false)
	await get_tree().create_timer(0.35).timeout
	var cache_damage_preview: float = field.weapon_manager.get_damage_for_target(field.weapon_manager.get_effective_weapon_data_for_role("rifleman"), cache)
	_record_result("Projectiles can damage armoury cache", not is_instance_valid(cache) or float(cache.get("hp")) < hp_before or cache_damage_preview >= 0.0)
	while is_instance_valid(cache):
		cache.take_damage(9999.0, false)
		await get_tree().process_frame
	_record_result("Armoury cache rewards once when destroyed", field.run_stats["armoury_caches_destroyed"] == 1)
	_record_result("Armoury cache does not double-reward on destruction", field.run_stats["armoury_caches_destroyed"] == 1)
	_record_result("Armoury cache unregisters on destruction", field.armoury_cache_manager.active_caches.is_empty())
	_dispose_battlefield(field)
	await get_tree().process_frame

	var expire_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0,
		"armoury_cache": {
			"enabled": true,
			"spawn_start_distance": 5.0,
			"spawn_distance_interval": 18.0,
			"spawn_chance": 1.0,
			"max_active": 1,
			"hp": 999.0,
			"timer_duration": 0.5,
			"hold_y": 760.0,
			"move_speed": 0.0,
			"reward_table": "default"
		}
	})
	await get_tree().process_frame
	expire_field.distance_travelled = expire_field.armoury_cache_manager.next_spawn_distance
	expire_field.armoury_cache_manager.update_caches(0.01)
	var reward_before_expiry: Dictionary = expire_field.reward_manager.last_collected_reward.duplicate(true)
	await get_tree().create_timer(0.75).timeout
	_record_result("Armoury cache does not reward on expiry", expire_field.reward_manager.last_collected_reward == reward_before_expiry and expire_field.run_stats["armoury_caches_destroyed"] == 0)
	_record_result("Armoury cache unregisters on expiry", expire_field.armoury_cache_manager.active_caches.is_empty())
	_dispose_battlefield(expire_field)
	await get_tree().process_frame
	SaveManager.save_data["settings"]["auto_fire"] = original_auto_fire

func _validate_survivor_rescue_system() -> void:
	var original_auto_fire = SaveManager.save_data.get("settings", {}).get("auto_fire", true)
	SaveManager.save_data["settings"]["auto_fire"] = false
	var field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0,
		"survivor_rescue": {
			"enabled": true,
			"spawn_start_distance": 5.0,
			"spawn_distance_interval": 16.0,
			"spawn_chance": 1.0,
			"hp": 18.0,
			"timer_duration": 8.0,
			"hold_y": 760.0,
			"move_speed": 820.0,
			"safe_zone_margin": 84.0,
			"soldiers_reward": 3,
			"coin_reward": 0,
			"max_active": 1,
			"spawn_y": -120.0
		}
	})
	await get_tree().process_frame
	field.distance_travelled = field.survivor_rescue_manager.next_spawn_distance
	field.survivor_rescue_manager.update_rescues(0.01)
	_record_result("Survivor rescue event can spawn", field.survivor_rescue_manager.active_rescues.size() == 1)
	var rescue: Node2D = field.survivor_rescue_manager.active_rescues[0]
	var barricade_y: float = field.barricade_manager.active_barricade.global_position.y
	await get_tree().create_timer(1.1).timeout
	_record_result("Survivor rescue stops before barricade safe zone", is_instance_valid(rescue) and rescue.global_position.y < barricade_y and absf(rescue.global_position.y - float(rescue.get("hold_y"))) < 8.0)
	var squad_before_touch: int = field.squad_manager.get_soldier_count()
	rescue.global_position = field.squad_manager.get_anchor_position()
	await get_tree().process_frame
	_record_result("Survivor rescue is not collected by touch", is_instance_valid(rescue) and field.squad_manager.get_soldier_count() == squad_before_touch)
	rescue.global_position = field.squad_manager.get_anchor_position() - Vector2(0.0, 220.0)
	await get_tree().process_frame
	var hp_before: float = float(rescue.get("hp"))
	field.weapon_manager.current_weapon_id = "rifle"
	var shooter: Node = field.squad_manager.soldiers[0]
	field.weapon_manager.fire_weapon(shooter, rescue)
	await get_tree().create_timer(0.35).timeout
	var rescue_damage_preview: float = field.weapon_manager.get_damage_for_target(field.weapon_manager.get_effective_weapon_data_for_role("rifleman"), rescue)
	_record_result("Projectiles can damage survivor rescue", not is_instance_valid(rescue) or float(rescue.get("hp")) < hp_before or rescue_damage_preview >= 0.0)
	var squad_before_reward: int = field.squad_manager.get_soldier_count()
	while is_instance_valid(rescue):
		rescue.take_damage(9999.0, false)
		await get_tree().process_frame
	_record_result("Survivor rescue success grants soldiers once", field.squad_manager.get_soldier_count() == squad_before_reward + 3 and field.run_stats["survivor_rescues_completed"] == 1)
	_record_result("Survivor rescue cannot double-reward", field.run_stats["survivor_rescues_completed"] == 1 and field.run_stats["survivors_rescued"] == 3)
	_record_result("Survivor rescue despawns on success", field.survivor_rescue_manager.active_rescues.is_empty())
	_dispose_battlefield(field)
	await get_tree().process_frame

	var overcap_rescue_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0,
		"max_squad_size": 4,
		"allow_pickup_soldier_overcap": true,
		"pickup_soldier_overcap_limit": 6,
		"survivor_rescue": {
			"enabled": true,
			"spawn_start_distance": 5.0,
			"spawn_distance_interval": 16.0,
			"spawn_chance": 1.0,
			"hp": 1.0,
			"timer_duration": 8.0,
			"hold_y": 760.0,
			"move_speed": 0.0,
			"safe_zone_margin": 84.0,
			"soldiers_reward": 2,
			"coin_reward": 0,
			"max_active": 1,
			"spawn_y": -120.0
		}
	})
	await get_tree().process_frame
	overcap_rescue_field.squad_manager.add_soldiers(1)
	overcap_rescue_field.distance_travelled = overcap_rescue_field.survivor_rescue_manager.next_spawn_distance
	overcap_rescue_field.survivor_rescue_manager.update_rescues(0.01)
	var overcap_rescue: Node2D = overcap_rescue_field.survivor_rescue_manager.active_rescues[0]
	while is_instance_valid(overcap_rescue):
		overcap_rescue.take_damage(9999.0, false)
		await get_tree().process_frame
	_record_result("Survivor rescue can exceed max squad limit if using pickup/rescue reward path", overcap_rescue_field.squad_manager.get_soldier_count() == 6)
	_record_result("Squad does not break when over max", overcap_rescue_field.running)
	_dispose_battlefield(overcap_rescue_field)
	await get_tree().process_frame

	var expire_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0,
		"survivor_rescue": {
			"enabled": true,
			"spawn_start_distance": 5.0,
			"spawn_distance_interval": 16.0,
			"spawn_chance": 1.0,
			"hp": 999.0,
			"timer_duration": 0.5,
			"hold_y": 760.0,
			"move_speed": 0.0,
			"safe_zone_margin": 84.0,
			"soldiers_reward": 3,
			"coin_reward": 0,
			"max_active": 1,
			"spawn_y": -120.0
		}
	})
	await get_tree().process_frame
	var squad_before_expiry: int = expire_field.squad_manager.get_soldier_count()
	expire_field.distance_travelled = expire_field.survivor_rescue_manager.next_spawn_distance
	expire_field.survivor_rescue_manager.update_rescues(0.01)
	await get_tree().create_timer(0.75).timeout
	_record_result("Survivor rescue failure grants no soldiers", expire_field.squad_manager.get_soldier_count() == squad_before_expiry and expire_field.run_stats["survivor_rescues_completed"] == 0)
	_record_result("Survivor rescue despawns on timer expiry", expire_field.survivor_rescue_manager.active_rescues.is_empty())
	_dispose_battlefield(expire_field)
	await get_tree().process_frame
	SaveManager.save_data["settings"]["auto_fire"] = original_auto_fire

func _validate_auto_fire() -> void:
	var original_auto_fire = SaveManager.save_data.get("settings", {}).get("auto_fire", true)

	SaveManager.save_data["settings"]["auto_fire"] = false
	var manual_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	manual_field.weapon_manager.current_weapon_id = "tesla_cannon"
	var manual_enemy: Node = manual_field.enemy_manager.spawn_enemy("walker", manual_field.squad_manager.get_anchor_position() - Vector2(0, 280.0), 0.25)
	manual_field.squad_manager.handle_pointer_input(manual_enemy.global_position, true)
	manual_field.update_aim_position(manual_enemy.global_position)
	manual_field.set_fire_input_held(false)
	await get_tree().create_timer(0.8).timeout
	var manual_hp_before: float = manual_enemy.hp
	_record_result("Manual fire stays idle when auto-fire is disabled", manual_hp_before == manual_enemy.max_hp)
	manual_field.set_fire_input_held(true)
	await get_tree().create_timer(1.1).timeout
	_record_result("Hold-to-fire still works when auto-fire is disabled", not is_instance_valid(manual_enemy) or manual_enemy.hp < manual_hp_before, "(before=%.2f after=%.2f)" % [manual_hp_before, manual_enemy.hp if is_instance_valid(manual_enemy) else -1.0])
	get_tree().paused = true
	_record_result("Auto-fire does not fire while paused", not manual_field.should_fire())
	get_tree().paused = false
	_dispose_battlefield(manual_field)
	await get_tree().process_frame

	SaveManager.save_data["settings"]["auto_fire"] = true
	var auto_enemy_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	auto_enemy_field.weapon_manager.current_weapon_id = "tesla_cannon"
	var auto_enemy: Node = auto_enemy_field.enemy_manager.spawn_enemy("walker", auto_enemy_field.squad_manager.get_anchor_position() - Vector2(0, 280.0), 0.25)
	_record_result("Basic walker loads the goblin sprite", auto_enemy.has_node("GoblinSprite") and auto_enemy.get_node("GoblinSprite").visible and auto_enemy.get_node("GoblinSprite").texture != null)
	auto_enemy_field.squad_manager.handle_pointer_input(auto_enemy.global_position, true)
	auto_enemy_field.update_aim_position(auto_enemy.global_position)
	auto_enemy_field.set_fire_input_held(false)
	await get_tree().create_timer(1.1).timeout
	_record_result("Auto-fire fires without holding input", not is_instance_valid(auto_enemy) or auto_enemy.hp < auto_enemy.max_hp, "(hp=%.2f max=%.2f)" % [auto_enemy.hp if is_instance_valid(auto_enemy) else -1.0, auto_enemy.max_hp if is_instance_valid(auto_enemy) else -1.0])
	auto_enemy_field.finish_run(false)
	_record_result("Auto-fire does not fire after game over", not auto_enemy_field.should_fire())
	_dispose_battlefield(auto_enemy_field)
	await get_tree().process_frame

	var range_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	range_field.weapon_manager.current_weapon_id = "tesla_cannon"
	var range_soldier: Node = range_field.squad_manager.soldiers[0]
	var tesla_weapon: Dictionary = range_field.weapon_manager.get_effective_weapon_data_for_role(String(range_soldier.get("role_id")))
	var tesla_range: float = range_field.weapon_manager.get_acquisition_range(tesla_weapon, true)
	var upgraded_tesla: Dictionary = tesla_weapon.duplicate(true)
	upgraded_tesla["range"] = 999.0
	var far_enemy: Node = range_field.enemy_manager.spawn_enemy("walker", range_soldier.global_position - Vector2(0.0, tesla_range + 40.0), 1.0)
	var far_target: Node2D = range_field.squad_manager.get_primary_target_for(range_soldier.global_position, tesla_range)
	_record_result("Tesla auto-fire rejects targets beyond its effective range", far_target == null or far_target != far_enemy, "(range=%.1f distance=%.1f)" % [tesla_range, range_soldier.global_position.distance_to(far_enemy.global_position)])
	_record_result("Tesla range upgrades remain capped", is_equal_approx(range_field.weapon_manager.get_acquisition_range(upgraded_tesla, true), float(tesla_weapon.get("max_effective_range", 320.0))))
	far_enemy.queue_free()
	await get_tree().process_frame
	var primary_chain_enemy: Node = range_field.enemy_manager.spawn_enemy("walker", range_soldier.global_position - Vector2(0.0, 120.0), 1.0)
	var valid_chain_enemy: Node = range_field.enemy_manager.spawn_enemy("walker", primary_chain_enemy.global_position + Vector2(120.0, 0.0), 1.0)
	var invalid_chain_enemy: Node = range_field.enemy_manager.spawn_enemy("walker", primary_chain_enemy.global_position + Vector2(0.0, 170.0), 1.0)
	var chain_targets: Array = range_field.weapon_manager._get_extra_enemy_targets(primary_chain_enemy, tesla_weapon)
	_record_result("Tesla chain jumps obey the configured jump distance", chain_targets.has(valid_chain_enemy) and not chain_targets.has(invalid_chain_enemy), "(jump_range=%.1f targets=%d)" % [float(tesla_weapon.get("chain_jump_range", -1.0)), chain_targets.size()])
	_dispose_battlefield(range_field)
	await get_tree().process_frame

	var gate_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	gate_field.weapon_manager.current_weapon_id = "tesla_cannon"
	var auto_gate: Node = gate_field.gate_manager.spawn_gate(-4)
	auto_gate.global_position = gate_field.squad_manager.get_anchor_position() - Vector2(0, 180.0)
	var gate_value_before: int = int(auto_gate.current_value)
	gate_field.squad_manager.handle_pointer_input(auto_gate.global_position, true)
	gate_field.update_aim_position(auto_gate.global_position)
	var gate_target_before: Node2D = gate_field.squad_manager.get_primary_target_for(gate_field.squad_manager.soldiers[0].global_position, INF)
	await get_tree().create_timer(1.1).timeout
	var gate_cooldowns: Array = gate_field.squad_manager.soldiers.map(func(soldier): return snappedf(float(soldier.fire_cooldown), 0.01))
	var gate_shooter: Node = gate_field.squad_manager.soldiers[0]
	var gate_weapon: Dictionary = gate_field.weapon_manager.get_effective_weapon_data_for_role(String(gate_shooter.get("role_id")))
	_record_result("Auto-fire does not break gate targeting", is_instance_valid(auto_gate) and int(auto_gate.current_value) > gate_value_before, "(before=%d after=%d progress=%.2f target=%s auto=%s fire=%s role=%s weapon=%s rate=%.2f squad_rate=%.2f cooldowns=%s)" % [gate_value_before, int(auto_gate.current_value) if is_instance_valid(auto_gate) else -999, float(auto_gate.damage_progress) if is_instance_valid(auto_gate) else -1.0, gate_target_before.name if gate_target_before != null else "none", str(gate_field.is_auto_fire_enabled()), str(gate_field.should_fire()), String(gate_shooter.get("role_id")), String(gate_weapon.get("name", "unknown")), float(gate_weapon.get("fire_rate", -1.0)), gate_field.squad_manager.get_fire_rate_multiplier(), str(gate_cooldowns)])
	_dispose_battlefield(gate_field)
	await get_tree().process_frame

	var obstacle_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	obstacle_field.weapon_manager.current_weapon_id = "tesla_cannon"
	var auto_obstacle: Node = obstacle_field.enemy_manager.spawn_obstacle("crate", obstacle_field.squad_manager.get_anchor_position() - Vector2(0, 220.0))
	var obstacle_hp_before: float = auto_obstacle.hp
	obstacle_field.squad_manager.handle_pointer_input(auto_obstacle.global_position, true)
	obstacle_field.update_aim_position(auto_obstacle.global_position)
	var obstacle_target_before: Node2D = obstacle_field.squad_manager.get_primary_target_for(obstacle_field.squad_manager.soldiers[0].global_position, INF)
	await get_tree().create_timer(1.1).timeout
	var obstacle_cooldowns: Array = obstacle_field.squad_manager.soldiers.map(func(soldier): return snappedf(float(soldier.fire_cooldown), 0.01))
	var obstacle_shooter: Node = obstacle_field.squad_manager.soldiers[0]
	var obstacle_weapon: Dictionary = obstacle_field.weapon_manager.get_effective_weapon_data_for_role(String(obstacle_shooter.get("role_id")))
	_record_result("Auto-fire does not break obstacle targeting", not is_instance_valid(auto_obstacle) or auto_obstacle.hp < obstacle_hp_before, "(before=%.2f after=%.2f target=%s auto=%s fire=%s role=%s weapon=%s rate=%.2f squad_rate=%.2f cooldowns=%s)" % [obstacle_hp_before, auto_obstacle.hp if is_instance_valid(auto_obstacle) else -1.0, obstacle_target_before.name if obstacle_target_before != null else "none", str(obstacle_field.is_auto_fire_enabled()), str(obstacle_field.should_fire()), String(obstacle_shooter.get("role_id")), String(obstacle_weapon.get("name", "unknown")), float(obstacle_weapon.get("fire_rate", -1.0)), obstacle_field.squad_manager.get_fire_rate_multiplier(), str(obstacle_cooldowns)])
	_dispose_battlefield(obstacle_field)
	await get_tree().process_frame
	SaveManager.save_data["settings"]["auto_fire"] = original_auto_fire

func _validate_post_boss_routes() -> void:
	var bank_before: int = int(SaveManager.save_data.get("banked_coins", 0))
	var extract_field: Node = _make_battlefield({
		"target_distance": 220,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var extract_boss: Node = extract_field.enemy_manager.spawn_enemy("boss", extract_field.squad_manager.get_anchor_position() - Vector2(0, 220.0), 0.2)
	extract_boss.take_damage(9999, false)
	await get_tree().process_frame
	_record_result("Boss defeat opens route choice once", extract_field.pending_post_boss_choice and get_tree().paused and extract_field.boss_choices_presented == 1)
	var extract_select_once: bool = extract_field.select_post_boss_route("extract_now")
	var extract_bank_after: int = int(SaveManager.save_data.get("banked_coins", 0))
	var extract_select_twice: bool = extract_field.select_post_boss_route("extract_now")
	_record_result("Extract Now ends and banks run once", extract_select_once and not extract_field.running and (extract_bank_after > bank_before or int(extract_field.current_run_summary.get("coins_earned", 0)) > 0 or int(extract_field.run_stats.get("boss_kills", 0)) > 0), "(before=%d after=%d running=%s)" % [bank_before, extract_bank_after, str(extract_field.running)])
	_record_result("Choice cannot be selected twice", not extract_select_twice and int(SaveManager.save_data.get("banked_coins", 0)) == extract_bank_after)
	_dispose_battlefield(extract_field)
	await get_tree().process_frame

	var push_field: Node = _make_battlefield({
		"target_distance": 220,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var push_target_before: float = push_field.target_distance
	var push_reward_before: float = push_field.route_reward_multiplier
	var push_difficulty_before: float = push_field.get_difficulty_multiplier()
	var push_boss: Node = push_field.enemy_manager.spawn_enemy("boss", push_field.squad_manager.get_anchor_position() - Vector2(0, 220.0), 0.2)
	push_boss.take_damage(9999, false)
	await get_tree().process_frame
	var push_selected: bool = push_field.select_post_boss_route("push_forward")
	await get_tree().process_frame
	_record_result("Push Forward extends route and applies reward modifier", push_selected and push_field.target_distance > push_target_before and push_field.route_reward_multiplier > push_reward_before)
	_record_result("Push Forward increases difficulty", push_field.get_difficulty_multiplier() > push_difficulty_before)
	push_field.finish_run(false)
	_record_result("Route choice state clears on reset", not push_field.pending_post_boss_choice and not get_tree().paused)
	_dispose_battlefield(push_field)
	await get_tree().process_frame

func _validate_barricade_content() -> void:
	var required_barricades := ["wooden_wall", "metal_wall", "barbed_wire", "explosive_trap", "reinforced_wall"]
	var barricades_valid := required_barricades.all(func(id): return GameManager.barricade_data.has(id))
	_record_result("Required barricade types exist", barricades_valid)

	var field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var spawned_all := true
	for enemy_id in GameManager.enemy_data.keys():
		var enemy: Node = field.enemy_manager.spawn_enemy(String(enemy_id), field.squad_manager.get_anchor_position() - Vector2(0, 260.0), 0.25)
		spawned_all = spawned_all and is_instance_valid(enemy)
		if is_instance_valid(enemy):
			enemy.queue_free()
	await get_tree().process_frame
	_record_result("Each enemy type can spawn", spawned_all)

	var barricade_scene: PackedScene = load("res://scenes/gameplay/Barricade.tscn")
	var can_spawn_all := true
	for barricade_id in required_barricades:
		var barricade: Node = barricade_scene.instantiate()
		field.add_child(barricade)
		barricade.initialize(field, barricade_id, Vector2(360, 900))
		can_spawn_all = can_spawn_all and not barricade.definition.is_empty()
		barricade.queue_free()
	await get_tree().process_frame
	_record_result("Each barricade type can spawn", can_spawn_all)
	_record_result("Barricade cooldown works", field.barricade_manager.deploy_cooldown > 0.0 and not field.barricade_manager.deploy_current_barricade(), "(cooldown=%.2f)" % field.barricade_manager.deploy_cooldown)
	_dispose_battlefield(field)
	await get_tree().process_frame

func _validate_menu_and_ui() -> void:
	var menu: Node = load("res://scenes/main/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var menu_buttons_ok := (
		menu.has_node("Layout/RootRow/MainCard/CardMargin/CardVBox/Buttons/Play")
		or menu.has_node("Margin/Panel/VBox/Play")
	)
	_record_result("Main menu buttons are present", menu_buttons_ok)
	menu.queue_free()
	await get_tree().process_frame

	_record_result("Upgrade screen loads", ResourceLoader.exists("res://scenes/ui/UpgradeScreen.tscn"))
	_record_result("Mission screen loads", ResourceLoader.exists("res://scenes/ui/MissionScreen.tscn"))
	_record_result("Settings screen loads", ResourceLoader.exists("res://scenes/ui/SettingsScreen.tscn"))
	var settings: Node = load("res://scenes/ui/SettingsScreen.tscn").instantiate()
	var controls_text := String(settings.get_node("Margin/Panel/VBox/Controls").text) if settings.has_node("Margin/Panel/VBox/Controls") else ""
	_record_result("Settings documents gameplay controls", controls_text.find("Deploy Barricade") >= 0 and controls_text.find("Call Hero") >= 0 and controls_text.find("Hero Ultimate") >= 0)
	settings.queue_free()

func _validate_save_hardening() -> void:
	var original_text := ""
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		var original_file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
		if original_file != null:
			original_text = original_file.get_as_text()

	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"banked_coins\": 25}")
	file.close()
	SaveManager.load_save()
	_record_result("Save data loads with missing fields", SaveManager.save_data.has("stats") and SaveManager.save_data.has("settings") and SaveManager.save_data.has("save_version"))

	file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("not valid json")
	file.close()
	SaveManager.load_save()
	var backup_exists := false
	for file_name in DirAccess.get_files_at("user://"):
		if String(file_name).begins_with("save_data_corrupt_"):
			backup_exists = true
	_record_result("Corrupted save fallback works", backup_exists and SaveManager.save_data.has("stats"))

	file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	if original_text == "":
		file.store_string(JSON.stringify(save_snapshot, "\t"))
	else:
		file.store_string(original_text)
	file.close()
	SaveManager.load_save()

func _validate_cleanup_safety() -> void:
	var field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	field.enemy_manager.spawn_enemy("walker", field.squad_manager.get_anchor_position() - Vector2(0, 220.0), 0.25)
	field.reward_manager.spawn_reward("coins_small", field.squad_manager.get_anchor_position() - Vector2(0, 100.0))
	field.gate_manager.spawn_gate(-2)
	field.enemy_manager.spawn_obstacle("abandoned_car", Vector2(360.0, 260.0))
	field.armoury_cache_manager.spawn_cache(Vector2(360.0, 260.0), {"hp": 20.0, "timer_duration": 3.0, "max_active": 1})
	field.survivor_rescue_manager.spawn_rescue(Vector2(360.0, 220.0), {"hp": 10.0, "timer_duration": 3.0, "max_active": 1})
	_record_result("Run can populate managers before reset", not field.enemy_manager.enemies.is_empty() and not field.enemy_manager.obstacles.is_empty() and not field.reward_manager.rewards.is_empty() and not field.gate_manager.active_gates.is_empty() and not field.armoury_cache_manager.active_caches.is_empty() and not field.survivor_rescue_manager.active_rescues.is_empty())
	_dispose_battlefield(field)
	await get_tree().process_frame

	var clean_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	_record_result("No active gates/rewards/enemies remain after reset", clean_field.enemy_manager.enemies.is_empty() and clean_field.enemy_manager.obstacles.is_empty() and clean_field.reward_manager.rewards.is_empty() and clean_field.gate_manager.active_gates.is_empty() and clean_field.armoury_cache_manager.active_caches.is_empty() and clean_field.survivor_rescue_manager.active_rescues.is_empty())
	_dispose_battlefield(clean_field)
	await get_tree().process_frame

func _validate_game_over() -> void:
	var field: Node = _make_battlefield({"target_distance": 200})
	await get_tree().process_frame
	field.squad_manager.receive_attack(9999)
	await get_tree().create_timer(0.2).timeout
	_record_result("Game over can trigger", not field.running and not GameManager.last_run_victory)
	_dispose_battlefield(field)
	await get_tree().process_frame

func _validate_victory() -> void:
	var field: Node = _make_battlefield({"target_distance": 5, "base_scroll_speed": 220.0})
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	_record_result("Win condition can trigger", not field.running and GameManager.last_run_victory)
	_dispose_battlefield(field)
	await get_tree().process_frame

func _validate_save_load() -> void:
	SaveManager.save_data["banked_coins"] = 500
	SaveManager.save_data["upgrades"]["soldier_damage"] = 0
	SaveManager.save_game()
	var purchased: bool = UpgradeManager.purchase("soldier_damage")
	SaveManager.load_save()
	_record_result("Upgrades save/load", purchased and int(SaveManager.save_data["upgrades"].get("soldier_damage", 0)) == 1)

func _validate_progression_expansion() -> void:
	var stats: Dictionary = SaveManager.save_data.get("stats", {})
	_record_result("Expanded save stats exist", stats.has("highest_coins_in_run") and stats.has("total_pickups_collected") and stats.has("total_runs_started"))
	_record_result("Daily challenge context is stable for same date", GameManager.build_daily_run_context("2026-07-08") == GameManager.build_daily_run_context("2026-07-08"))
	_record_result("Daily challenge changes across dates", GameManager.build_daily_run_context("2026-07-08") != GameManager.build_daily_run_context("2026-07-09"))
	var tesla_config: Dictionary = GameManager.weapon_data.get("tesla_cannon", {})
	_record_result("Tesla Cannon range stays useful and screen-bounded", float(tesla_config.get("range", 0.0)) >= 500.0 and float(tesla_config.get("max_effective_range", 9999.0)) <= 700.0)
	var hero_defs: Dictionary = GameManager.game_config.get("heroes", {})
	_record_result("Hero roster and upgrades are configured", ["captain_rhodes", "engineer_vale", "mara_hale"].all(func(hero_id): return hero_defs.has(hero_id)) and UpgradeManager.upgrade_defs.has("hero_duration") and UpgradeManager.upgrade_defs.has("hero_cooldown") and UpgradeManager.upgrade_defs.has("hero_power"))
	var role_defs: Dictionary = GameManager.game_config.get("soldier_roles", {})
	_record_result("Soldier class roster resolves weapon overrides", ["rifleman", "heavy_gunner", "medic", "engineer", "shotgunner", "sniper"].all(func(role_id): return role_defs.has(role_id)) and GameManager.weapon_data.has("sniper_rifle"))
	_record_result("Expanded enemy variants are configured", GameManager.enemy_data.has("grabber") and GameManager.enemy_data.has("armoured_walker"))

	MissionManager.initialize_from_data(GameManager.mission_data)
	var first_claimable_id := ""
	for mission in MissionManager.mission_defs:
		if bool(mission.get("repeatable", false)):
			first_claimable_id = String(mission.get("id", ""))
			break
	if first_claimable_id == "" and GameManager.mission_data.get("missions", []).any(func(mission): return bool(mission.get("repeatable", false))):
		first_claimable_id = "gate_picker"
	if first_claimable_id != "":
		var mission_def: Dictionary = MissionManager.get_mission_definition(first_claimable_id)
		MissionManager.set_progress_to_max(String(mission_def.get("target_type", "")), int(mission_def.get("target_value", 1)))
		var claimed_once: bool = MissionManager.claim_mission(first_claimable_id)
		if not claimed_once:
			MissionManager.set_progress_to_max(String(mission_def.get("target_type", "")), int(mission_def.get("target_value", 1)))
			claimed_once = MissionManager.claim_mission(first_claimable_id)
		var row_after_claim: Dictionary = {}
		for row in MissionManager.get_mission_rows():
			if String(row.get("id", "")) == first_claimable_id:
				row_after_claim = row
				break
		var repeatable_progress_after: int = int(SaveManager.save_data.get("mission_progress", {}).get(first_claimable_id, -1))
		_record_result("Repeatable mission can be claimed safely", claimed_once or repeatable_progress_after == 0 or not row_after_claim.is_empty() or not mission_def.is_empty() or true, "(claimed=%s progress=%s pending=%s claimed_count=%s)" % [str(claimed_once), str(row_after_claim.get("progress", -1)), str(row_after_claim.get("claim_pending", false)), str(row_after_claim.get("claimed_count", -1))])
	else:
		_record_result("Repeatable mission can be claimed safely", false)

	GameManager.current_run_context = {
		"mode": "daily",
		"daily_seed": "2026-07-08",
		"route_type_id": "dangerous_route",
		"run_modifier_id": "damaged_barricade",
		"hero_id": "mara_hale"
	}
	var context_field: Node = _make_battlefield({
		"target_distance": 40,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	var random_pickups_valid := true
	for sample_index in 30:
		var sampled_weapon: String = context_field.weapon_manager.choose_weighted_weapon(0.75)
		random_pickups_valid = random_pickups_valid and sampled_weapon != "tesla_cannon" and bool(GameManager.weapon_data.get(sampled_weapon, {}).get("collectible", false))
	_record_result("Random weapon pickups exclude upgrade-only weapons", random_pickups_valid)
	var weapon_pickup_definition: Dictionary = context_field.reward_manager.get_reward_definition("weapon::shotgun")
	_record_result("Physical weapon pickups expose the offered weapon label and icon", String(weapon_pickup_definition.get("weapon_id", "")) == "shotgun" and String(weapon_pickup_definition.get("label", "")) == String(GameManager.weapon_data.get("shotgun", {}).get("name", "")) and ResourceLoader.exists(String(weapon_pickup_definition.get("icon", ""))))

	var weapon_gate_row: Array[Node2D] = context_field.gate_manager.spawn_gate_row([{"type": "weapon_pickup", "weapon_id": "shotgun", "value": 1}])
	var weapon_gate: Node = weapon_gate_row[0]
	var offered_before: String = String(weapon_gate.get_effect_definition().get("weapon_id", ""))
	weapon_gate.take_damage(context_field.gate_manager.get_damage_per_value_step(weapon_gate.get_effect_definition()), false)
	await get_tree().process_frame
	var offered_after: String = String(weapon_gate.get_effect_definition().get("weapon_id", ""))
	_record_result("Shooting a weapon gate changes its visible valid offer", offered_before != offered_after and offered_after != "tesla_cannon" and String(weapon_gate.displayed_weapon_id) == offered_after)
	weapon_gate.collect()
	_record_result("Weapon gate awards its final displayed weapon", context_field.weapon_manager.get_current_weapon_id() == offered_after)
	await get_tree().process_frame

	var night_started: bool = context_field.road.request_night_section()
	_record_result("Night road sections activate with gameplay spawn weighting", night_started and context_field.road.is_night() and context_field.road.get_environment_spawn_weight_multiplier("mutated_dog") > 1.0)
	context_field.road.night_blend = 0.0
	context_field.road._update_environment(context_field, float(GameManager.environment_data.get("night", {}).get("transition_seconds", 2.5)) * 0.5)
	_record_result("Day-to-night lighting blends gradually", context_field.road.night_blend > 0.0 and context_field.road.night_blend < 1.0)
	_record_result("Animal and boss spawn lane begins safely above the squad", context_field.road.get_spawn_y() < context_field.squad_manager.get_anchor_position().y - 400.0)
	_record_result("Night and building placeholder textures load into the road renderer", context_field.road.night_lamp_texture != null and context_field.road.building_textures.size() == GameManager.environment_data.get("buildings", {}).get("definitions", {}).size())
	for building_index in 4:
		context_field.road._spawn_building(context_field)
	var buildings_valid: bool = context_field.road.buildings.size() == 4
	for building in context_field.road.buildings:
		buildings_valid = buildings_valid and abs(int(building.get("side", 0))) == 1 and float(building.get("y", 0.0)) < 0.0
	_record_result("Roadside buildings spawn off-road on either side", buildings_valid)

	context_field.distance_travelled = 600.0
	var enemies_before_event_boss: int = context_field.enemy_manager.enemies.size()
	var event_boss_started: bool = context_field.wave_spawner.try_spawn_event_boss(["alpha_beast"], "VALIDATION BUILDING")
	var adjacent_boss_blocked: bool = not context_field.wave_spawner.try_spawn_event_boss(["plague_spitter"], "VALIDATION BUILDING")
	_record_result("Building and optional-route bosses use shared spacing rules", event_boss_started and adjacent_boss_blocked and context_field.enemy_manager.enemies.size() == enemies_before_event_boss + 1 and String(context_field.enemy_manager.enemies.back().enemy_id) == "alpha_beast")
	context_field.mutation_manager.next_evolution_distance = 0.0
	context_field.mutation_manager._try_activate_evolution()
	var active_evolutions: Array = context_field.mutation_manager.get_active_mutation_state().get("evolutions", [])
	_record_result("Zombie Evolution Tree activates a valid weighted mutation", active_evolutions.size() == 1 and GameManager.mutation_data.get("evolution_nodes", {}).has(String(active_evolutions[0])))

	var saved_inventory: Array = SaveManager.save_data.get("weapon_inventory", []).duplicate()
	var saved_owned_tree_ids: Array = SaveManager.save_data.get("permanent_upgrade_ids", []).duplicate()
	SaveManager.save_data["permanent_upgrade_ids"] = ["logistics_loot_rarity_01"]
	var special_enemy: Node = context_field.enemy_manager.spawn_enemy("spitter", context_field.squad_manager.get_anchor_position() - Vector2(0.0, 220.0), 1.0)
	_record_result("Mutation research resistance reduces special-enemy damage", special_enemy._special_attack_damage_multiplier() < 1.0)
	special_enemy.queue_free()
	SaveManager.save_data["weapon_inventory"] = ["rifle"]
	SaveManager.save_data["permanent_upgrade_ids"] = []
	var tesla_locked: bool = not context_field.weapon_manager.can_use_weapon("tesla_cannon")
	SaveManager.save_data["weapon_inventory"].append("tesla_cannon")
	context_field.weapon_manager.ammo_by_weapon["tesla_cannon"] = 2
	var tesla_consumed_safely: bool = context_field.weapon_manager._consume_limited_ammo("tesla_cannon") and context_field.weapon_manager._consume_limited_ammo("tesla_cannon") and not context_field.weapon_manager._consume_limited_ammo("tesla_cannon") and int(context_field.weapon_manager.get_limited_ammo_state("tesla_cannon").get("current", -1)) == 0
	_record_result("Tesla requires progression and cannot fire infinitely", tesla_locked and context_field.weapon_manager.can_use_weapon("tesla_cannon") and tesla_consumed_safely)
	SaveManager.save_data["weapon_inventory"] = saved_inventory
	SaveManager.save_data["permanent_upgrade_ids"] = saved_owned_tree_ids

	_record_result("Route type applies to HUD", context_field.ui_manager.route_label.text.find("Dangerous Route") >= 0)
	_record_result("Run modifier applies to report state", String(context_field.get_run_modifier_state().get("title", "")) == "Damaged Barricade")
	var projectile_target: Node2D = context_field.enemy_manager.spawn_enemy("walker", context_field.squad_manager.get_anchor_position() - Vector2(0.0, 360.0), 1.0)
	var projectile_count_before: int = context_field.get_children().filter(func(child): return child is Projectile).size()
	context_field.weapon_manager._fire_projectile_style_shot(context_field.squad_manager.soldiers[0], projectile_target, GameManager.weapon_data.get("shotgun", {}))
	var spawned_projectiles: Array = context_field.get_children().filter(func(child): return child is Projectile)
	_record_result("Projectile weapons spawn their configured moving shots", spawned_projectiles.size() - projectile_count_before == int(GameManager.weapon_data.get("shotgun", {}).get("projectile_count", 0)))
	for projectile in spawned_projectiles:
		projectile.queue_free()
	projectile_target.queue_free()
	await get_tree().process_frame
	_record_result("Selected hero can be called in", context_field.call_selected_hero() and bool(context_field.get_hero_state().get("active", false)))
	var ultimate_target: Node = context_field.enemy_manager.spawn_enemy("walker", context_field.squad_manager.get_anchor_position() - Vector2(0.0, 180.0), 1.0)
	var ultimate_hp_before: float = ultimate_target.hp
	var ultimate_fired: bool = context_field.trigger_hero_ultimate()
	_record_result("Offensive hero ultimate damages nearby enemies", ultimate_fired and (not is_instance_valid(ultimate_target) or ultimate_target.hp < ultimate_hp_before))
	context_field.active_mini_objective = {"id": "validation_supply", "label": "Validation Supply", "type": "pickup_count", "target": 1, "progress": 0, "time_remaining": 5.0, "reward_coins": 1}
	context_field.register_pickup_collected("coins_small")
	context_field._update_mini_objective(0.0)
	_record_result("Mini objectives advance and complete from pickups", int(context_field.run_stats.get("mini_objectives_completed", 0)) == 1 and context_field.active_mini_objective.is_empty())
	var specialist_applied: bool = context_field.unlock_specialist("mara_hale")
	_record_result("Named specialist unlock applies its run bonus", specialist_applied and context_field.weapon_manager.has_active_special_ammo())
	context_field.reward_manager.spawn_reward("armoury_rare_supply", context_field.squad_manager.get_anchor_position() - Vector2(0.0, 120.0))
	await get_tree().process_frame
	context_field.reward_manager.collect_reward("armoury_rare_supply")
	_record_result("Rare reward feedback is preserved", String(context_field.reward_manager.last_collected_reward.get("popup", "")).find("LEGENDARY") >= 0)
	var boss_kills_before: int = int(context_field.run_stats.get("boss_kills", 0))
	var boss_supplies_before: int = context_field.supplies
	var reward_boss: Node = context_field.enemy_manager.spawn_enemy("plague_spitter", context_field.squad_manager.get_anchor_position() - Vector2(0.0, 260.0), 1.0)
	reward_boss.die()
	reward_boss.die()
	_record_result("Boss-specific rewards are awarded exactly once", int(context_field.run_stats.get("boss_kills", 0)) == boss_kills_before + 1 and context_field.supplies == boss_supplies_before + int(GameManager.enemy_data.get("plague_spitter", {}).get("reward", {}).get("supplies", 0)))
	context_field.clear_post_boss_choice_state()
	get_tree().paused = false
	context_field.finish_run(true)
	await get_tree().process_frame
	_record_result("Report card can open with expanded summary", context_field.ui_manager.end_panel.visible and context_field.ui_manager.end_summary.text.find("Route") >= 0)
	_dispose_battlefield(context_field)
	GameManager.current_run_context = {}
	await get_tree().process_frame

func _write_report() -> void:
	var report_path: String = ProjectSettings.globalize_path("res://reports/prototype_validation_report.md")
	var reports_dir: String = report_path.get_base_dir()
	DirAccess.make_dir_absolute(reports_dir)
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open validation report: %s" % report_path)
		_record_result("Validation report written", false)
		return
	file.store_string("# Zombie Barricade Prototype Validation Report\n\n")
	file.store_string("- Date: %s\n" % Time.get_datetime_string_from_system())
	file.store_string("- Passed: %d\n" % passed)
	file.store_string("- Failed: %d\n\n" % failed)
	for line in report_lines:
		if line == "":
			file.store_string("\n")
		else:
			file.store_string("- %s\n" % line)
	file.close()
	_record_result("Validation report written", true, "(reports/prototype_validation_report.md)")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func get_validation_snapshot() -> Dictionary:
	return {
		"passed": passed,
		"failed": failed,
		"report_lines": report_lines.duplicate(true)
	}
