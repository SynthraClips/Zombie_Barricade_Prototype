extends Node2D
class_name Obstacle

var run_manager: Node
var obstacle_type := "barrel"
var config: Dictionary = {}
var hp := 30.0
var max_hp := 30.0
var reward_id := ""
var hit_flash := 0.0
var time_remaining := 0.0
var has_timer := false
var resolved := false
var alarm_triggered := false
var display_label := "OBSTACLE"
var hold_y := INF
var hold_enabled := false
var projectile_hit_radius := 20.0

func initialize(run: Node, type_id: String, spawn_position: Vector2, config_overrides: Dictionary = {}) -> void:
	run_manager = run
	obstacle_type = type_id
	config = _get_obstacle_definition(type_id)
	for key in config_overrides.keys():
		config[key] = config_overrides[key]
	global_position = spawn_position
	max_hp = float(config.get("hp", 30.0))
	hp = max_hp
	reward_id = _resolve_reward_id()
	time_remaining = float(config.get("timer_duration", 0.0))
	has_timer = time_remaining > 0.0
	display_label = String(config.get("label", obstacle_type.replace("_", " "))).to_upper()
	hold_enabled = bool(config.get("hold_position_enabled", false))
	hold_y = float(config.get("hold_y", global_position.y))
	projectile_hit_radius = float(config.get("projectile_hit_radius", 20.0))
	resolved = false
	alarm_triggered = false
	queue_redraw()

func update_obstacle(delta: float) -> void:
	if resolved:
		return
	var scroll_delta: float = run_manager.scroll_speed * delta
	if hold_enabled and global_position.y >= hold_y:
		global_position.y = hold_y
	else:
		position += Vector2.DOWN * scroll_delta
		if hold_enabled and global_position.y >= hold_y:
			global_position.y = hold_y
	hit_flash = max(hit_flash - delta * 3.0, 0.0)
	if has_timer:
		time_remaining = max(time_remaining - delta, 0.0)
		if time_remaining <= 0.0:
			_handle_timer_expired()
			return
	queue_redraw()
	if position.y > 1380:
		force_cleanup("offscreen")

func take_damage(amount: float, _explosive_hit: bool = false) -> void:
	if resolved:
		return
	hp -= amount
	hit_flash = 1.0
	run_manager.ui_manager.spawn_damage_number(global_position, amount, Color("ffd98f"))
	if hp <= 0.0:
		destroy_obstacle()
	else:
		queue_redraw()

func destroy_obstacle() -> void:
	if resolved:
		return
	resolved = true
	_unregister()
	run_manager.register_obstacle_destroyed()
	_apply_destroy_effect()
	_award_reward()
	queue_free()

func force_cleanup(_reason: String = "reset") -> void:
	if resolved:
		queue_free()
		return
	resolved = true
	_unregister()
	queue_free()

func get_projectile_hit_radius() -> float:
	return projectile_hit_radius

func _handle_timer_expired() -> void:
	if resolved:
		return
	resolved = true
	_unregister()
	if String(config.get("timer_effect", "")) == "alarm_wave":
		alarm_triggered = true
		run_manager.ui_manager.show_status_message("Alarm Triggered!", Color("ff6b6b"))
		run_manager.ui_manager.spawn_reward_popup(global_position + Vector2(-50.0, -38.0), "Alarm Triggered!", Color("ff6b6b"))
		run_manager.wave_spawner.trigger_alarm_wave(config, global_position)
	else:
		run_manager.ui_manager.show_status_message("Object Destroyed", Color("ffd98f"))
	queue_free()

func _apply_destroy_effect() -> void:
	var destroy_message: String = String(config.get("destroy_message", "Object Destroyed"))
	var destroy_color := Color(config.get("destroy_color", "#ffd98f"))
	var effect_type: String = String(config.get("destroy_effect", "none"))
	match effect_type:
		"explosion":
			var radius: float = float(config.get("explosion_radius", 80.0))
			var damage: float = float(config.get("explosion_damage", 30.0))
			run_manager.enemy_manager.damage_enemies_in_radius(global_position, radius, damage)
			run_manager.ui_manager.spawn_explosion(global_position, radius * 0.45)
			AudioManager.play_sfx("explosion")
		"stun":
			var stun_radius: float = float(config.get("stun_radius", 90.0))
			var stun_amount: float = float(config.get("stun_amount", 1.0))
			var stun_duration: float = float(config.get("stun_duration", 1.8))
			run_manager.enemy_manager.apply_slow_in_radius(global_position, stun_radius, stun_amount, stun_duration)
			run_manager.ui_manager.spawn_explosion(global_position, stun_radius * 0.35)
			destroy_message = "Zombies Stunned"
			destroy_color = Color("8ee4ff")
		"alarm_stopped":
			destroy_message = "Alarm Stopped"
			destroy_color = Color("7be495")
			run_manager.ui_manager.spawn_explosion(global_position, 28.0)
			run_manager.register_special_event_completed("alarm_stopped")
	if destroy_message != "":
		run_manager.ui_manager.show_status_message(destroy_message, destroy_color)
		run_manager.ui_manager.spawn_reward_popup(global_position + Vector2(-46.0, -40.0), destroy_message, destroy_color)

func _award_reward() -> void:
	if reward_id == "":
		return
	run_manager.reward_manager.spawn_reward(reward_id, global_position)

func _unregister() -> void:
	if run_manager != null and run_manager.enemy_manager != null:
		run_manager.enemy_manager.unregister_obstacle(self)

func _resolve_reward_id() -> String:
	var configured_reward: String = String(config.get("reward_id", ""))
	if configured_reward != "":
		return configured_reward
	var reward_table: Array = config.get("reward_table", [])
	if reward_table.is_empty():
		reward_table = GameManager.reward_data.get("obstacle_reward_table", [])
	if reward_table.is_empty():
		return ""
	return String(reward_table[randi() % reward_table.size()])

func _get_obstacle_definition(type_id: String) -> Dictionary:
	var definitions: Dictionary = GameManager.game_config.get("road_objects", {}).get("definitions", {})
	if definitions.has(type_id):
		return definitions.get(type_id, {}).duplicate(true)
	if type_id == "crate":
		return {
			"label": "Crate",
			"hp": 40.0,
			"reward_table": GameManager.reward_data.get("obstacle_reward_table", []),
			"draw_style": "crate",
			"destroy_message": "Object Destroyed",
			"destroy_color": "#ffd98f",
			"projectile_hit_radius": 20.0
		}
	return {
		"label": "Barrel",
		"hp": 28.0,
		"reward_table": GameManager.reward_data.get("obstacle_reward_table", []),
		"draw_style": "barrel",
		"destroy_message": "Object Destroyed",
		"destroy_color": "#ffd98f",
		"projectile_hit_radius": 18.0
	}

func _draw() -> void:
	var draw_style: String = String(config.get("draw_style", obstacle_type))
	var base_color := Color(config.get("base_color", "#8b5a2b" if obstacle_type == "crate" else "#a75b3f"))
	var accent_color := Color(config.get("accent_color", "#f4b266"))
	var outline_color := Color(config.get("outline_color", "#22262b"))
	if hit_flash > 0.0:
		base_color = base_color.lerp(Color.WHITE, hit_flash)
		accent_color = accent_color.lerp(Color.WHITE, hit_flash * 0.75)
	match draw_style:
		"fuel_barrel", "barrel":
			draw_circle(Vector2.ZERO, 20.0, base_color)
			draw_rect(Rect2(-16.0, -20.0, 32.0, 40.0), base_color)
			draw_rect(Rect2(-18.0, -8.0, 36.0, 6.0), accent_color)
			draw_rect(Rect2(-18.0, 8.0, 36.0, 6.0), accent_color)
		"car", "alarm_car":
			draw_rect(Rect2(-42.0, -20.0, 84.0, 40.0), base_color)
			draw_rect(Rect2(-26.0, -34.0, 52.0, 20.0), accent_color)
			draw_circle(Vector2(-24.0, 22.0), 9.0, outline_color)
			draw_circle(Vector2(24.0, 22.0), 9.0, outline_color)
			if draw_style == "alarm_car":
				var pulse_color := Color("ff5252") if int(Time.get_ticks_msec() / 200.0) % 2 == 0 else Color("ffd166")
				draw_circle(Vector2(0.0, -30.0), 8.0, pulse_color)
		"electric_box":
			draw_rect(Rect2(-24.0, -28.0, 48.0, 56.0), base_color)
			draw_rect(Rect2(-16.0, -12.0, 32.0, 8.0), accent_color)
			draw_line(Vector2(-8.0, -4.0), Vector2(2.0, -18.0), Color("c8f8ff"), 3.0)
			draw_line(Vector2(2.0, -18.0), Vector2(10.0, -2.0), Color("c8f8ff"), 3.0)
			draw_line(Vector2(10.0, -2.0), Vector2(-2.0, 18.0), Color("c8f8ff"), 3.0)
		_:
			draw_rect(Rect2(-22.0, -22.0, 44.0, 44.0), base_color)
			draw_rect(Rect2(-26.0, -26.0, 52.0, 52.0), outline_color, false, 3.0)
	draw_rect(Rect2(-42.0, -48.0, 84.0, 7.0), outline_color)
	draw_rect(Rect2(-42.0, -48.0, 84.0 * (hp / max(max_hp, 1.0)), 7.0), accent_color)
	if has_timer:
		draw_rect(Rect2(-42.0, -60.0, 84.0, 6.0), Color("1f252b"))
		draw_rect(Rect2(-42.0, -60.0, 84.0 * (time_remaining / max(float(config.get("timer_duration", 1.0)), 0.01)), 6.0), Color("ffd166"))
		draw_string(ThemeDB.fallback_font, Vector2(-18.0, 52.0), "%0.1fs" % time_remaining, HORIZONTAL_ALIGNMENT_LEFT, 52, 14, Color("ffe7ad"))
	draw_string(ThemeDB.fallback_font, Vector2(-54.0, -70.0), display_label, HORIZONTAL_ALIGNMENT_LEFT, 108, 15, Color.WHITE)
