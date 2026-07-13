extends Node
class_name WaveSpawner

var run_manager: Node
var spawn_timer := 0.0
var obstacle_timer := 0.0
var wave_spawned_count := 0
var current_wave_index := 0
var boss_milestones: Array = []
var boss_spawned: Dictionary = {}

func setup(run: Node) -> void:
	run_manager = run
	spawn_timer = 0.7
	obstacle_timer = 1.4
	current_wave_index = 0
	wave_spawned_count = 0
	boss_milestones = GameManager.game_config.get("boss_milestones", [])

func update_spawner(delta: float) -> void:
	spawn_timer -= delta
	obstacle_timer -= delta
	if obstacle_timer <= 0.0:
		obstacle_timer = float(GameManager.game_config.get("obstacle_spawn_interval", 3.4))
		var obstacle_type := _pick_road_object_type()
		var spawn_y: float = run_manager.road.get_spawn_y()
		var x: float = run_manager.road.get_random_lane_x(spawn_y, 72.0)
		run_manager.enemy_manager.spawn_obstacle(obstacle_type, Vector2(x, spawn_y))
	if spawn_timer <= 0.0:
		_spawn_enemy_from_wave()
	for milestone in boss_milestones:
		var milestone_value := int(milestone)
		if run_manager.distance_travelled >= milestone_value and not boss_spawned.get(milestone_value, false):
			boss_spawned[milestone_value] = true
			run_manager.ui_manager.show_status_message("BOSS INCOMING", Color("ff7d7d"))
			run_manager.enemy_manager.spawn_enemy("boss", Vector2(run_manager.road.get_center_x(), run_manager.road.get_spawn_y() - 20.0), run_manager.get_difficulty_multiplier())

func _spawn_enemy_from_wave() -> void:
	var waves: Array = GameManager.wave_data.get("waves", [])
	if waves.is_empty():
		return
	var wave_data: Dictionary = waves[min(current_wave_index, waves.size() - 1)]
	run_manager.set_wave(int(wave_data.get("wave", 1)) + max(current_wave_index - waves.size() + 1, 0))
	var pool: Array = wave_data.get("pool", [])
	var spawn_count: int = int(wave_data.get("spawn_count", 6)) + max(0, current_wave_index - waves.size() + 1) * 2
	if wave_spawned_count >= spawn_count:
		current_wave_index += 1
		wave_spawned_count = 0
		wave_data = waves[min(current_wave_index, waves.size() - 1)]
		pool = wave_data.get("pool", [])
		run_manager.set_wave(int(wave_data.get("wave", 1)) + max(current_wave_index - waves.size() + 1, 0))
	var enemy_id := pick_enemy_from_pool(pool)
	var x: float = run_manager.road.get_random_lane_x(run_manager.road.get_spawn_y(), 64.0)
	var modifier: float = run_manager.get_difficulty_multiplier()
	run_manager.enemy_manager.spawn_enemy(enemy_id, Vector2(x, run_manager.road.get_spawn_y()), modifier)
	wave_spawned_count += 1
	var base_interval := float(GameManager.game_config.get("base_enemy_spawn_interval", 1.8))
	var pressure_interval_multiplier: float = run_manager.get_pressure_spawn_interval_multiplier() if run_manager != null else 1.0
	spawn_timer = max(0.35, base_interval * pressure_interval_multiplier / modifier)

func trigger_alarm_wave(config: Dictionary, world_position: Vector2 = Vector2.ZERO) -> void:
	var spawn_count: int = int(config.get("alarm_spawn_count", 3))
	var spawn_pool: Array = config.get("alarm_spawn_pool", ["runner", "walker", "exploder"])
	for index in range(spawn_count):
		var enemy_id: String = String(spawn_pool[index % max(1, spawn_pool.size())])
		var offset_x: float = randf_range(-110.0, 110.0)
		var spawn_y: float = min(world_position.y - 180.0, run_manager.road.get_spawn_y())
		var spawn_x: float = run_manager.road.clamp_lane_x(world_position.x + offset_x, 220.0, 64.0)
		run_manager.enemy_manager.spawn_enemy(enemy_id, Vector2(spawn_x, spawn_y), run_manager.get_difficulty_multiplier())

func pick_enemy_from_pool(pool: Array) -> String:
	if pool.is_empty():
		return "walker"
	var weighted_pool: Dictionary = get_spawn_weight_snapshot(pool)
	var total_weight := 0.0
	for weight in weighted_pool.values():
		total_weight += float(weight)
	var roll: float = randf() * max(total_weight, 0.01)
	for enemy_id in weighted_pool.keys():
		roll -= float(weighted_pool[enemy_id])
		if roll <= 0.0:
			return String(enemy_id)
	return String(weighted_pool.keys().back())

func get_spawn_weight_snapshot(pool: Array) -> Dictionary:
	var weights: Dictionary = {}
	for enemy in pool:
		var enemy_id: String = String(enemy)
		weights[enemy_id] = float(weights.get(enemy_id, 0.0)) + 1.0
	if run_manager == null or run_manager.mutation_manager == null:
		return weights
	if run_manager != null:
		var runner_multiplier: float = run_manager.get_pressure_runner_weight_multiplier()
		if weights.has("runner"):
			weights["runner"] = float(weights["runner"]) * runner_multiplier
		if weights.has("dog"):
			weights["dog"] = float(weights["dog"]) * runner_multiplier
	for enemy_id in weights.keys():
		weights[enemy_id] = float(weights[enemy_id]) * run_manager.mutation_manager.get_spawn_weight_multiplier(String(enemy_id))
	return weights

func _pick_road_object_type() -> String:
	var spawn_entries: Array = GameManager.game_config.get("road_objects", {}).get("spawn_pool", [])
	if spawn_entries.is_empty():
		return "barrel" if randf() < 0.5 else "crate"
	var total_weight := 0.0
	for entry in spawn_entries:
		total_weight += max(0.01, float(entry.get("weight", 1.0)))
	var roll := randf() * total_weight
	for entry in spawn_entries:
		roll -= max(0.01, float(entry.get("weight", 1.0)))
		if roll <= 0.0:
			return String(entry.get("type", "barrel"))
	return String(spawn_entries.back().get("type", "barrel"))
