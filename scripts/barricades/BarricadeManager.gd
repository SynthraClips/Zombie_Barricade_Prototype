extends Node2D
class_name BarricadeManager

@export var barricade_scene: PackedScene

var run_manager: Node
var active_barricade: Node
var deploy_cooldown := 0.0
var selected_barricade_id := "wooden_wall"

func setup(run: Node) -> void:
	run_manager = run
	if barricade_scene == null:
		barricade_scene = load("res://scenes/gameplay/Barricade.tscn")
	for child in get_children():
		child.queue_free()
	selected_barricade_id = GameManager.get_starting_barricade_id()
	deploy_cooldown = 0.0
	active_barricade = null
	deploy_current_barricade(false)
	if active_barricade != null and is_instance_valid(active_barricade) and deploy_cooldown <= 0.0:
		deploy_cooldown = _get_deploy_cooldown_for(selected_barricade_id)

func update_barricade(delta: float) -> void:
	deploy_cooldown = max(deploy_cooldown - delta, 0.0)
	if active_barricade != null and is_instance_valid(active_barricade):
		active_barricade.update_barricade(delta)
		for enemy in run_manager.enemy_manager.enemies:
			if is_instance_valid(enemy):
				active_barricade.apply_zone_effect(enemy, delta)

func deploy_current_barricade(apply_pressure_relief: bool = true) -> bool:
	if deploy_cooldown > 0.0:
		return false
	if active_barricade != null and is_instance_valid(active_barricade):
		return false
	selected_barricade_id = GameManager.get_starting_barricade_id()
	active_barricade = barricade_scene.instantiate()
	add_child(active_barricade)
	active_barricade.initialize(run_manager, selected_barricade_id, Vector2(run_manager.road.get_center_x(), 900))
	deploy_cooldown = max(0.1, _get_deploy_cooldown_for(selected_barricade_id))
	SaveManager.save_data["stats"]["barricades_deployed"] += 1
	MissionManager.increment_progress("barricades_deployed", 1)
	if apply_pressure_relief:
		run_manager.reduce_horde_pressure_for("barricade_deployed")
	run_manager.ui_manager.show_status_message("%s DEPLOYED" % String(GameManager.barricade_data.get(selected_barricade_id, {}).get("name", "Barricade")).to_upper(), Color("9bd4ff"))
	return true

func damage_active_barricade(amount: float) -> void:
	if active_barricade != null and is_instance_valid(active_barricade):
		active_barricade.take_damage(amount)
	else:
		run_manager.squad_manager.receive_attack(amount)

func clear_active_barricade() -> void:
	active_barricade = null

func repair_active_barricade(amount: float) -> float:
	if active_barricade == null or not is_instance_valid(active_barricade):
		return 0.0
	return active_barricade.repair(amount)

func reset_cooldown() -> void:
	deploy_cooldown = 0.0

func get_selected_barricade_definition() -> Dictionary:
	return GameManager.barricade_data.get(selected_barricade_id, {})

func _get_deploy_cooldown_for(barricade_id: String) -> float:
	var base_cooldown: float = float(GameManager.game_config.get("barricade_cooldown", 8.0))
	var definition: Dictionary = GameManager.barricade_data.get(barricade_id, {})
	var cooldown_multiplier: float = float(definition.get("cooldown_multiplier", 1.0))
	var upgrade_multiplier: float = max(0.5, 1.0 - UpgradeManager.get_upgrade_value("barricade_cooldown"))
	return max(0.1, base_cooldown * cooldown_multiplier * upgrade_multiplier)
