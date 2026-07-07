extends Node2D
class_name Barricade

var run_manager: Node
var barricade_id := "paper_wall"
var definition: Dictionary = {}
var hp := 0.0
var max_hp := 0.0
var hit_flash := 0.0

func initialize(run: Node, tier_id: String, spawn_position: Vector2) -> void:
	run_manager = run
	barricade_id = tier_id
	definition = GameManager.barricade_data.get(tier_id, {})
	global_position = spawn_position
	max_hp = float(definition.get("hp", 40)) * (1.0 + UpgradeManager.get_upgrade_value("barricade_hp"))
	hp = max_hp

func update_barricade(delta: float) -> void:
	hit_flash = max(hit_flash - delta * 4.0, 0.0)
	var auto_repair: float = UpgradeManager.get_upgrade_value("barricade_auto_repair")
	if auto_repair > 0.0:
		repair(auto_repair * delta, true)
	queue_redraw()

func take_damage(amount: float) -> void:
	hp -= amount
	hit_flash = 1.0
	run_manager.ui_manager.spawn_damage_number(global_position, amount, Color("cfe8ff"))
	run_manager.add_screen_shake(0.12, 4.0)
	if hp <= 0.0:
		var explosion_radius: float = float(definition.get("explosion_radius", 44.0))
		run_manager.ui_manager.spawn_explosion(global_position, explosion_radius)
		var explosion_damage: float = float(definition.get("explosion_damage", 0.0))
		if explosion_damage > 0.0:
			for enemy in run_manager.enemy_manager.enemies:
				if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= explosion_radius:
					enemy.take_damage(explosion_damage, true)
		queue_free()
		run_manager.barricade_manager.clear_active_barricade()

func repair(amount: float, silent: bool = false) -> float:
	if amount <= 0.0:
		return 0.0
	var repair_multiplier: float = 1.0 + UpgradeManager.get_upgrade_value("barricade_repair") + float(definition.get("repair_multiplier", 0.0))
	var previous_hp: float = hp
	hp = min(max_hp, hp + amount * repair_multiplier)
	var repaired: float = hp - previous_hp
	if repaired > 0.0 and not silent:
		run_manager.ui_manager.spawn_reward_popup(global_position + Vector2(0, -26), "+%d REPAIR" % int(round(repaired)), Color("9bd4ff"))
	return repaired

func apply_zone_effect(enemy: Node, _delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var slow_factor: float = float(definition.get("slow_factor", 0.0))
	if slow_factor <= 0.0:
		return
	if enemy.global_position.distance_to(global_position) <= attack_reach_radius():
		enemy.apply_slow(slow_factor, 0.2)

func attack_reach_radius() -> float:
	return float(definition.get("width", 180.0)) * 0.5 + 26.0

func _draw() -> void:
	var color: Color = Color(definition.get("color", "#d7d0aa"))
	if hit_flash > 0.0:
		color = color.lerp(Color.WHITE, hit_flash)
	var width: float = float(definition.get("width", 180))
	var height: float = float(definition.get("height", 28))
	draw_rect(Rect2(-width * 0.5, -height * 0.5, width, height), color)
	if barricade_id == "barbed_wire":
		for offset in [-0.35, 0.0, 0.35]:
			draw_line(Vector2(-width * 0.5, offset * height), Vector2(width * 0.5, offset * height + 6.0), Color("d8dde3"), 2.0)
	if barricade_id == "explosive_trap":
		draw_circle(Vector2.ZERO, 18.0, Color("2d3138"))
		draw_circle(Vector2.ZERO, 10.0, Color("ff935a"))
	draw_rect(Rect2(-width * 0.5, -height * 0.5 - 10, width, 6), Color("1c2128"))
	draw_rect(Rect2(-width * 0.5, -height * 0.5 - 10, width * (hp / max(max_hp, 1.0)), 6), Color("6be392"))
