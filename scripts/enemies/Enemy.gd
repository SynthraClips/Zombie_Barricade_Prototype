extends Node2D
class_name Enemy

@onready var goblin_sprite: Sprite2D = $GoblinSprite

var run_manager: Node
var enemy_id := "walker"
var definition: Dictionary = {}
var hp := 10.0
var max_hp := 10.0
var base_max_hp := 10.0
var move_speed := 40.0
var base_move_speed := 40.0
var damage := 5.0
var base_damage := 5.0
var attack_range := 28.0
var base_attack_range := 28.0
var reward_value := 3
var base_reward_value := 3
var special_behavior := "none"
var attack_cooldown := 0.0
var spit_cooldown := 0.0
var hit_flash := 0.0
var slow_amount := 0.0
var slow_time := 0.0
var boss_phase_triggered := false
var death_fade := 0.0
var burn_damage_per_second := 0.0
var burn_time := 0.0
var burn_tick_time := 0.0
var mutation_stat_modifiers: Dictionary = {}
var phase_speed_multiplier := 1.0
var phase_damage_multiplier := 1.0
var special_trigger_used := false
var charge_time := 0.0
var visual_animation_time := 0.0

func initialize(run: Node, enemy_type: String, spawn_position: Vector2, modifier: float, mutation_modifiers: Dictionary = {}) -> void:
	run_manager = run
	enemy_id = enemy_type
	definition = GameManager.enemy_data.get(enemy_type, {})
	global_position = spawn_position
	base_max_hp = float(definition.get("hp", 20)) * modifier
	base_move_speed = float(definition.get("speed", 40))
	base_damage = float(definition.get("damage", 5)) * lerp(1.0, modifier, 0.4)
	base_attack_range = float(definition.get("attack_range", 30))
	base_reward_value = int(definition.get("reward_value", 4))
	mutation_stat_modifiers = mutation_modifiers.duplicate(true)
	special_behavior = String(definition.get("special_behavior", "none"))
	scale = Vector2.ONE * (1.0 if enemy_type != "boss" else 1.6)
	death_fade = 0.0
	burn_damage_per_second = 0.0
	burn_time = 0.0
	burn_tick_time = 0.0
	phase_speed_multiplier = 1.0
	phase_damage_multiplier = 1.0
	special_trigger_used = false
	charge_time = 0.0
	visual_animation_time = 0.0
	_update_visual(0.0)
	_recalculate_stats(false)

func update_enemy(delta: float) -> void:
	_update_visual(delta)
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	spit_cooldown = max(spit_cooldown - delta, 0.0)
	slow_time = max(slow_time - delta, 0.0)
	_update_burn(delta)
	if slow_time <= 0.0:
		slow_amount = 0.0
	hit_flash = max(hit_flash - delta * 4.0, 0.0)
	_handle_boss_phase()
	queue_redraw()
	if _handle_screamer(delta):
		return
	if _handle_brute_charge(delta):
		return
	if _handle_spitter(delta):
		return
	var target_y: float = run_manager.squad_manager.get_anchor_position().y
	var barricade: Node = run_manager.barricade_manager.active_barricade
	if barricade != null and is_instance_valid(barricade):
		target_y = barricade.global_position.y
	if global_position.y < target_y:
		var move_vector: Vector2 = Vector2(0, 1) * (run_manager.scroll_speed + _get_effective_move_speed()) * delta
		position += move_vector
	if barricade != null and is_instance_valid(barricade) and global_position.y >= barricade.global_position.y - attack_range - 24.0:
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

func _handle_screamer(delta: float) -> bool:
	if special_behavior != "screamer":
		return false
	position += Vector2.DOWN * (run_manager.scroll_speed + _get_effective_move_speed() * delta)
	if not special_trigger_used and global_position.y >= run_manager.road.get_squad_y() - 260.0:
		special_trigger_used = true
		run_manager.ui_manager.show_status_message("SCREAMER HOWL!", Color("ff8cf5"))
		for offset in [-70.0, 0.0, 70.0]:
			var spawn_x: float = run_manager.road.clamp_lane_x(global_position.x + offset, 220.0, 64.0)
			run_manager.enemy_manager.spawn_enemy("walker", Vector2(spawn_x, global_position.y - 120.0), run_manager.get_difficulty_multiplier())
	return false

func _handle_brute_charge(delta: float) -> bool:
	if special_behavior != "brute_charger":
		return false
	if not special_trigger_used and global_position.y >= run_manager.road.get_squad_y() - 320.0:
		special_trigger_used = true
		charge_time = 1.2
		run_manager.ui_manager.show_status_message("BRUTE CHARGER!", Color("ff9f5c"))
	if charge_time > 0.0:
		charge_time -= delta
		position += Vector2.DOWN * (run_manager.scroll_speed + _get_effective_move_speed() * 2.8) * delta
		return false
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
	elif special_behavior == "brute_charger":
		run_manager.barricade_manager.damage_active_barricade(damage * 1.4)
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
	elif special_behavior == "treasure_horde":
		run_manager.squad_manager.receive_attack(damage * 0.8)
	elif special_behavior == "grabber":
		run_manager.squad_manager.receive_attack(max(damage, run_manager.squad_manager.base_soldier_hp))
		run_manager.ui_manager.show_status_message("GRABBER PULLED A SOLDIER!", Color("d5a7ff"))
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
	var coins_awarded: int = run_manager.add_coins(reward_value)
	if coins_awarded <= 0 and reward_value > 0:
		run_manager.coins += reward_value
		run_manager.run_stats["coins_earned"] = int(run_manager.run_stats["coins_earned"]) + reward_value
		run_manager.coins_changed.emit(run_manager.coins)
		coins_awarded = reward_value
	run_manager.ui_manager.spawn_reward_popup(global_position, "+%d coins" % coins_awarded, Color("f5d142"))
	if enemy_id == "boss":
		run_manager.reward_manager.apply_reward_by_id("boss_relic")
		run_manager.ui_manager.spawn_reward_popup(global_position + Vector2(0.0, -24.0), "+90M ROUTE", Color("7de3ff"))
		run_manager.ui_manager.show_status_message("BOSS DEFEATED", Color("ffd166"))
	if special_behavior == "treasure_horde":
		run_manager.reward_manager.spawn_reward("coins_large", global_position + Vector2(-22.0, 0.0))
		run_manager.reward_manager.spawn_reward("coins_large", global_position + Vector2(22.0, 0.0))
	AudioManager.play_sfx("zombie_death")
	run_manager.ui_manager.spawn_explosion(global_position, 24.0 if enemy_id != "boss" else 42.0)
	queue_free()

func set_mutation_modifiers(modifiers: Dictionary) -> void:
	mutation_stat_modifiers = modifiers.duplicate(true)
	_recalculate_stats(true)

func _draw() -> void:
	var color: Color = Color(definition.get("color", "#79a35d"))
	if hit_flash > 0.0:
		color = color.lerp(Color.WHITE, hit_flash)
	var body_width := 28.0
	var body_height := 36.0
	if enemy_id == "walker":
		draw_rect(Rect2(-18, -68, 36, 6), Color("20242a"))
		draw_rect(Rect2(-18, -68, 36 * (hp / max(max_hp, 1.0)), 6), Color("ff6262"))
		draw_string(ThemeDB.fallback_font, Vector2(-24, 18), String(definition.get("name", enemy_id)).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 64, 12, Color.WHITE)
		return
	match special_behavior:
		"dog":
			body_width = 20.0
			body_height = 18.0
		"crawler":
			body_width = 30.0
			body_height = 18.0
		"runner":
			body_width = 24.0
			body_height = 32.0
		"tank":
			body_width = 38.0
			body_height = 44.0
		"screamer":
			body_width = 24.0
			body_height = 36.0
		"brute_charger":
			body_width = 42.0
			body_height = 46.0
		"treasure_horde":
			body_width = 40.0
			body_height = 42.0
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
	if special_behavior == "screamer":
		draw_circle(Vector2(0, -12), 8.0, Color("ff8cf5"))
	if special_behavior == "treasure_horde":
		draw_circle(Vector2(0, -6), 8.0, Color("ffd166"))
	if special_behavior == "boss":
		draw_rect(Rect2(-24, 12, 48, 8), Color("5a1d1d"))
	draw_rect(Rect2(-18, -body_height * 0.5 - 16, 36, 6), Color("20242a"))
	draw_rect(Rect2(-18, -body_height * 0.5 - 16, 36 * (hp / max(max_hp, 1.0)), 6), Color("ff6262"))
	draw_string(ThemeDB.fallback_font, Vector2(-24, body_height * 0.5 + 18), String(definition.get("name", enemy_id)).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 64, 12, Color.WHITE)

func _update_visual(delta: float) -> void:
	if goblin_sprite == null:
		return
	var use_goblin: bool = enemy_id == "walker"
	goblin_sprite.visible = use_goblin
	if not use_goblin:
		return
	visual_animation_time += delta
	goblin_sprite.frame_coords = Vector2i(int(floor(visual_animation_time * 10.0)) % 6, 0)
	goblin_sprite.modulate = Color.WHITE.lerp(Color("fff2d2"), hit_flash)

func apply_slow(amount: float, duration: float) -> void:
	slow_amount = max(slow_amount, amount)
	slow_time = max(slow_time, duration)

func apply_burn(damage_per_second: float, duration: float) -> void:
	burn_damage_per_second = max(burn_damage_per_second, damage_per_second)
	burn_time = max(burn_time, duration)
	burn_tick_time = max(burn_tick_time, 0.0)

func _get_effective_move_speed() -> float:
	return move_speed * (1.0 - slow_amount)

func _handle_boss_phase() -> void:
	if special_behavior != "boss" or boss_phase_triggered or hp > max_hp * 0.5:
		return
	boss_phase_triggered = true
	phase_speed_multiplier = 1.3
	phase_damage_multiplier = 1.2
	_recalculate_stats(true)
	run_manager.ui_manager.show_status_message("BOSS ENRAGED", Color("ff6b6b"))
	for offset in [-90.0, 0.0, 90.0]:
		var spawn_x: float = run_manager.road.clamp_lane_x(run_manager.road.get_center_x() + offset, 220.0, 64.0)
		run_manager.enemy_manager.spawn_enemy("runner", Vector2(spawn_x, run_manager.road.get_spawn_y() - 40.0), run_manager.get_difficulty_multiplier())

func _update_burn(delta: float) -> void:
	if burn_time <= 0.0 or hp <= 0.0:
		return
	burn_time = max(burn_time - delta, 0.0)
	burn_tick_time -= delta
	if burn_tick_time > 0.0:
		return
	burn_tick_time = 0.5
	var burn_damage: float = burn_damage_per_second * 0.5
	hp -= burn_damage
	hit_flash = 0.6
	run_manager.ui_manager.spawn_damage_number(global_position + Vector2(10.0, -12.0), burn_damage, Color("ff9d57"))
	if hp <= 0.0:
		die()

func _recalculate_stats(preserve_hp_ratio: bool = true) -> void:
	var previous_max_hp: float = max(max_hp, 1.0)
	var hp_ratio: float = hp / previous_max_hp if preserve_hp_ratio else 1.0
	max_hp = base_max_hp * float(mutation_stat_modifiers.get("hp_multiplier", 1.0))
	move_speed = base_move_speed * float(mutation_stat_modifiers.get("speed_multiplier", 1.0)) * phase_speed_multiplier
	damage = base_damage * float(mutation_stat_modifiers.get("damage_multiplier", 1.0)) * phase_damage_multiplier
	attack_range = base_attack_range * float(mutation_stat_modifiers.get("attack_range_multiplier", 1.0))
	reward_value = max(1, int(round(base_reward_value * float(mutation_stat_modifiers.get("reward_multiplier", 1.0)))))
	hp = max_hp if not preserve_hp_ratio else clamp(max_hp * hp_ratio, 0.0, max_hp)
