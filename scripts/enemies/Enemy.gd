extends Node2D
class_name Enemy

var run_manager: Node
var enemy_id := "walker"
var definition: Dictionary = {}
var hp := 10.0
var max_hp := 10.0
var move_speed := 40.0
var damage := 5.0
var attack_range := 28.0
var reward_value := 3
var special_behavior := "none"
var attack_cooldown := 0.0
var spit_cooldown := 0.0
var hit_flash := 0.0
var slow_amount := 0.0
var slow_time := 0.0
var boss_phase_triggered := false
var death_fade := 0.0

func initialize(run: Node, enemy_type: String, spawn_position: Vector2, modifier: float) -> void:
	run_manager = run
	enemy_id = enemy_type
	definition = GameManager.enemy_data.get(enemy_type, {})
	global_position = spawn_position
	max_hp = float(definition.get("hp", 20)) * modifier
	hp = max_hp
	move_speed = float(definition.get("speed", 40))
	damage = float(definition.get("damage", 5)) * lerp(1.0, modifier, 0.4)
	attack_range = float(definition.get("attack_range", 30))
	reward_value = int(definition.get("reward_value", 4))
	special_behavior = String(definition.get("special_behavior", "none"))
	scale = Vector2.ONE * (1.0 if enemy_type != "boss" else 1.6)
	death_fade = 0.0

func update_enemy(delta: float) -> void:
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	spit_cooldown = max(spit_cooldown - delta, 0.0)
	slow_time = max(slow_time - delta, 0.0)
	if slow_time <= 0.0:
		slow_amount = 0.0
	hit_flash = max(hit_flash - delta * 4.0, 0.0)
	_handle_boss_phase()
	queue_redraw()
	if _handle_spitter(delta):
		return
	var target_y: float = run_manager.squad_manager.get_anchor_position().y
	var barricade: Node = run_manager.barricade_manager.active_barricade
	if barricade != null and is_instance_valid(barricade):
		target_y = barricade.global_position.y
	if global_position.y < target_y:
		var move_vector: Vector2 = Vector2(0, 1) * (run_manager.scroll_speed + _get_effective_move_speed()) * delta
		position += move_vector
	if barricade != null and is_instance_valid(barricade) and global_position.distance_to(barricade.global_position) <= attack_range + 24.0:
		_attack_barricade_or_explode()
	elif global_position.y >= run_manager.squad_manager.get_anchor_position().y - 90.0:
		_attack_squad_or_explode()
	if global_position.y > 1360:
		queue_free()

func _handle_spitter(delta: float) -> bool:
	if special_behavior != "spitter":
		return false
	position += Vector2.DOWN * (run_manager.scroll_speed + _get_effective_move_speed() * 0.4) * delta
	var distance: float = global_position.distance_to(run_manager.squad_manager.get_anchor_position())
	if distance <= attack_range and spit_cooldown <= 0.0:
		spit_cooldown = 1.3
		run_manager.squad_manager.receive_attack(damage)
		run_manager.ui_manager.spawn_bullet_trail(global_position, run_manager.squad_manager.get_anchor_position(), Color("7bf26e"))
		return true
	return false

func _attack_barricade_or_explode() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.8
	if special_behavior == "exploder":
		run_manager.barricade_manager.damage_active_barricade(damage * 1.5)
		run_manager.ui_manager.spawn_explosion(global_position, 34.0)
		AudioManager.play_sfx("explosion")
		queue_free()
	else:
		run_manager.barricade_manager.damage_active_barricade(damage)

func _attack_squad_or_explode() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.9
	if special_behavior == "exploder":
		run_manager.squad_manager.receive_attack(damage * 1.6)
		run_manager.ui_manager.spawn_explosion(global_position, 40.0)
		AudioManager.play_sfx("explosion")
		queue_free()
	else:
		run_manager.squad_manager.receive_attack(damage)

func take_damage(amount: float, explosive_hit: bool) -> void:
	hp -= amount
	hit_flash = 1.0
	run_manager.ui_manager.spawn_damage_number(global_position, amount)
	AudioManager.play_sfx("zombie_hit")
	if hp <= 0.0:
		die()

func die() -> void:
	run_manager.register_kill(enemy_id)
	run_manager.add_coins(reward_value)
	run_manager.ui_manager.spawn_reward_popup(global_position, "+%d coins" % reward_value, Color("f5d142"))
	if enemy_id == "boss":
		run_manager.ui_manager.show_status_message("BOSS DEFEATED", Color("ffd166"))
		run_manager.reward_manager.spawn_reward("boss_relic", global_position + Vector2(0, -24))
	AudioManager.play_sfx("zombie_death")
	run_manager.ui_manager.spawn_explosion(global_position, 24.0 if enemy_id != "boss" else 42.0)
	queue_free()

func _draw() -> void:
	var color: Color = Color(definition.get("color", "#79a35d"))
	if hit_flash > 0.0:
		color = color.lerp(Color.WHITE, hit_flash)
	var body_width := 28.0
	var body_height := 36.0
	match special_behavior:
		"runner":
			body_width = 24.0
			body_height = 32.0
		"tank":
			body_width = 38.0
			body_height = 44.0
		"exploder":
			body_width = 26.0
			body_height = 34.0
		"boss":
			body_width = 44.0
			body_height = 54.0
	draw_rect(Rect2(-body_width * 0.5, -body_height * 0.5, body_width, body_height), color)
	draw_rect(Rect2(-body_width * 0.35, -body_height * 0.5 - 10, body_width * 0.7, 12), color.darkened(0.1))
	if special_behavior == "exploder":
		draw_circle(Vector2(0, -8), 8.0 + sin(Time.get_ticks_msec() / 110.0) * 2.0, Color("ffcf61", 0.9))
	if special_behavior == "spitter":
		draw_circle(Vector2(0, -6), 7.0, Color("88ff88"))
	if special_behavior == "boss":
		draw_rect(Rect2(-24, 12, 48, 8), Color("5a1d1d"))
	draw_rect(Rect2(-18, -body_height * 0.5 - 16, 36, 6), Color("20242a"))
	draw_rect(Rect2(-18, -body_height * 0.5 - 16, 36 * (hp / max(max_hp, 1.0)), 6), Color("ff6262"))
	draw_string(ThemeDB.fallback_font, Vector2(-24, body_height * 0.5 + 18), String(definition.get("name", enemy_id)).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 64, 12, Color.WHITE)

func apply_slow(amount: float, duration: float) -> void:
	slow_amount = max(slow_amount, amount)
	slow_time = max(slow_time, duration)

func _get_effective_move_speed() -> float:
	return move_speed * (1.0 - slow_amount)

func _handle_boss_phase() -> void:
	if special_behavior != "boss" or boss_phase_triggered or hp > max_hp * 0.5:
		return
	boss_phase_triggered = true
	move_speed *= 1.3
	damage *= 1.2
	run_manager.ui_manager.show_status_message("BOSS ENRAGED", Color("ff6b6b"))
	for offset in [-90.0, 0.0, 90.0]:
		var spawn_x: float = run_manager.road.clamp_lane_x(360.0 + offset, 220.0, 64.0)
		run_manager.enemy_manager.spawn_enemy("runner", Vector2(spawn_x, run_manager.road.get_spawn_y() - 40.0), run_manager.get_difficulty_multiplier())
