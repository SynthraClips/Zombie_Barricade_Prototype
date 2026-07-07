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
		var obstacle_type := "barrel" if randf() < 0.5 else "crate"
		var spawn_y: float = run_manager.road.get_spawn_y()
		var x: float = run_manager.road.clamp_lane_x(randf_range(180.0, 540.0), 240.0, 72.0)
		run_manager.enemy_manager.spawn_obstacle(obstacle_type, Vector2(x, spawn_y))
	if spawn_timer <= 0.0:
		_spawn_enemy_from_wave()
	for milestone in boss_milestones:
		var milestone_value := int(milestone)
		if run_manager.distance_travelled >= milestone_value and not boss_spawned.get(milestone_value, false):
			boss_spawned[milestone_value] = true
			run_manager.ui_manager.show_status_message("BOSS INCOMING", Color("ff7d7d"))
			run_manager.enemy_manager.spawn_enemy("boss", Vector2(360, run_manager.road.get_spawn_y() - 20.0), run_manager.get_difficulty_multiplier())

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
	var enemy_id := String(pool[randi() % max(pool.size(), 1)])
	var x: float = run_manager.road.clamp_lane_x(randf_range(180.0, 540.0), 220.0, 64.0)
	var modifier: float = run_manager.get_difficulty_multiplier()
	run_manager.enemy_manager.spawn_enemy(enemy_id, Vector2(x, run_manager.road.get_spawn_y()), modifier)
	wave_spawned_count += 1
	var base_interval := float(GameManager.game_config.get("base_enemy_spawn_interval", 1.8))
	spawn_timer = max(0.4, base_interval / modifier)
