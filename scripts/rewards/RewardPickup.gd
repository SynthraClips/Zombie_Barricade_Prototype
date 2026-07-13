extends Area2D
class_name RewardPickup

var run_manager: Node
var reward_id := "coins_small"
var reward_def: Dictionary = {}
var pulse := 0.0
var collected := false
var magnet_radius := 140.0
var collect_radius := 72.0
var magnet_speed := 420.0
var display_scale := 1.0
var magnet_trail_time := 0.0
var icon_texture: Texture2D

func initialize(run: Node, id: String, world_position: Vector2) -> void:
	run_manager = run
	reward_id = id
	reward_def = run_manager.reward_manager.get_reward_definition(reward_id)
	icon_texture = null
	var icon_path := String(reward_def.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon_texture = load(icon_path)
	magnet_radius = float(GameManager.game_config.get("pickup_magnet_radius", 140.0)) + UpgradeManager.get_upgrade_value("pickup_magnet")
	collect_radius = float(GameManager.game_config.get("pickup_collect_radius", 72.0))
	magnet_speed = float(GameManager.game_config.get("pickup_magnet_speed", 420.0))
	collected = false
	display_scale = 1.0
	magnet_trail_time = 0.0
	global_position = world_position
	collision_layer = SquadManager.PICKUP_LAYER
	collision_mask = SquadManager.COLLECTOR_LAYER
	monitoring = true
	monitorable = true
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if run_manager != null and global_position.distance_to(run_manager.squad_manager.get_anchor_position()) <= collect_radius:
		call_deferred("collect")

func update_reward(delta: float) -> void:
	if collected:
		return
	pulse += delta * 5.0
	magnet_trail_time = max(magnet_trail_time - delta, 0.0)
	var anchor_position: Vector2 = run_manager.squad_manager.get_anchor_position()
	global_position += Vector2.DOWN * run_manager.scroll_speed * delta
	var distance_to_squad: float = global_position.distance_to(anchor_position)
	if distance_to_squad <= magnet_radius:
		var direction: Vector2 = (anchor_position - global_position).normalized()
		if magnet_trail_time <= 0.0:
			run_manager.ui_manager.spawn_bullet_trail(global_position, global_position + direction * 14.0, Color(reward_def.get("color", "#ffffff"), 0.15))
			magnet_trail_time = 0.08
		# move_toward prevents a long/slow frame from overshooting the squad and
		# oscillating to the far side of the collector.
		global_position = global_position.move_toward(anchor_position, magnet_speed * delta)
		display_scale = lerpf(display_scale, 1.12, clampf(delta * 8.0, 0.0, 1.0))
		distance_to_squad = global_position.distance_to(anchor_position)
	else:
		display_scale = lerpf(display_scale, 1.0, clampf(delta * 6.0, 0.0, 1.0))
	queue_redraw()
	if overlaps_area(run_manager.squad_manager.get_collector_area()) or distance_to_squad <= collect_radius:
		collect()
		return
	if global_position.y > 1380.0:
		_unregister_and_free()

func _process(delta: float) -> void:
	if collected or run_manager == null or not is_instance_valid(run_manager):
		return
	if run_manager.running and not get_tree().paused:
		update_reward(delta)

func _physics_process(_delta: float) -> void:
	if collected or run_manager == null:
		return
	var anchor_position: Vector2 = run_manager.squad_manager.get_anchor_position()
	if overlaps_area(run_manager.squad_manager.get_collector_area()) or global_position.distance_to(anchor_position) <= collect_radius:
		collect()

func collect() -> void:
	if collected:
		return
	collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	run_manager.reward_manager.unregister_reward(self)
	run_manager.reward_manager.collect_reward(reward_id)
	run_manager.ui_manager.spawn_reward_popup(global_position, String(reward_def.get("label", "Reward")).to_upper(), Color(reward_def.get("color", "#ffffff")))
	run_manager.ui_manager.spawn_explosion(global_position, 16.0)
	visible = false
	call_deferred("_detach_and_free")

func _on_area_entered(area: Area2D) -> void:
	if area == run_manager.squad_manager.get_collector_area():
		collect()

func _unregister_and_free() -> void:
	collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	run_manager.reward_manager.unregister_reward(self)
	call_deferred("_detach_and_free")

func _detach_and_free() -> void:
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	queue_free()

func _draw() -> void:
	var color := Color(reward_def.get("color", "#ffffff"))
	var label := String(reward_def.get("label", "")).to_upper()
	var reward_type := String(reward_def.get("type", "coins"))
	draw_circle(Vector2.ZERO, (14.0 + sin(pulse) * 2.0) * display_scale, color)
	draw_circle(Vector2.ZERO, 22.0 * display_scale, Color(color, 0.18))
	match reward_type:
		"coins":
			draw_circle(Vector2.ZERO, 6.0 * display_scale, Color("5f4b00"))
		"add_soldier", "add_soldiers", "heal_soldiers":
			draw_rect(Rect2(-4, -6, 8, 12), Color.WHITE)
			draw_circle(Vector2(0, -10), 5.0, Color.WHITE)
		"weapon_pickup":
			if icon_texture != null:
				draw_texture_rect(icon_texture, Rect2(-26, -15, 52, 30), false, Color.WHITE)
			else:
				draw_rect(Rect2(-14, -7, 28, 14), Color("2f2a3b"))
				draw_line(Vector2(-11, 0), Vector2(11, 0), Color.WHITE, 3.0)
		"supplies":
			draw_rect(Rect2(-9, -9, 18, 18), Color("6f8e68"))
		"survivors":
			draw_circle(Vector2(0, -7), 5.0, Color.WHITE)
			draw_rect(Rect2(-5, -2, 10, 13), Color.WHITE)
		"tesla_ammo":
			if icon_texture != null:
				draw_texture_rect(icon_texture, Rect2(-18, -18, 36, 36), false, Color.WHITE)
			else:
				draw_polyline(PackedVector2Array([Vector2(-8,-10),Vector2(1,-2),Vector2(-3,2),Vector2(8,10)]), Color("8ee4ff"), 4.0)
		"special_ammo":
			draw_line(Vector2(-7, 6), Vector2(0, -10), Color.WHITE, 3.0)
			draw_line(Vector2(0, -10), Vector2(7, 6), Color.WHITE, 3.0)
			draw_circle(Vector2.ZERO, 4.0 * display_scale, Color("2d1e12"))
		"barricade_repair", "barricade_cooldown_reset":
			draw_rect(Rect2(-10, -10, 20, 20), Color("4b5b73"))
		"fire_rate_boost":
			draw_line(Vector2(-7, 7), Vector2(0, -10), Color.WHITE, 3.0)
			draw_line(Vector2(0, -10), Vector2(7, 7), Color.WHITE, 3.0)
		"damage_boost", "risk_gate":
			draw_circle(Vector2.ZERO, 5.0 * display_scale, Color("441818"))
	draw_string(ThemeDB.fallback_font, Vector2(-44, -22), label, HORIZONTAL_ALIGNMENT_LEFT, 88, 16, Color.WHITE)
