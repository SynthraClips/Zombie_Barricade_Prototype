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
var hit_targets: Array[int] = []
var previous_position := Vector2.ZERO

func initialize(run: Node, origin: Vector2, target_position: Vector2, weapon: Dictionary, spread_angle: float) -> void:
	run_manager = run
	global_position = origin
	previous_position = origin
	weapon_data = weapon
	splash_radius = float(weapon.get("splash_radius", 0))
	pierce_count = int(weapon.get("pierce_count", 0))
	hit_targets.clear()
	var direction: Vector2 = (target_position - origin).normalized().rotated(spread_angle)
	velocity = direction * float(weapon.get("projectile_speed", 400))
	run_manager.ui_manager.spawn_bullet_trail(origin, origin + direction * 26.0, Color("ffcc7a"))

func _process(delta: float) -> void:
	alive_time += delta
	previous_position = global_position
	position += velocity * delta
	queue_redraw()
	var enemies: Array = run_manager.enemy_manager.enemies.duplicate()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if hit_targets.has(enemy.get_instance_id()):
			continue
		if _distance_to_segment(enemy.global_position) <= 24.0:
			_hit_enemy(enemy)
			if hits_done > pierce_count:
				queue_free()
				return
	var obstacles: Array = run_manager.enemy_manager.obstacles.duplicate()
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			continue
		var obstacle_hit_radius: float = 18.0
		if obstacle.has_method("get_projectile_hit_radius"):
			obstacle_hit_radius = float(obstacle.call("get_projectile_hit_radius"))
		if _distance_to_segment(obstacle.global_position) <= obstacle_hit_radius:
			obstacle.take_damage(run_manager.weapon_manager.get_damage_for_target(weapon_data, obstacle))
			queue_free()
			return
	var cache_hit_radius: float = 26.0
	var nearest_cache: Node2D = run_manager.armoury_cache_manager.get_target_cache(global_position, 64.0, global_position, true)
	if nearest_cache != null and nearest_cache.has_method("get_projectile_hit_radius"):
		cache_hit_radius = float(nearest_cache.call("get_projectile_hit_radius"))
	var cache: Node2D = run_manager.armoury_cache_manager.find_cache_at_position(global_position, cache_hit_radius)
	if cache != null and is_instance_valid(cache) and _distance_to_segment(cache.global_position) <= cache_hit_radius:
		cache.take_damage(run_manager.weapon_manager.get_damage_for_target(weapon_data, cache), splash_radius > 0.0)
		queue_free()
		return
	var gate: Node2D = run_manager.gate_manager.find_gate_at_position(global_position, 30.0)
	if gate != null and is_instance_valid(gate) and _distance_to_segment(gate.global_position) <= 30.0:
		gate.take_damage(run_manager.weapon_manager.get_damage_for_target(weapon_data, gate), false)
		queue_free()
		return
	var rescue_hit_radius: float = 30.0
	var nearest_rescue: Node2D = run_manager.survivor_rescue_manager.get_target_rescue(global_position, 64.0, global_position, true)
	if nearest_rescue != null and nearest_rescue.has_method("get_projectile_hit_radius"):
		rescue_hit_radius = float(nearest_rescue.call("get_projectile_hit_radius"))
	var rescue: Node2D = run_manager.survivor_rescue_manager.find_rescue_at_position(global_position, rescue_hit_radius)
	if rescue != null and is_instance_valid(rescue) and _distance_to_segment(rescue.global_position) <= rescue_hit_radius:
		rescue.take_damage(run_manager.weapon_manager.get_damage_for_target(weapon_data, rescue), splash_radius > 0.0)
		queue_free()
		return
	if alive_time >= max_time or position.y < -80 or position.y > 1400:
		queue_free()

func _hit_enemy(enemy: Node) -> void:
	hits_done += 1
	hit_targets.append(enemy.get_instance_id())
	var damage: float = run_manager.weapon_manager.get_damage_for_target(weapon_data, enemy)
	enemy.take_damage(damage, splash_radius > 0.0)
	run_manager.weapon_manager._apply_post_hit_effects(weapon_data, enemy, damage)

func _draw() -> void:
	var splash := float(weapon_data.get("splash_radius", 0.0))
	var speed := float(weapon_data.get("projectile_speed", 400.0))
	var style := String(weapon_data.get("vfx_placeholder", "trail"))
	var radius: float = 4.0 + float(min(4.0, splash * 0.04))
	var color: Color = Color("ffd966")
	if splash > 0.0:
		color = Color("ff9655")
	elif String(weapon_data.get("special_ammo_type", "")) == "incendiary":
		color = Color("ff7b5a")
	elif String(weapon_data.get("special_ammo_type", "")) == "heavy":
		color = Color("d8d2c4")
	elif speed > 600.0:
		color = Color("90f4ff")
	var direction := velocity.normalized()
	match style:
		"rocket":
			draw_line(-direction * 18.0, -direction * 5.0, Color("ff7b42", 0.75), 7.0)
			draw_circle(Vector2.ZERO, radius + 3.0, color)
		"flame":
			draw_circle(Vector2.ZERO, radius + 2.0, Color("ff7b42", 0.8))
			draw_circle(-direction * 7.0, radius, Color("ffd166", 0.55))
		"stream":
			draw_line(-direction * 10.0, direction * 4.0, color, 3.0)
		"burst":
			draw_circle(Vector2.ZERO, radius, color)
			draw_line(-direction * 6.0, direction * 3.0, Color(color, 0.65), 2.0)
		_:
			draw_line(-direction * 8.0, direction * 3.0, color, 3.0)

func _distance_to_segment(target_position: Vector2) -> float:
	var segment: Vector2 = global_position - previous_position
	if segment.length_squared() <= 0.001:
		return global_position.distance_to(target_position)
	var t: float = clampf((target_position - previous_position).dot(segment) / segment.length_squared(), 0.0, 1.0)
	var closest: Vector2 = previous_position + segment * t
	return closest.distance_to(target_position)
