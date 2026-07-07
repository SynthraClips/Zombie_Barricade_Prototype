extends Node2D
class_name SquadManager

@export var soldier_scene: PackedScene

const COLLECTOR_LAYER := 1 << 4
const PICKUP_LAYER := 1 << 5

var run_manager: Node
var soldiers: Array[Node] = []
var base_soldier_hp := 18.0
var squad_shield_hp := 0.0
var temporary_damage_bonus := 0.0
var temporary_fire_rate_bonus := 0.0
var damage_boost_time := 0.0
var fire_rate_boost_time := 0.0
var formation_center_x := 360.0
var formation_target_x := 360.0
var formation_y := 1110.0
var movement_smoothing := 9.0
var touch_input_active := false
var support_role_id := "rifleman"
var collector_area: Area2D
var collector_shape: CollisionShape2D

func setup(run: Node) -> void:
	run_manager = run
	if soldier_scene == null:
		soldier_scene = load("res://scenes/gameplay/Soldier.tscn")
	for child in get_children():
		child.queue_free()
	soldiers.clear()
	_ensure_collector_area()
	formation_y = run_manager.road.get_squad_y()
	formation_center_x = run_manager.road.clamp_lane_x(360.0, formation_y)
	formation_target_x = formation_center_x
	support_role_id = GameManager.get_support_role_id()
	var starting: int = min(run_manager.max_squad_size, GameManager.get_starting_soldier_count())
	for i in starting:
		var role_id := support_role_id if i == 0 else "rifleman"
		add_soldier(role_id)
	_apply_formation(true)

func update_squad(delta: float) -> void:
	if damage_boost_time > 0.0:
		damage_boost_time -= delta
		if damage_boost_time <= 0.0:
			temporary_damage_bonus = 0.0
	if fire_rate_boost_time > 0.0:
		fire_rate_boost_time -= delta
		if fire_rate_boost_time <= 0.0:
			temporary_fire_rate_bonus = 0.0
	formation_y = run_manager.road.get_squad_y()
	formation_target_x = run_manager.road.clamp_lane_x(formation_target_x, formation_y)
	formation_center_x = lerpf(formation_center_x, formation_target_x, clampf(delta * movement_smoothing, 0.0, 1.0))
	_apply_formation()
	_apply_role_support(delta)
	for soldier in soldiers:
		soldier.update_soldier(delta)

func add_soldier(role_id: String = "rifleman") -> bool:
	if soldiers.size() >= run_manager.max_squad_size:
		return false
	var soldier: Node = soldier_scene.instantiate()
	add_child(soldier)
	soldier.initialize(self, role_id)
	soldiers.append(soldier)
	_apply_formation(true)
	run_manager.on_squad_count_changed()
	return true

func add_soldiers(amount: int) -> int:
	var added := 0
	for index in amount:
		if add_soldier():
			added += 1
	if added > 0:
		SaveManager.save_data["stats"]["soldiers_rescued"] += added
		MissionManager.increment_progress("soldiers_rescued", added)
	return added

func remove_soldiers(amount: int) -> int:
	var removed := _remove_soldiers_internal(amount, false)
	if removed > 0:
		run_manager.add_screen_shake(0.08, 4.0)
		run_manager.ui_manager.flash_hit()
	return removed

func multiply_soldiers(multiplier: int) -> int:
	var desired_count: int = clampi(soldiers.size() * multiplier, 1, run_manager.max_squad_size)
	return add_soldiers(max(0, desired_count - soldiers.size()))

func handle_pointer_input(screen_position: Vector2, is_touch: bool = false) -> void:
	touch_input_active = is_touch
	formation_target_x = run_manager.road.screen_x_to_lane_x(screen_position.x, formation_y)

func release_touch_input() -> void:
	touch_input_active = false

func get_collector_area() -> Area2D:
	return collector_area

func get_role_definition(role_id: String) -> Dictionary:
	return GameManager.game_config.get("soldier_roles", {}).get(role_id, GameManager.game_config.get("soldier_roles", {}).get("rifleman", {}))

func _apply_formation(snap: bool = false) -> void:
	var width: float = min(220.0, 120.0 + float(max(soldiers.size() - 1, 0)) * 26.0)
	var count: int = soldiers.size()
	for i in count:
		var soldier: Node = soldiers[i]
		var t: float = 0.0 if count == 1 else float(i) / float(count - 1)
		var target_position := Vector2(formation_center_x + lerpf(-width * 0.5, width * 0.5, t), formation_y + 24.0 * sin(t * PI))
		if snap:
			soldier.position = target_position
		else:
			soldier.position = soldier.position.lerp(target_position, 0.22)
	if collector_area != null:
		collector_area.position = Vector2(formation_center_x, formation_y - 10.0)
	if collector_shape != null:
		var shape: RectangleShape2D = collector_shape.shape
		shape.size = Vector2(max(92.0, width + 70.0), 86.0)

func _ensure_collector_area() -> void:
	collector_area = Area2D.new()
	collector_area.name = "SquadCollector"
	collector_area.collision_layer = COLLECTOR_LAYER
	collector_area.collision_mask = PICKUP_LAYER
	collector_area.monitoring = true
	collector_area.monitorable = true
	add_child(collector_area)
	collector_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(150.0, 86.0)
	collector_shape.shape = shape
	collector_area.add_child(collector_shape)

func _remove_soldiers_internal(amount: int, allow_zero: bool) -> int:
	var minimum_count: int = 0 if allow_zero else 1
	var removable: int = max(0, soldiers.size() - minimum_count)
	var removed := 0
	for index in min(amount, removable):
		if soldiers.size() <= minimum_count:
			break
		var soldier: Node = soldiers.pop_back()
		soldier.queue_free()
		removed += 1
	if removed > 0:
		_apply_formation(true)
		run_manager.on_squad_count_changed()
	return removed

func get_soldier_count() -> int:
	return soldiers.size()

func get_anchor_position() -> Vector2:
	if soldiers.is_empty():
		return Vector2(formation_center_x, formation_y)
	var total: Vector2 = Vector2.ZERO
	for soldier in soldiers:
		total += soldier.global_position
	return total / soldiers.size()

func get_primary_target_for(soldier_position: Vector2, weapon_range: float) -> Node2D:
	if not run_manager.should_fire():
		return null
	var aim_position: Vector2 = run_manager.get_aim_position()
	var auto_fire_enabled: bool = run_manager.is_auto_fire_enabled()
	var best_target: Node2D
	var best_score := INF
	for enemy in run_manager.enemy_manager.enemies:
		if not is_instance_valid(enemy):
			continue
		if not auto_fire_enabled and soldier_position.distance_to(enemy.global_position) > weapon_range:
			continue
		var score: float = soldier_position.distance_to(enemy.global_position) if auto_fire_enabled else enemy.global_position.distance_to(aim_position)
		if score < best_score:
			best_score = score
			best_target = enemy
	var gate: Node2D = run_manager.gate_manager.get_target_gate(soldier_position, INF if auto_fire_enabled else weapon_range, Vector2.ZERO if auto_fire_enabled else aim_position)
	if gate != null:
		var gate_score: float = soldier_position.distance_to(gate.global_position) if auto_fire_enabled else gate.global_position.distance_to(aim_position)
		if gate_score < best_score:
			best_score = gate_score
			best_target = gate
	for obstacle in run_manager.enemy_manager.obstacles:
		if not is_instance_valid(obstacle):
			continue
		if not auto_fire_enabled and soldier_position.distance_to(obstacle.global_position) > weapon_range:
			continue
		var obstacle_score: float = soldier_position.distance_to(obstacle.global_position) if auto_fire_enabled else obstacle.global_position.distance_to(aim_position)
		if obstacle_score < best_score:
			best_score = obstacle_score
			best_target = obstacle
	if best_target != null and (auto_fire_enabled or best_score <= 110.0):
		return best_target
	return null

func get_damage_multiplier() -> float:
	return 1.0 + UpgradeManager.get_upgrade_value("soldier_damage") + temporary_damage_bonus

func get_fire_rate_multiplier() -> float:
	return 1.0 + UpgradeManager.get_upgrade_value("fire_rate") + temporary_fire_rate_bonus

func get_role_counts() -> Dictionary:
	var counts: Dictionary = {}
	for soldier in soldiers:
		var role_id: String = String(soldier.get("role_id"))
		counts[role_id] = int(counts.get(role_id, 0)) + 1
	return counts

func receive_attack(amount: float) -> void:
	var remaining: float = amount
	if squad_shield_hp > 0.0:
		var blocked: float = min(squad_shield_hp, remaining)
		squad_shield_hp -= blocked
		remaining -= blocked
	if remaining <= 0.0:
		return
	var soldiers_to_remove: int = int(ceil(remaining / base_soldier_hp))
	var removed: int = _remove_soldiers_internal(soldiers_to_remove, true)
	if removed > 0:
		run_manager.add_screen_shake(0.15, 6.0)
		run_manager.ui_manager.flash_hit()
	if soldiers.is_empty():
		run_manager.finish_run(false)

func apply_reward_boost(reward_type: String, value: float) -> void:
	match reward_type:
		"fire_rate_boost":
			temporary_fire_rate_bonus += value
			fire_rate_boost_time = float(GameManager.game_config.get("temporary_boost_duration", 8.0))
		"damage_boost":
			temporary_damage_bonus += value
			damage_boost_time = float(GameManager.game_config.get("temporary_boost_duration", 8.0))
		"temporary_shield":
			squad_shield_hp += value
	print("Reward applied: %s value=%s squad=%d damage_bonus=%.2f fire_rate_bonus=%.2f shield=%.2f" % [reward_type, value, get_soldier_count(), temporary_damage_bonus, temporary_fire_rate_bonus, squad_shield_hp])

func heal_soldiers(amount: int) -> int:
	return add_soldiers(amount)

func _apply_role_support(delta: float) -> void:
	var counts: Dictionary = get_role_counts()
	var engineer_count: int = int(counts.get("engineer", 0))
	if engineer_count <= 0:
		return
	var barricade: Node = run_manager.barricade_manager.active_barricade
	if barricade == null or not is_instance_valid(barricade):
		return
	var base_repair: float = float(get_role_definition("engineer").get("barricade_repair_per_second", 0.0))
	if base_repair <= 0.0:
		return
	barricade.repair((base_repair + UpgradeManager.get_upgrade_value("barricade_auto_repair")) * engineer_count * delta, true)
