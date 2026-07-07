extends Node2D
class_name Projectile

var run_manager: Node
var velocity := Vector2.ZERO
var weapon_data: Dictionary = {}
var alive_time := 0.0
var max_time := 2.0
var splash_radius := 0.0
var pierce_count := 0
var hits_done := 0

func initialize(run: Node, origin: Vector2, target_position: Vector2, weapon: Dictionary, spread_angle: float) -> void:
	run_manager = run
	global_position = origin
	weapon_data = weapon
	splash_radius = float(weapon.get("splash_radius", 0))
	pierce_count = int(weapon.get("pierce_count", 0))
	var direction: Vector2 = (target_position - origin).normalized().rotated(spread_angle)
	velocity = direction * float(weapon.get("projectile_speed", 400))
	run_manager.ui_manager.spawn_bullet_trail(origin, origin + direction * 26.0, Color("ffcc7a"))

func _process(delta: float) -> void:
	alive_time += delta
	position += velocity * delta
	queue_redraw()
	var enemies: Array = run_manager.enemy_manager.enemies.duplicate()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= 16.0:
			_hit_enemy(enemy)
			if hits_done > pierce_count:
				queue_free()
				return
	var obstacles: Array = run_manager.enemy_manager.obstacles.duplicate()
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			continue
		if global_position.distance_to(obstacle.global_position) <= 18.0:
			obstacle.take_damage(run_manager.weapon_manager.get_damage_for_projectile(weapon_data))
			queue_free()
			return
	var gate: Node2D = run_manager.gate_manager.find_gate_at_position(global_position, 30.0)
	if gate != null and is_instance_valid(gate):
		gate.take_damage(run_manager.weapon_manager.get_damage_for_projectile(weapon_data), false)
		queue_free()
		return
	if alive_time >= max_time or position.y < -80 or position.y > 1400:
		queue_free()

func _hit_enemy(enemy: Node) -> void:
	hits_done += 1
	var damage: float = run_manager.weapon_manager.get_damage_for_projectile(weapon_data)
	enemy.take_damage(damage, splash_radius > 0.0)
	if splash_radius > 0.0:
		for nearby in run_manager.enemy_manager.enemies:
			if nearby == enemy or not is_instance_valid(nearby):
				continue
			if nearby.global_position.distance_to(enemy.global_position) <= splash_radius:
				nearby.take_damage(damage * 0.5, false)
		run_manager.ui_manager.spawn_explosion(enemy.global_position, splash_radius)
		AudioManager.play_sfx("explosion")

func _draw() -> void:
	var splash := float(weapon_data.get("splash_radius", 0.0))
	var speed := float(weapon_data.get("projectile_speed", 400.0))
	var radius: float = 4.0 + float(min(4.0, splash * 0.04))
	var color: Color = Color("ffd966")
	if splash > 0.0:
		color = Color("ff9655")
	elif speed > 600.0:
		color = Color("90f4ff")
	draw_circle(Vector2.ZERO, radius, color)
