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

func _make_field(context: Dictionary) -> Node:
	var game: Node = root.get_node("GameManager")
	game.current_run_context = context.duplicate(true)
	var field: Node = load("res://scenes/gameplay/Battlefield.tscn").instantiate()
	root.add_child(field)
	await process_frame
	field.running = false
	return field

func _sample_rows(field: Node, count: int) -> Array[String]:
	var samples: Array[String] = []
	for index in count:
		field.gate_manager._spawn_next_gate_row()
		var gates: Array = field.gate_manager.active_gates
		var row: Array = []
		for gate in gates:
			var effect: Dictionary = gate.get_effect_definition()
			row.append([String(effect.get("type", "")), effect.get("value", 0), round(gate.global_position.x)])
		samples.append(JSON.stringify(row))
		field.gate_manager.clear_gate_row()
		await process_frame
	return samples

func _run() -> void:
	var saves: Node = root.get_node("SaveManager")
	var game: Node = root.get_node("GameManager")
	saves.load_profile_index()
	if not saves.profile_exists(0):
		saves.create_profile(0, "Gate Tests")
	saves.select_profile(0)
	root.get_node("GameManager").initialize_active_profile()
	var normal_context_a: Dictionary = game._build_run_context()
	await process_frame
	var normal_context_b: Dictionary = game._build_run_context()
	_expect(int(normal_context_a.get("run_seed", 0)) != 0 and int(normal_context_a.get("run_seed", 0)) != int(normal_context_b.get("run_seed", 0)), "normal runs receive fresh explicit run seeds")
	var daily_a := await _make_field({"mode": "daily", "daily_seed": "2030-02-03"})
	var rows_a := await _sample_rows(daily_a, 6)
	daily_a.queue_free()
	await process_frame
	var daily_b := await _make_field({"mode": "daily", "daily_seed": "2030-02-03"})
	var rows_b := await _sample_rows(daily_b, 6)
	_expect(rows_a == rows_b, "same daily seed reproduces gate layouts and lane occupancy")
	var adjacent_repeat := false
	for index in range(1, rows_b.size()):
		if rows_b[index] == rows_b[index - 1]:
			adjacent_repeat = true
	_expect(not adjacent_repeat, "short-term history prevents immediate gate-layout repetition")
	var lane_width: float = daily_b.road.get_usable_road_width(-280.0) / 3.0
	var gate_width: float = float(root.get_node("GameManager").gate_data.get("gate_width", 0.0))
	_expect(gate_width < lane_width, "gate width leaves a neutral margin inside each lane")
	var crossing_time: float = daily_b.road.get_usable_road_width(daily_b.road.get_squad_y()) / float(root.get_node("GameManager").game_config.get("squad_lateral_speed", 520.0)) + 0.75
	var required_spacing: float = (daily_b.scroll_speed / 10.0) * crossing_time
	_expect(float(root.get_node("GameManager").gate_data.get("spawn_distance_max", 0.0)) > float(root.get_node("GameManager").gate_data.get("spawn_distance_min", 0.0)) and required_spacing > 0.0, "gate spacing configuration and speed-based crossing calculation are valid")
	var new_gate_count: float = (float(root.get_node("GameManager").game_config.get("target_distance", 0.0)) - float(root.get_node("GameManager").gate_data.get("spawn_start_distance", 0.0))) / ((float(root.get_node("GameManager").gate_data.get("spawn_distance_min", 0.0)) + float(root.get_node("GameManager").gate_data.get("spawn_distance_max", 0.0))) * 0.5)
	_expect(new_gate_count >= 12.0 and new_gate_count <= 18.0, "normal run retains a substantial but controlled number of gate opportunities")
	daily_b.queue_free()
	await process_frame
	var traffic_field := await _make_field({"mode": "normal", "run_seed": 481516})
	var road_center: float = traffic_field.road.get_center_x()
	traffic_field.enemy_manager.spawn_obstacle("crate", Vector2(road_center, 220.0))
	traffic_field.reward_manager.spawn_reward("coins_small", Vector2(road_center + 160.0, 180.0))
	traffic_field.armoury_cache_manager.spawn_cache(Vector2(road_center - 180.0, 140.0))
	traffic_field.survivor_rescue_manager.spawn_rescue(Vector2(road_center + 220.0, 100.0))
	traffic_field.distance_travelled = traffic_field.gate_manager.next_spawn_distance
	traffic_field.gate_manager.update_gates(0.0)
	_expect(not traffic_field.gate_manager.active_gates.is_empty(), "ordinary road traffic cannot starve scheduled gate rows")
	traffic_field.queue_free()
	await process_frame
	print("GATE DETERMINISM TESTS: %d passed, %d failed" % [passes, failures.size()])
	quit(0 if failures.is_empty() else 1)
