extends Node2D
class_name GateManager

@export var gate_scene: PackedScene

var run_manager: Node
var active_gates: Array[Node2D] = []
var next_spawn_distance := 18.0
var spawn_index := 0
var current_row_id := 0
var rng := RandomNumberGenerator.new()
var recent_layouts: Array[String] = []

func setup(run: Node) -> void:
	run_manager = run
	if gate_scene == null:
		gate_scene = load("res://scenes/gameplay/Gate.tscn")
	for child in get_children():
		child.queue_free()
	active_gates.clear()
	spawn_index = 0
	current_row_id = 0
	recent_layouts.clear()
	var configured_seed: int = int(GameManager.current_run_context.get("run_seed", 0))
	var daily_seed: String = String(GameManager.current_run_context.get("daily_seed", ""))
	if configured_seed != 0:
		rng.seed = configured_seed
	elif not daily_seed.is_empty():
		rng.seed = hash(daily_seed)
	else:
		rng.randomize()
	next_spawn_distance = float(GameManager.gate_data.get("spawn_start_distance", 18.0))

func update_gates(delta: float) -> void:
	active_gates = active_gates.filter(func(gate): return is_instance_valid(gate))
	if not active_gates.is_empty():
		for gate in active_gates:
			gate.update_gate(delta)
	elif run_manager.distance_travelled >= next_spawn_distance:
		if not _gate_corridor_is_clear():
			next_spawn_distance = run_manager.distance_travelled + 8.0
			return
		_spawn_next_gate_row()
		var min_spacing: float = float(GameManager.gate_data.get("spawn_distance_min", 42.0))
		var max_spacing: float = max(min_spacing, float(GameManager.gate_data.get("spawn_distance_max", 62.0)))
		var lateral_speed: float = max(1.0, float(GameManager.game_config.get("squad_lateral_speed", 520.0)))
		var crossing_time: float = run_manager.road.get_usable_road_width(run_manager.road.get_squad_y()) / lateral_speed + 0.75
		var gameplay_forward_speed: float = run_manager.scroll_speed / 10.0
		var speed_spacing: float = gameplay_forward_speed * crossing_time
		var reaction_spacing: float = float(GameManager.gate_data.get("minimum_reaction_distance", min_spacing))
		var frequency: float = max(0.1, float(GameManager.gate_data.get("gate_row_frequency", 1.0)))
		var resolved_spacing: float = max(max(rng.randf_range(min_spacing, max_spacing), speed_spacing), reaction_spacing)
		resolved_spacing = max(min_spacing, resolved_spacing / frequency)
		next_spawn_distance += max(min_spacing, resolved_spacing * run_manager.get_route_gate_spawn_distance_multiplier())

func _gate_corridor_is_clear() -> bool:
	# Only exclusive route decisions postpone a gate row. Pickups, rescues, caches,
	# and ordinary obstacles are normal road traffic and may remain active long
	# enough to otherwise starve the gate scheduler for an entire run.
	if run_manager.pending_post_boss_choice:
		return false
	for enemy in run_manager.enemy_manager.enemies:
		if is_instance_valid(enemy) and String(enemy.get("enemy_id")) == "boss":
			return false
	return true

func spawn_gate(start_value: int) -> Node2D:
	return spawn_gate_row([{"type": "add_soldiers" if start_value >= 0 else "remove_soldiers", "value": abs(start_value) if start_value < 0 else start_value, "start_value": start_value}])[0]

func spawn_gate_row(gate_defs: Array) -> Array[Node2D]:
	if not active_gates.is_empty():
		return active_gates
	var spawn_y: float = float(GameManager.gate_data.get("spawn_y", run_manager.road.get_spawn_y()))
	var row_gate_defs: Array = gate_defs.duplicate(true)
	var gate_count: int = clampi(row_gate_defs.size(), 1, 3)
	if row_gate_defs.size() > gate_count:
		row_gate_defs.resize(gate_count)
	var positions: Array[float] = run_manager.road.get_gate_row_positions(spawn_y, gate_count)
	if gate_count == 2:
		var three_lanes: Array[float] = run_manager.road.get_gate_row_positions(spawn_y, 3)
		var omitted_lane: int = rng.randi_range(0, 2)
		positions = []
		for lane in 3:
			if lane != omitted_lane:
				positions.append(three_lanes[lane])
	active_gates.clear()
	current_row_id += 1
	for index in range(gate_count):
		var gate: Node2D = gate_scene.instantiate()
		add_child(gate)
		gate.initialize(run_manager, self, _normalize_gate_effect(row_gate_defs[index]), Vector2(positions[index], spawn_y), current_row_id)
		active_gates.append(gate)
	return active_gates

func unregister_gate(gate: Node) -> void:
	active_gates.erase(gate)

func get_target_gate(from_position: Vector2, max_range: float, aim_position: Vector2 = Vector2.ZERO) -> Node2D:
	var best_gate: Node2D
	var best_score := INF
	for gate in active_gates:
		if not is_instance_valid(gate):
			continue
		if from_position.distance_to(gate.global_position) > max_range:
			continue
		if aim_position != Vector2.ZERO and gate.global_position.distance_to(aim_position) > 120.0:
			continue
		var score: float = gate.global_position.distance_to(aim_position) if aim_position != Vector2.ZERO else from_position.distance_to(gate.global_position)
		if score < best_score:
			best_score = score
			best_gate = gate
	return best_gate

func find_gate_at_position(world_position: Vector2, hit_radius: float) -> Node2D:
	for gate in active_gates:
		if is_instance_valid(gate) and world_position.distance_to(gate.global_position) <= hit_radius:
			return gate
	return null

func consume_gate(gate: Node) -> Dictionary:
	if gate == null or not is_instance_valid(gate):
		return {}
	var row_id: int = int(gate.get("row_id"))
	var effect: Dictionary = gate.get_effect_definition()
	var result: Dictionary = apply_gate_effect(effect)
	run_manager.register_gate_chosen(effect)
	clear_gate_row(row_id)
	return result

func clear_gate_row(row_id: int = current_row_id) -> void:
	var gates_to_clear: Array[Node2D] = active_gates.duplicate()
	active_gates.clear()
	for gate in gates_to_clear:
		if not is_instance_valid(gate):
			continue
		if int(gate.get("row_id")) != row_id:
			active_gates.append(gate)
			continue
		gate.clear_without_collect()

func apply_gate_effect(effect: Dictionary) -> Dictionary:
	var normalized: Dictionary = _normalize_gate_effect(effect)
	var reward_type: String = String(normalized.get("type", "add_soldiers"))
	var result: Dictionary = run_manager.reward_manager.apply_reward_effect(reward_type, normalized)
	var popup: String = String(result.get("popup", format_gate_label(normalized)))
	return {
		"delta": int(result.get("delta", 0)),
		"popup": popup,
		"color": Color(result.get("color", normalized.get("color", _color_for_gate(normalized))))
	}

func format_gate_label(effect: Dictionary) -> String:
	var normalized: Dictionary = _normalize_gate_effect(effect)
	return _format_gate_label_normalized(normalized)

func _format_gate_label_normalized(normalized: Dictionary) -> String:
	var gate_type: String = String(normalized.get("type", "add_soldiers"))
	var value = normalized.get("value", 0)
	match gate_type:
		"add_soldiers":
			return "+%d SOLDIERS" % int(value)
		"remove_soldiers":
			return "-%d SOLDIERS" % int(value)
		"multiply_soldiers":
			return "x%d SQUAD" % int(value)
		"fire_rate_boost":
			return "+%d%% FIRE RATE" % int(round(float(value) * 100.0))
		"damage_boost":
			return "+%d%% DAMAGE" % int(round(float(value) * 100.0))
		"temporary_shield":
			return "+%d SHIELD" % int(round(float(value)))
		"weapon_pickup":
			return "WEAPON CRATE"
		"coins":
			return "+%d COINS" % int(value)
		"heal_soldiers":
			return "MEDICAL +%d" % int(value)
		"barricade_repair":
			return "+%d BARRICADE" % int(value)
		"barricade_cooldown_reset":
			return "BARRICADE READY"
		"risk_gate":
			return "RISK GATE"
	return String(normalized.get("label", "GATE")).to_upper()

func _spawn_next_gate_row() -> void:
	var rows: Array = GameManager.gate_data.get("rows", [])
	if rows.is_empty():
		_spawn_start_value_row()
		return
	var chosen_index: int = rng.randi_range(0, rows.size() - 1)
	var row_def: Dictionary = rows[chosen_index]
	for attempt in 4:
		var signature := JSON.stringify(row_def.get("gates", []))
		if not recent_layouts.has(signature) or rows.size() <= 2:
			break
		chosen_index = rng.randi_range(0, rows.size() - 1)
		row_def = rows[chosen_index]
	spawn_index += 1
	var gates: Array = row_def.get("gates", []).duplicate(true)
	if gates.is_empty():
		_spawn_start_value_row()
		return
	var allowed_count: int = clampi(rng.randi_range(1, int(GameManager.gate_data.get("max_gates_per_row", 3))), 1, mini(3, gates.size()))
	while gates.size() > allowed_count:
		gates.remove_at(rng.randi_range(0, gates.size() - 1))
	var signature := JSON.stringify(gates)
	recent_layouts.append(signature)
	if recent_layouts.size() > 2:
		recent_layouts.pop_front()
	spawn_gate_row(gates)

func _spawn_start_value_row() -> void:
	var values: Array = GameManager.gate_data.get("start_values", [])
	if values.is_empty():
		values = [-3]
	var gate_count: int = clampi(int(GameManager.gate_data.get("fallback_row_gate_count", 2)), 2, 3)
	var row: Array = []
	for index in range(gate_count):
		var start_value: int = int(values[spawn_index % values.size()])
		spawn_index += 1
		row.append({
			"type": "add_soldiers" if start_value >= 0 else "remove_soldiers",
			"value": abs(start_value),
			"start_value": start_value
		})
	spawn_gate_row(row)

func _normalize_gate_effect(effect: Dictionary) -> Dictionary:
	var normalized: Dictionary = effect.duplicate(true)
	var gate_type: String = String(normalized.get("type", ""))
	var has_start_value: bool = normalized.has("start_value")
	if gate_type == "":
		var start_value: int = int(normalized.get("value", normalized.get("start_value", 0)))
		normalized["start_value"] = start_value
		normalized["type"] = "add_soldiers" if start_value >= 0 else "remove_soldiers"
		normalized["value"] = abs(start_value)
	else:
		match gate_type:
			"add_soldiers", "remove_soldiers", "multiply_soldiers", "coins", "heal_soldiers", "barricade_repair", "barricade_cooldown_reset":
				normalized["value"] = int(normalized.get("value", 0))
			"fire_rate_boost", "damage_boost", "temporary_shield":
				normalized["value"] = float(normalized.get("value", 0.0))
			"weapon_pickup":
				normalized["value"] = int(normalized.get("value", 1))
			"risk_gate":
				normalized["value"] = int(normalized.get("reward_value", normalized.get("value", 1)))
	if not has_start_value:
		normalized["start_value"] = _compute_display_start_value(normalized)
	if not normalized.has("improvement_step"):
		normalized["improvement_step"] = _default_improvement_step(normalized)
	if not normalized.has("damage_per_value_step"):
		normalized["damage_per_value_step"] = get_damage_per_value_step(normalized)
	if not normalized.has("label"):
		normalized["label"] = _format_gate_label_normalized(normalized)
	if not normalized.has("color"):
		normalized["color"] = _color_for_gate(normalized)
	return normalized

func get_damage_per_value_step(effect: Dictionary) -> float:
	if effect.has("damage_per_value_step"):
		return max(0.01, float(effect.get("damage_per_value_step", 0.01)))
	var resolved: float = float(GameManager.gate_data.get("damage_per_value_step", 12.0))
	for entry in GameManager.gate_data.get("damage_per_value_step_by_distance", []):
		if float(run_manager.distance_travelled) >= float(entry.get("distance", 0.0)):
			resolved = float(entry.get("damage_per_value_step", resolved))
	return max(0.01, resolved)

func _compute_display_start_value(effect: Dictionary) -> int:
	match String(effect.get("type", "")):
		"add_soldiers":
			return int(effect.get("value", 0))
		"remove_soldiers":
			return -int(effect.get("value", 0))
	return 0

func _default_improvement_step(effect: Dictionary):
	match String(effect.get("type", "")):
		"add_soldiers", "remove_soldiers", "multiply_soldiers", "coins", "heal_soldiers":
			return 1
		"barricade_repair":
			return 10
		"fire_rate_boost", "damage_boost":
			return 0.1
		"temporary_shield":
			return 15.0
	return 0

func _color_for_gate(effect: Dictionary) -> String:
	match String(effect.get("type", "")):
		"add_soldiers", "fire_rate_boost", "damage_boost", "temporary_shield", "weapon_pickup", "coins", "multiply_soldiers", "heal_soldiers", "barricade_repair", "barricade_cooldown_reset":
			return "#64e291"
		"remove_soldiers":
			return "#ff8080"
		"risk_gate":
			return "#ff7d7d"
	return "#ffd166"
