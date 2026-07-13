extends SceneTree

var failures: Array[String] = []
var passes := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("[PASS] ", label)
	else:
		failures.append(label)
		push_error("[FAIL] " + label)

func _run() -> void:
	var saves: Node = root.get_node("SaveManager")
	var game: Node = root.get_node("GameManager")
	saves.load_profile_index()
	for slot in 3:
		saves.clear_profile(slot)
	saves.create_profile(0, "Expansion Stress")
	saves.save_data["weapon_inventory"] = ["rifle", "tesla_cannon"]
	saves.save_data["heroes"]["unlocked"] = ["captain_rhodes", "dr_imani", "rook", "nyx", "arc"]
	saves.save_data["selected_hero"] = "rook"
	saves.save_game()
	game.initialize_active_profile()
	game.current_run_context = {"mode": "standard", "hero_id": "rook", "run_seed": 73193}
	var field: Node = load("res://scenes/gameplay/Battlefield.tscn").instantiate()
	root.add_child(field)
	await process_frame
	while field.squad_manager.get_soldier_count() < field.max_squad_size:
		field.squad_manager.add_soldier("rifleman")
	field.squad_manager._apply_formation(true)
	var enemy_ids: Array[String] = ["walker", "runner", "mutated_dog", "mutated_boar", "rat_swarm", "carrion_bird", "mutated_bear", "boss", "screamer_matriarch", "plague_spitter", "horde_commander", "night_stalker", "alpha_beast"]
	for index in 80:
		var enemy_id: String = enemy_ids[index % enemy_ids.size()]
		var spawn_position := Vector2(field.road.get_center_x() + float((index % 9) - 4) * 70.0, -140.0 + float(index / 9) * 62.0)
		field.enemy_manager.spawn_enemy(enemy_id, spawn_position, 1.0)
	for index in 18:
		field.reward_manager.spawn_reward("weapon::%s" % (["shotgun", "smg", "grenade_launcher"][index % 3]), Vector2(220.0 + float(index % 6) * 125.0, -80.0 - float(index / 6) * 70.0))
	field.gate_manager.spawn_gate_row([{"type": "weapon_pickup", "weapon_id": "shotgun"}, {"type": "supplies", "value": 5}, {"type": "night_section", "value": 1}])
	field.road.request_night_section()
	for index in 12:
		field.road._spawn_building(field)
	var hero_called: bool = field.call_selected_hero()
	var hero_ultimate_used: bool = field.trigger_hero_ultimate()
	field.weapon_manager.set_active_weapon("tesla_cannon")
	field.weapon_manager.refill_limited_ammo(field.weapon_manager.get_max_ammo("tesla_cannon"), "tesla_cannon")
	var shooter: Node = field.squad_manager.soldiers[0]
	for index in 12:
		var target: Node2D = field.enemy_manager.enemies[index]
		field.weapon_manager.fire_weapon(shooter, target)
	var started_usec := Time.get_ticks_usec()
	for frame_index in 120:
		await process_frame
	var elapsed_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	var max_buildings: int = int(game.environment_data.get("buildings", {}).get("max_visible", 6))
	_expect(field.squad_manager.get_soldier_count() == field.max_squad_size, "large squad remains bounded and active")
	_expect(hero_called and hero_ultimate_used and field.hero_avatar != null, "hero effects coexist with the stress horde")
	_expect(field.road.is_night() and field.road.buildings.size() <= max_buildings, "night lighting and roadside buildings stay bounded")
	_expect(field.reward_manager.rewards.size() <= 128 and field.gate_manager.active_gates.size() <= 3, "pickups and gates remain bounded under horde rewards")
	_expect(int(field.weapon_manager.get_limited_ammo_state("tesla_cannon").get("current", -1)) >= 0, "Tesla chain attacks never create negative ammunition")
	_expect(field.get_tree().get_node_count() < 1600, "combined expansion node count remains bounded")
	_expect(elapsed_seconds < 8.0, "120-frame integrated stress pass completes within eight seconds (%.2fs)" % elapsed_seconds)
	field.queue_free()
	await process_frame
	print("EXPANSION STRESS TESTS: %d passed, %d failed" % [passes, failures.size()])
	quit(0 if failures.is_empty() else 1)
