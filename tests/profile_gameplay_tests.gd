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
	_expect(saves.create_profile(0, "Alpha"), "creates Profile 1")
	saves.save_data["banked_coins"] = 123
	saves.save_game()
	_expect(saves.rename_profile(0, "  Alpha   Prime  "), "profile can be renamed")
	_expect(String(saves.save_data.get("profile_name", "")) == "Alpha Prime" and int(saves.save_data.get("banked_coins", 0)) == 123, "renaming trims spaces without resetting progression")
	_expect(saves.rename_profile(0, "   ") and String(saves.save_data.get("profile_name", "")) == "Profile 1", "blank profile names fall back to the slot default")
	_expect(saves.rename_profile(0, "Alpha\nPrime\tSquad") and String(saves.save_data.get("profile_name", "")) == "Alpha Prime Squad", "profile names normalize control whitespace")
	saves.rename_profile(0, "Alpha Prime")
	_expect(saves.create_profile(1, "Bravo"), "creates Profile 2")
	_expect(saves.select_profile(1) and int(saves.save_data["banked_coins"]) == 0, "Profile 2 progression is independent")
	saves.save_data["banked_coins"] = 9
	saves.save_game()
	_expect(saves.select_profile(0) and int(saves.save_data["banked_coins"]) == 123, "Profile 1 reloads its own coins")
	game.initialize_active_profile()
	_expect(saves.clear_profile(1) and saves.profile_exists(0) and not saves.profile_exists(1), "clearing Profile 2 is isolated")
	_expect(int(game.game_config.get("max_squad_size", 0)) == 48, "squad capacity doubled from 24 to 48")
	var road_script: Script = load("res://scripts/gameplay/Road.gd")
	var road: Node2D = Node2D.new()
	road.set_script(road_script)
	_expect(road.get_usable_road_width(0.0) >= 500.0, "road top width increased by at least 50 percent")
	_expect(road.get_usable_road_width(road.get_squad_y()) - 80.0 >= 726.0, "squad-line usable road width increased by at least 50 percent")
	var lanes: Array[float] = road.get_gate_row_positions(-150.0, 3)
	_expect(lanes.size() == 3 and lanes[0] < lanes[1] and lanes[1] < lanes[2], "three ordered gate lanes")
	var gate_width := float(game.gate_data.get("gate_width", 120.0))
	_expect(lanes[1] - lanes[0] > gate_width and lanes[2] - lanes[1] > gate_width, "gate visual and trigger widths do not overlap")
	_expect(saves.create_profile(2, "Charlie"), "creates Profile 3 for clear-confirmation coverage")
	var profile_scene: PackedScene = load("res://scenes/main/ProfileSelect.tscn")
	var profile_control: Node = profile_scene.instantiate() if profile_scene != null else null
	_expect(profile_scene != null and profile_control != null, "profile selection page loads")
	if profile_control != null:
		root.add_child(profile_control)
		await process_frame
		_expect(profile_control.get_node("Margin/Panel/VBox/Slots").get_child_count() == 3, "profile page contains exactly three selectable slots")
		_expect("Alpha Prime" in String(profile_control.get_node("Margin/Panel/VBox/Slots").get_child(0).text), "saved user-defined profile name is displayed")
		profile_control._select_slot(2)
		profile_control._on_clear_pressed()
		await process_frame
		var dialog: ConfirmationDialog = profile_control.get_node("ClearConfirmation")
		_expect(saves.profile_exists(2) and dialog.visible and "progression and run history" in dialog.dialog_text, "clear requires deliberate confirmation and explains deleted data")
		profile_control._on_clear_confirmed()
		_expect(not saves.profile_exists(2) and saves.profile_exists(0), "confirmed clear affects only the selected profile")
		dialog.hide()
		profile_control.queue_free()
		await process_frame
	saves.select_profile(0)
	game.initialize_active_profile()
	road.free()
	game.current_run_context = {"mode": "standard", "hero_id": "captain_rhodes"}
	saves.save_data["selected_hero"] = "captain_rhodes"
	saves.save_data["settings"]["auto_fire"] = true
	var battlefield: Node = load("res://scenes/gameplay/Battlefield.tscn").instantiate()
	root.add_child(battlefield)
	await process_frame
	while battlefield.squad_manager.get_soldier_count() < battlefield.max_squad_size:
		battlefield.squad_manager.add_soldier("rifleman")
	battlefield.squad_manager._apply_formation(true)
	var min_x := INF
	var max_x := -INF
	for soldier in battlefield.squad_manager.soldiers:
		min_x = min(min_x, soldier.position.x)
		max_x = max(max_x, soldier.position.x)
	_expect(battlefield.squad_manager.get_soldier_count() == 48, "48 soldiers spawn and remain functional")
	_expect(max_x - min_x + 24.0 <= gate_width * 0.9 + 0.1, "maximum visual formation remains narrower than one gate")
	var formation_inside_edges := true
	for pointer_x in [-1000.0, 3000.0]:
		battlefield.squad_manager.handle_pointer_input(Vector2(pointer_x, battlefield.road.get_squad_y()))
		battlefield.squad_manager.formation_center_x = battlefield.squad_manager.formation_target_x
		battlefield.squad_manager._apply_formation(true)
		for soldier in battlefield.squad_manager.soldiers:
			var edges: Vector2 = battlefield.road.get_lane_edges_at_y(soldier.position.y)
			if soldier.position.x - 12.0 < edges.x or soldier.position.x + 12.0 > edges.y:
				formation_inside_edges = false
	_expect(formation_inside_edges, "maximum formation remains inside both expanded road edges")
	_expect(battlefield.call_selected_hero(), "selected hero call succeeds")
	_expect(battlefield.hero_avatar != null and battlefield.hero_avatar.is_visible_in_tree() and battlefield.hero_avatar.z_index > 0, "hero has a visible world-space instance above the squad")
	var gate_choices_before: int = int(battlefield.run_stats.get("gates_chosen", 0))
	for lane_index in 3:
		var row: Array[Node2D] = battlefield.gate_manager.spawn_gate_row([
			{"type": "coins", "value": 1},
			{"type": "damage_boost", "value": 0.1},
			{"type": "fire_rate_boost", "value": 0.1}
		])
		var chosen_x: float = row[lane_index].global_position.x
		battlefield.squad_manager.formation_center_x = chosen_x
		battlefield.squad_manager.formation_target_x = chosen_x
		for gate in row:
			gate.global_position.y = battlefield.squad_manager.get_anchor_position().y
		battlefield.gate_manager.update_gates(0.0)
		await process_frame
	_expect(int(battlefield.run_stats.get("gates_chosen", 0)) == gate_choices_before + 3, "maximum squad selects left, centre, and right gates exactly once per row")
	_expect(battlefield.gate_manager.active_gates.is_empty(), "trailing soldiers cannot activate another gate in a selected row")
	var non_squad_row: Array[Node2D] = battlefield.gate_manager.spawn_gate_row([{"type": "coins", "value": 2}])
	var choices_before_projectile: int = int(battlefield.run_stats.get("gates_chosen", 0))
	non_squad_row[0].take_damage(999.0, false)
	_expect(int(battlefield.run_stats.get("gates_chosen", 0)) == choices_before_projectile and not non_squad_row[0].collected, "projectiles can modify but never select a gate")
	battlefield.gate_manager.clear_gate_row()
	await process_frame
	var shooter: Node = battlefield.squad_manager.soldiers[0]
	var projectile_count_before: int = battlefield.get_children().filter(func(child): return child is Projectile).size()
	shooter.fire_cooldown = 0.0
	shooter.update_soldier(0.01)
	var projectile_count_after: int = battlefield.get_children().filter(func(child): return child is Projectile).size()
	_expect(projectile_count_after > projectile_count_before, "standard auto-fire shoots on cadence without requiring a target")
	battlefield.weapon_manager.fire_weapon(shooter, null)
	var straight_projectile: Node2D
	for child in battlefield.get_children():
		if child is Projectile:
			straight_projectile = child
			break
	_expect(straight_projectile != null and abs(straight_projectile.velocity.x) < 0.01 and straight_projectile.velocity.dot(battlefield.road.get_forward_direction()) > 0.0, "auto-fire projectile travels straight along the road forward vector")
	battlefield.weapon_manager.current_weapon_id = "shotgun"
	var spread_start: int = battlefield.get_children().filter(func(child): return child is Projectile).size()
	battlefield.weapon_manager.fire_weapon(shooter, null)
	var spread_shots: Array = battlefield.get_children().filter(func(child): return child is Projectile).slice(spread_start)
	var configured_pellets: int = int(root.get_node("GameManager").weapon_data.get("shotgun", {}).get("projectile_count", 0))
	_expect(spread_shots.size() == configured_pellets and spread_shots.all(func(projectile): return abs(projectile.velocity.x) < 0.01), "multi-projectile auto-fire uses its configured pellet count and forward aim")
	battlefield.weapon_manager.current_weapon_id = "rifle"
	battlefield.hero_time_remaining = 0.01
	battlefield._update_hero_state(0.02)
	await process_frame
	_expect(battlefield.hero_avatar == null, "hero despawns when its gameplay duration expires")
	var all_heroes_visible := true
	var all_hero_ultimates_work := true
	for hero_id in game.get_hero_order():
		battlefield.selected_hero_id = hero_id
		battlefield.selected_hero_def = game.get_hero_def(hero_id)
		battlefield.hero_uses_remaining = 2
		battlefield.hero_cooldown_remaining = 0.0
		if not battlefield.call_selected_hero() or battlefield.hero_avatar == null or not battlefield.hero_avatar.is_visible_in_tree():
			all_heroes_visible = false
		battlefield.hero_ultimate_ready = true
		battlefield.hero_ultimate_uses_remaining = 1
		if not battlefield.trigger_hero_ultimate():
			all_hero_ultimates_work = false
		battlefield.hero_time_remaining = 0.0
		battlefield._update_hero_state(0.01)
		await process_frame
	_expect(all_heroes_visible, "every configured hero creates a visible gameplay avatar")
	_expect(all_hero_ultimates_work, "every configured hero can execute its data-driven ultimate")
	battlefield.selected_hero_id = "mara_hale"
	battlefield.selected_hero_def = game.get_hero_def("mara_hale")
	battlefield.hero_uses_remaining = 1
	battlefield.hero_cooldown_remaining = 0.0
	_expect(battlefield.call_selected_hero(), "hero can be called repeatedly after its allowed cooldown")
	battlefield.queue_free()
	await process_frame
	await process_frame
	root.get_node("AudioManager").clear_sfx()
	await process_frame
	await process_frame
	print("PROFILE/GAMEPLAY TESTS: %d passed, %d failed" % [passes, failures.size()])
	quit(0 if failures.is_empty() else 1)
