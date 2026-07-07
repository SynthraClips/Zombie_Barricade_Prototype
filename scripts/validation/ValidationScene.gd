extends Control

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
	"barricades_deployed"
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
	if DisplayServer.get_name() == "headless":
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if failed == 0 else 1)

func _restore_save() -> void:
	SaveManager.save_data = save_snapshot.duplicate(true)
	SaveManager.save_game()

func _record_result(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passed += 1
		report_lines.append("[PASS] %s %s" % [name, detail])
	else:
		failed += 1
		report_lines.append("[FAIL] %s %s" % [name, detail])

func _validate_all() -> void:
	report_lines = ["Zombie Barricade Prototype Validation", ""]
	_validate_required_files()
	_validate_data_files()
	_validate_data_integrity()
	await _validate_scene_loading()
	await _validate_core_run()
	await _validate_movement_and_bounds()
	await _validate_gate_system()
	await _validate_field_pickups()
	await _validate_auto_fire()
	await _validate_barricade_content()
	await _validate_menu_and_ui()
	_validate_save_hardening()
	await _validate_cleanup_safety()
	await _validate_game_over()
	await _validate_victory()
	_validate_save_load()
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
		"res://data/rewards.json",
		"res://data/gates.json",
		"res://data/missions.json",
		"res://data/upgrades.json",
		"res://data/game_config.json"
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
	_record_result("Reward data loads", not GameManager.reward_data.get("rewards", {}).is_empty())
	_record_result("Gate data loads", not GameManager.gate_data.get("rows", []).is_empty() or not GameManager.gate_data.get("start_values", []).is_empty())
	_record_result("Mission data loads", not GameManager.mission_data.get("missions", []).is_empty())
	_record_result("Upgrade data loads", not GameManager.upgrade_data.get("upgrades", {}).is_empty())

func _validate_data_integrity() -> void:
	var waves_valid := true
	for wave in GameManager.wave_data.get("waves", []):
		waves_valid = waves_valid and int(wave.get("spawn_count", 0)) > 0
		for enemy_id in wave.get("pool", []):
			if not GameManager.enemy_data.has(String(enemy_id)):
				waves_valid = false
	_record_result("Wave enemy references are valid", waves_valid)

	var reward_refs_valid := true
	for reward_id in GameManager.reward_data.get("obstacle_reward_table", []):
		if not GameManager.reward_data.get("rewards", {}).has(String(reward_id)):
			reward_refs_valid = false
	for row in GameManager.gate_data.get("rows", []):
		for gate in row.get("gates", []):
			var gate_type: String = String(gate.get("type", ""))
			reward_refs_valid = reward_refs_valid and gate_type != ""
	_record_result("Reward and gate references are valid", reward_refs_valid)

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

func _make_battlefield(config_overrides: Dictionary = {}) -> Node:
	var original: Dictionary = GameManager.game_config.duplicate(true)
	for key in config_overrides.keys():
		GameManager.game_config[key] = config_overrides[key]
	var field: Node = load("res://scenes/gameplay/Battlefield.tscn").instantiate()
	field.set_meta("validation_original_config", original)
	add_child(field)
	return field

func _dispose_battlefield(field: Node) -> void:
	var original: Dictionary = field.get_meta("validation_original_config", {})
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
	_record_result("Squad spawns", field.squad_manager.get_soldier_count() >= 3)
	_record_result("Barricade deploys at run start", field.barricade_manager.active_barricade != null)
	var start_distance: float = field.distance_travelled
	await get_tree().create_timer(1.0).timeout
	_record_result("Distance counter increases", field.distance_travelled > start_distance)
	var first_enemy: Node = field.enemy_manager.spawn_enemy("walker", Vector2(360, 720), 0.25)
	field.squad_manager.handle_pointer_input(first_enemy.global_position, true)
	field.update_aim_position(first_enemy.global_position)
	field.set_fire_input_held(true)
	await get_tree().create_timer(2.0).timeout
	_record_result("Soldiers damage zombies", field.run_stats["kills"] > 0 or field.enemy_manager.enemies.any(func(enemy): return enemy.hp < enemy.max_hp))
	_record_result("Zombies can die", field.run_stats["kills"] > 0)
	_record_result("Coins are awarded", field.coins > 0)
	var obstacle: Node = field.enemy_manager.spawn_obstacle("crate", Vector2(360, 700))
	await get_tree().process_frame
	obstacle.take_damage(999)
	await get_tree().create_timer(0.6).timeout
	_record_result("Rewards can spawn from obstacles", field.reward_manager.rewards.size() > 0 or field.run_stats["obstacles_destroyed"] > 0)
	_record_result("Mission progress updates", int(SaveManager.save_data["mission_progress"].get("destroy_25_barrels", 0)) > 0)
	var barricade: Node = field.barricade_manager.active_barricade
	var barricade_hp: float = barricade.hp if barricade != null else 0.0
	var second_enemy: Node = field.enemy_manager.spawn_enemy("walker", Vector2(360, 860), 0.5)
	field.squad_manager.handle_pointer_input(second_enemy.global_position, true)
	field.update_aim_position(second_enemy.global_position)
	await get_tree().create_timer(1.3).timeout
	var barricade_damaged: bool = field.barricade_manager.active_barricade != null and field.barricade_manager.active_barricade.hp < barricade_hp
	_record_result("Barricade blocks zombies", barricade_damaged)
	field.barricade_manager.damage_active_barricade(9999)
	await get_tree().process_frame
	_record_result("Barricade can be destroyed", field.barricade_manager.active_barricade == null)
	field.set_fire_input_held(false)
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
	_record_result("Multiple gates can spawn in one row", spawn_field.gate_manager.active_gates.size() >= 2)
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
	shoot_field.squad_manager.handle_pointer_input(shoot_gate.global_position, true)
	shoot_field.update_aim_position(shoot_gate.global_position)
	shoot_field.set_fire_input_held(true)
	await get_tree().create_timer(0.7).timeout
	_record_result("Projectile damage can improve gates", int(shoot_gate.current_value) > initial_value)
	shoot_field.set_fire_input_held(false)
	_dispose_battlefield(shoot_field)
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
	_record_result("Negative gate removes soldiers but not below 1", remove_field.squad_manager.get_soldier_count() == 1)
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
	_record_result("Gates do not spawn at max squad cap", cap_field.gate_manager.active_gates.is_empty())
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
	_record_result("Pickup magnet pulls reward towards squad", moved_distance < start_distance)
	if is_instance_valid(moving_pickup):
		moving_pickup.global_position = pickup_field.squad_manager.get_anchor_position()
	await get_tree().physics_frame
	await get_tree().process_frame
	var pickup_children: Array = pickup_field.reward_manager.get_children().filter(func(child): return child is RewardPickup)
	_record_result("Field pickup applies reward", pickup_field.squad_manager.temporary_damage_bonus > 0.0)
	_record_result("Pickup collects and disappears", pickup_field.reward_manager.rewards.is_empty() and pickup_children.is_empty())
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
	_record_result("Pickup cannot be collected twice", double_collect_field.coins == coins_before + int(GameManager.reward_data["rewards"]["coins_small"]["value"]))
	_dispose_battlefield(double_collect_field)
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
	_record_result("Boss collectible extends run distance", boss_field.target_distance > initial_target_distance)
	_dispose_battlefield(boss_field)
	await get_tree().process_frame

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
	_record_result("Hold-to-fire still works when auto-fire is disabled", not is_instance_valid(manual_enemy) or manual_enemy.hp < manual_hp_before)
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
	auto_enemy_field.squad_manager.handle_pointer_input(auto_enemy.global_position, true)
	auto_enemy_field.update_aim_position(auto_enemy.global_position)
	auto_enemy_field.set_fire_input_held(false)
	await get_tree().create_timer(1.1).timeout
	_record_result("Auto-fire fires without holding input", not is_instance_valid(auto_enemy) or auto_enemy.hp < auto_enemy.max_hp)
	auto_enemy_field.finish_run(false)
	_record_result("Auto-fire does not fire after game over", not auto_enemy_field.should_fire())
	_dispose_battlefield(auto_enemy_field)
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
	await get_tree().create_timer(1.1).timeout
	_record_result("Auto-fire does not break gate targeting", is_instance_valid(auto_gate) and int(auto_gate.current_value) > gate_value_before)
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
	await get_tree().create_timer(1.1).timeout
	_record_result("Auto-fire does not break obstacle targeting", not is_instance_valid(auto_obstacle) or auto_obstacle.hp < obstacle_hp_before)
	_dispose_battlefield(obstacle_field)
	await get_tree().process_frame
	SaveManager.save_data["settings"]["auto_fire"] = original_auto_fire

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
	_record_result("Barricade cooldown works", field.barricade_manager.deploy_cooldown > 0.0 and not field.barricade_manager.deploy_current_barricade())
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
	_record_result("Run can populate managers before reset", not field.enemy_manager.enemies.is_empty() and not field.reward_manager.rewards.is_empty() and not field.gate_manager.active_gates.is_empty())
	_dispose_battlefield(field)
	await get_tree().process_frame

	var clean_field: Node = _make_battlefield({
		"target_distance": 200,
		"base_scroll_speed": 0.0,
		"base_enemy_spawn_interval": 99.0,
		"obstacle_spawn_interval": 99.0
	})
	await get_tree().process_frame
	_record_result("No active gates/rewards/enemies remain after reset", clean_field.enemy_manager.enemies.is_empty() and clean_field.reward_manager.rewards.is_empty() and clean_field.gate_manager.active_gates.is_empty())
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

func _write_report() -> void:
	var report_path: String = "res://reports/prototype_validation_report.md"
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
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
