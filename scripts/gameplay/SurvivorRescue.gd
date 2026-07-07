extends Node2D
class_name SurvivorRescue

var run_manager: Node
var rescue_manager: Node
var config: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var time_remaining := 0.0
var hold_y := 760.0
var move_speed := 120.0
var reached_hold := false
var hit_flash := 0.0
var resolved := false
var soldiers_reward := 0
var coin_reward := 0
var projectile_hit_radius := 36.0
var rescue_label := "SURVIVORS TRAPPED"
var obstruction_label := "ROADBLOCK"

func initialize(run: Node, manager: Node, world_position: Vector2, rescue_config: Dictionary) -> void:
	run_manager = run
	rescue_manager = manager
	config = rescue_config.duplicate(true)
	max_hp = float(config.get("hp", 28.0))
	hp = max_hp
	time_remaining = float(config.get("timer_duration", 6.5))
	move_speed = float(config.get("move_speed", 150.0))
	projectile_hit_radius = float(config.get("projectile_hit_radius", 36.0))
	soldiers_reward = int(config.get("soldiers_reward", 3))
	coin_reward = int(config.get("coin_reward", 0))
	rescue_label = String(config.get("rescue_label", "SURVIVORS TRAPPED")).to_upper()
	obstruction_label = String(config.get("obstruction_label", "WRECK")).to_upper()
	global_position = world_position
	hold_y = _resolve_hold_y(float(config.get("hold_y", 770.0)))
	reached_hold = global_position.y >= hold_y
	queue_redraw()

func update_rescue(delta: float) -> void:
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
	hp -= max(amount, 0.0)
	hit_flash = 1.0
	run_manager.ui_manager.spawn_damage_number(global_position + Vector2(0.0, -34.0), amount, Color("ffd98f"))
	AudioManager.play_sfx("zombie_hit")
	if hp <= 0.0:
		complete_rescue()
	else:
		queue_redraw()

func complete_rescue() -> void:
	if resolved:
		return
	resolved = true
	rescue_manager.unregister_rescue(self)
	var reward_result: Dictionary = rescue_manager.award_rescue(self)
	run_manager.ui_manager.show_status_message(String(reward_result.get("popup", "SURVIVORS RESCUED")), Color(reward_result.get("color", Color("7be495"))))
	run_manager.ui_manager.spawn_reward_popup(global_position + Vector2(-42.0, -48.0), String(reward_result.get("popup", "SURVIVORS RESCUED")), Color(reward_result.get("color", Color("7be495"))))
	if int(reward_result.get("coins", 0)) > 0:
		run_manager.ui_manager.spawn_reward_popup(global_position + Vector2(-28.0, -18.0), "+%d COINS" % int(reward_result.get("coins", 0)), Color("ffd166"))
	run_manager.ui_manager.spawn_explosion(global_position, 30.0)
	queue_free()

func expire() -> void:
	if resolved:
		return
	resolved = true
	rescue_manager.unregister_rescue(self)
	run_manager.ui_manager.show_status_message("SURVIVORS LOST", Color("ff8f6b"))
	run_manager.ui_manager.spawn_reward_popup(global_position + Vector2(-34.0, -42.0), "RESCUE FAILED", Color("ff8f6b"))
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
	var safe_margin: float = float(config.get("safe_zone_margin", 92.0))
	var squad_limit: float = run_manager.road.get_squad_y() - safe_margin - 56.0
	var barricade_limit: float = squad_limit
	var barricade: Node = run_manager.barricade_manager.active_barricade
	if barricade != null and is_instance_valid(barricade):
		barricade_limit = barricade.global_position.y - safe_margin
	var stop_limit: float = min(configured_hold_y, squad_limit, barricade_limit)
	return max(stop_limit, global_position.y + 120.0)

func _draw() -> void:
	var shell_color := Color("7b4e2e")
	var plate_color := Color("c9854b")
	var survivor_color := Color("9ad1ff")
	if hit_flash > 0.0:
		shell_color = shell_color.lerp(Color.WHITE, hit_flash)
		plate_color = plate_color.lerp(Color.WHITE, hit_flash * 0.7)
	draw_rect(Rect2(-38.0, -20.0, 76.0, 40.0), shell_color)
	draw_rect(Rect2(-48.0, -10.0, 96.0, 26.0), plate_color)
	draw_rect(Rect2(-54.0, -24.0, 108.0, 50.0), Color("2a221c"), false, 3.0)
	draw_rect(Rect2(-18.0, -4.0, 36.0, 18.0), Color("535f66"))
	draw_rect(Rect2(-24.0, 16.0, 48.0, 8.0), Color("5f4030"))
	draw_circle(Vector2(-14.0, -34.0), 7.0, survivor_color)
	draw_rect(Rect2(-19.0, -28.0, 10.0, 18.0), survivor_color)
	draw_circle(Vector2(14.0, -34.0), 7.0, survivor_color)
	draw_rect(Rect2(9.0, -28.0, 10.0, 18.0), survivor_color)
	draw_rect(Rect2(-38.0, -54.0, 76.0, 8.0), Color("20262b"))
	draw_rect(Rect2(-38.0, -54.0, 76.0 * (hp / max(max_hp, 1.0)), 8.0), Color("f06b5e"))
	draw_rect(Rect2(-38.0, -66.0, 76.0, 6.0), Color("20262b"))
	draw_rect(Rect2(-38.0, -66.0, 76.0 * (time_remaining / max(float(config.get("timer_duration", 6.5)), 0.01)), 6.0), Color("ffd166"))
	draw_string(ThemeDB.fallback_font, Vector2(-62.0, -76.0), rescue_label, HORIZONTAL_ALIGNMENT_LEFT, 124, 16, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(-28.0, 42.0), obstruction_label, HORIZONTAL_ALIGNMENT_LEFT, 72, 14, Color("ffe7ad"))
	draw_string(ThemeDB.fallback_font, Vector2(-16.0, 58.0), "%0.1fs" % time_remaining, HORIZONTAL_ALIGNMENT_LEFT, 48, 14, Color("ffd166"))
