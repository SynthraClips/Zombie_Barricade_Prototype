extends Node2D
class_name ArmouryCache

var run_manager: Node
var cache_manager: Node
var config: Dictionary = {}
var reward_id := ""
var hp := 1.0
var max_hp := 1.0
var time_remaining := 0.0
var hold_y := 760.0
var move_speed := 140.0
var reached_hold := false
var hit_flash := 0.0
var resolved := false
var projectile_hit_radius := 34.0

func initialize(run: Node, manager: Node, world_position: Vector2, cache_config: Dictionary, selected_reward_id: String) -> void:
	run_manager = run
	cache_manager = manager
	config = cache_config.duplicate(true)
	reward_id = selected_reward_id
	max_hp = float(config.get("hp", 220.0))
	hp = max_hp
	time_remaining = float(config.get("timer_duration", 8.0))
	move_speed = float(config.get("move_speed", 150.0))
	projectile_hit_radius = float(config.get("projectile_hit_radius", 34.0))
	global_position = world_position
	hold_y = _resolve_hold_y(float(config.get("hold_y", 760.0)))
	reached_hold = global_position.y >= hold_y
	queue_redraw()

func update_cache(delta: float) -> void:
	if resolved:
		return
	hit_flash = max(hit_flash - delta * 4.5, 0.0)
	if not reached_hold:
		global_position.y += (run_manager.scroll_speed + move_speed) * delta
		if global_position.y >= hold_y:
			global_position.y = hold_y
			reached_hold = true
	time_remaining = max(time_remaining - delta, 0.0)
	if time_remaining <= 0.0:
		expire()
		return
	queue_redraw()

func take_damage(amount: float, _explosive_hit: bool = false) -> void:
	if resolved:
		return
	hp -= amount
	hit_flash = 1.0
	run_manager.ui_manager.spawn_damage_number(global_position + Vector2(0.0, -34.0), amount, Color("ffd98f"))
	AudioManager.play_sfx("zombie_hit")
	if hp <= 0.0:
		destroy_cache()
	else:
		queue_redraw()

func destroy_cache() -> void:
	if resolved:
		return
	resolved = true
	cache_manager.unregister_cache(self)
	run_manager.register_armoury_cache_destroyed()
	var reward_result: Dictionary = cache_manager.award_cache_reward(self)
	run_manager.ui_manager.show_status_message("CACHE SECURED", Color("7be495"))
	run_manager.ui_manager.spawn_reward_popup(global_position + Vector2(-24.0, -44.0), String(reward_result.get("popup", "CACHE SECURED")), Color(reward_result.get("color", Color("7be495"))))
	run_manager.ui_manager.spawn_explosion(global_position, 34.0)
	queue_free()

func expire() -> void:
	if resolved:
		return
	resolved = true
	cache_manager.unregister_cache(self)
	run_manager.ui_manager.show_status_message("CACHE LOCKED", Color("ff8f6b"))
	run_manager.ui_manager.spawn_reward_popup(global_position + Vector2(-18.0, -44.0), "MISSED", Color("ff8f6b"))
	queue_free()

func force_cleanup(_reason: String = "reset") -> void:
	if resolved:
		queue_free()
		return
	resolved = true
	queue_free()

func get_projectile_hit_radius() -> float:
	return projectile_hit_radius

func _resolve_hold_y(configured_hold_y: float) -> float:
	var safe_margin: float = float(config.get("safe_zone_margin", 84.0))
	var squad_limit: float = run_manager.road.get_squad_y() - safe_margin - 56.0
	var barricade_limit: float = squad_limit
	var barricade: Node = run_manager.barricade_manager.active_barricade
	if barricade != null and is_instance_valid(barricade):
		barricade_limit = barricade.global_position.y - safe_margin
	var stop_limit: float = min(configured_hold_y, squad_limit, barricade_limit)
	return max(stop_limit, global_position.y + 120.0)

func _draw() -> void:
	var base_color := Color("c58a3a")
	var accent_color := Color("ffe0a6")
	if hit_flash > 0.0:
		base_color = base_color.lerp(Color.WHITE, hit_flash)
		accent_color = accent_color.lerp(Color.WHITE, hit_flash * 0.75)
	draw_rect(Rect2(-30.0, -24.0, 60.0, 48.0), base_color)
	draw_rect(Rect2(-34.0, -28.0, 68.0, 56.0), Color("2b2218"), false, 3.0)
	draw_rect(Rect2(-8.0, -24.0, 16.0, 48.0), accent_color)
	draw_rect(Rect2(-30.0, -6.0, 60.0, 12.0), Color("6a4923"))
	draw_rect(Rect2(-34.0, -46.0, 68.0, 8.0), Color("22262b"))
	draw_rect(Rect2(-34.0, -46.0, 68.0 * (hp / max(max_hp, 1.0)), 8.0), Color("f06b5e"))
	draw_rect(Rect2(-34.0, -58.0, 68.0, 6.0), Color("1f252b"))
	draw_rect(Rect2(-34.0, -58.0, 68.0 * (time_remaining / max(float(config.get("timer_duration", 8.0)), 0.01)), 6.0), Color("ffd166"))
	draw_string(ThemeDB.fallback_font, Vector2(-42.0, -68.0), "ARMOURY CACHE", HORIZONTAL_ALIGNMENT_LEFT, 96, 16, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(-18.0, 44.0), "%0.1fs" % time_remaining, HORIZONTAL_ALIGNMENT_LEFT, 48, 16, Color("ffe7ad"))
