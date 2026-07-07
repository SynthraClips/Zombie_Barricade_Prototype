extends Node2D
class_name Soldier

var squad_manager: Node
var role_id := "rifleman"
var role_def: Dictionary = {}
var fire_cooldown := 0.0
var muzzle_flash_time := 0.0

func initialize(manager: Node, new_role_id: String = "rifleman") -> void:
	squad_manager = manager
	role_id = new_role_id
	role_def = squad_manager.get_role_definition(role_id)

func update_soldier(delta: float) -> void:
	fire_cooldown -= delta
	muzzle_flash_time = max(muzzle_flash_time - delta, 0.0)
	queue_redraw()
	var weapon: Dictionary = squad_manager.run_manager.weapon_manager.get_weapon_data_for_role(role_id)
	var weapon_range: float = INF if squad_manager.run_manager.is_auto_fire_enabled() else float(weapon.get("range", 250))
	var target: Node2D = squad_manager.get_primary_target_for(global_position, weapon_range)
	if target != null and fire_cooldown <= 0.0:
		fire_cooldown = 1.0 / max(0.1, float(weapon.get("fire_rate", 1.0)) * squad_manager.get_fire_rate_multiplier())
		squad_manager.run_manager.weapon_manager.fire_weapon(self, target)
		muzzle_flash_time = 0.05
		AudioManager.play_sfx("gunfire")

func _draw() -> void:
	var body_color := Color(role_def.get("color", "#4f8bd6"))
	var accent := Color(role_def.get("accent_color", "#dbeafe"))
	draw_rect(Rect2(-11, -18, 22, 34), body_color)
	draw_rect(Rect2(-9, -30, 18, 12), Color("e2c39f"))
	draw_rect(Rect2(-12, -6, 24, 7), accent.darkened(0.2))
	draw_rect(Rect2(-10, 14, 7, 10), Color("20242a"))
	draw_rect(Rect2(3, 14, 7, 10), Color("20242a"))
	draw_line(Vector2(0, -9), Vector2(0, -34), Color("20242a"), 4.0)
	if role_id == "engineer":
		draw_rect(Rect2(-18, -5, 8, 16), Color("f5c36b"))
		draw_rect(Rect2(-19, -12, 10, 6), Color("7f6b44"))
	if muzzle_flash_time > 0.0:
		draw_circle(Vector2.ZERO + Vector2(0, -36), 8.0, Color(role_def.get("muzzle_color", "#ffd966"), muzzle_flash_time * 20.0))
