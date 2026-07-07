extends Node2D
class_name EnemyManager

@export var enemy_scene: PackedScene
@export var obstacle_scene: PackedScene

var run_manager: Node
var enemies: Array[Node] = []
var obstacles: Array[Node] = []

func setup(run: Node) -> void:
	run_manager = run
	if enemy_scene == null:
		enemy_scene = load("res://scenes/gameplay/Enemy.tscn")
	if obstacle_scene == null:
		obstacle_scene = load("res://scenes/gameplay/Obstacle.tscn")
	for child in get_children():
		child.queue_free()
	enemies.clear()
	obstacles.clear()

func update_enemies(delta: float) -> void:
	enemies = enemies.filter(func(enemy): return is_instance_valid(enemy))
	obstacles = obstacles.filter(func(obstacle): return is_instance_valid(obstacle))
	for enemy in enemies:
		enemy.update_enemy(delta)
	for obstacle in obstacles:
		obstacle.update_obstacle(delta)

func spawn_enemy(enemy_id: String, spawn_position: Vector2, modifier: float = 1.0) -> Node:
	var enemy: Node = enemy_scene.instantiate()
	add_child(enemy)
	enemy.initialize(run_manager, enemy_id, spawn_position, modifier)
	enemies.append(enemy)
	return enemy

func spawn_obstacle(obstacle_type: String, spawn_position: Vector2) -> Node:
	var obstacle: Node = obstacle_scene.instantiate()
	add_child(obstacle)
	obstacle.initialize(run_manager, obstacle_type, spawn_position)
	obstacles.append(obstacle)
	return obstacle

func get_nearest_enemy(from_position: Vector2, max_range: float) -> Node2D:
	var best: Node2D
	var best_distance: float = max_range
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance: float = from_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

func get_enemies_sorted_from(from_position: Vector2, max_range: float) -> Array:
	var result: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if from_position.distance_to(enemy.global_position) <= max_range:
			result.append(enemy)
	result.sort_custom(func(a, b): return from_position.distance_to(a.global_position) < from_position.distance_to(b.global_position))
	return result

func get_nearest_obstacle(from_position: Vector2, max_range: float) -> Node2D:
	var best: Node2D
	var best_distance: float = max_range
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			continue
		var distance: float = from_position.distance_to(obstacle.global_position)
		if distance < best_distance:
			best_distance = distance
			best = obstacle
	return best
