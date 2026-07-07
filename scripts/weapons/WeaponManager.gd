extends Node
class_name WeaponManager

@export var projectile_scene: PackedScene

var run_manager: Node
var current_weapon_id := ""
var temporary_weapon_id := ""
var temporary_weapon_time := 0.0
var special_ammo_type := ""
var special_ammo_time := 0.0

func setup(run: Node) -> void:
	run_manager = run
	if projectile_scene == null:
		projectile_scene = load("res://scenes/gameplay/Projectile.tscn")
	current_weapon_id = GameManager.get_starting_weapon_id()
	clear_special_ammo()

func _process(delta: float) -> void:
	if temporary_weapon_time > 0.0:
		temporary_weapon_time -= delta
		if temporary_weapon_time <= 0.0:
			temporary_weapon_id = ""
	if special_ammo_time > 0.0:
		special_ammo_time = max(special_ammo_time - delta, 0.0)
		if special_ammo_time <= 0.0:
			clear_special_ammo()

func get_current_weapon_id() -> String:
	return temporary_weapon_id if temporary_weapon_id != "" else current_weapon_id

func get_current_weapon_data() -> Dictionary:
	return GameManager.weapon_data.get(get_current_weapon_id(), GameManager.weapon_data.get("rifle", {}))

func get_weapon_data_for_role(role_id: String) -> Dictionary:
	var role_def: Dictionary = GameManager.game_config.get("soldier_roles", {}).get(role_id, {})
	var weapon_override: String = String(role_def.get("weapon_override", ""))
	if weapon_override != "" and GameManager.weapon_data.has(weapon_override):
		return GameManager.weapon_data.get(weapon_override, {})
	return get_current_weapon_data()

func fire_weapon(soldier: Node, target: Node2D) -> void:
	var weapon: Dictionary = get_effective_weapon_data_for_role(String(soldier.get("role_id")))
	if bool(weapon.get("hitscan", false)):
		_fire_hitscan(soldier, target, weapon)
		return
	var projectile_count: int = int(weapon.get("projectile_count", 1))
	for shot_index in projectile_count:
		var projectile: Node = Node2D.new()
		projectile.set_script(load("res://scripts/weapons/Projectile.gd"))
		run_manager.add_child(projectile)
		var spread: float = float(weapon.get("spread", 0.0))
		var angle: float = randf_range(-spread, spread)
		projectile.call("initialize", run_manager, soldier.global_position + Vector2(0, -34), target.global_position, weapon, angle)

func _fire_hitscan(soldier: Node, target: Node2D, weapon: Dictionary) -> void:
	var auto_fire_enabled: bool = run_manager.is_auto_fire_enabled()
	if target != null and not (target is Enemy):
		var direct_damage: float = get_damage_for_target(weapon, target)
		if target.has_method("take_damage"):
			target.take_damage(direct_damage, false)
		run_manager.ui_manager.spawn_bullet_trail(soldier.global_position + Vector2(0, -28), target.global_position, Color("90f4ff"))
		return
	if auto_fire_enabled and target != null:
		var auto_damage: float = get_damage_for_target(weapon, target)
		target.take_damage(auto_damage, false)
		_apply_post_hit_effects(weapon, target, auto_damage)
		run_manager.ui_manager.spawn_bullet_trail(soldier.global_position + Vector2(0, -28), target.global_position, Color("90f4ff"))
		return
	var candidates: Array = run_manager.enemy_manager.get_enemies_sorted_from(soldier.global_position, INF if auto_fire_enabled else float(weapon.get("range", 260)))
	var pierce: int = int(weapon.get("pierce_count", 0))
	var hit_count: int = 0
	for candidate in candidates:
		if hit_count > pierce:
			break
		var damage: float = get_damage_for_target(weapon, candidate)
		candidate.take_damage(damage, false)
		_apply_post_hit_effects(weapon, candidate, damage)
		run_manager.ui_manager.spawn_bullet_trail(soldier.global_position + Vector2(0, -28), candidate.global_position, Color("90f4ff"))
		hit_count += 1

func _compute_damage(base_damage: float) -> float:
	var crit_chance: float = UpgradeManager.get_upgrade_value("critical_chance")
	var damage: float = base_damage * run_manager.squad_manager.get_damage_multiplier()
	if randf() < crit_chance:
		damage *= float(GameManager.game_config.get("crit_multiplier", 1.5))
	return damage

func get_damage_for_projectile(weapon: Dictionary) -> float:
	return _compute_damage(float(weapon.get("damage", 5)))

func get_damage_for_target(weapon: Dictionary, target: Variant = null) -> float:
	var damage: float = get_damage_for_projectile(weapon)
	var category: String = _get_target_category(target)
	if special_ammo_type == "heavy" and category in ["gate", "armoury_cache", "survivor_rescue", "obstacle"]:
		damage *= get_special_ammo_config(special_ammo_type).get("object_damage_multiplier", 1.0)
	return damage

func get_effective_weapon_data_for_role(role_id: String) -> Dictionary:
	var weapon: Dictionary = get_weapon_data_for_role(role_id).duplicate(true)
	if special_ammo_type == "":
		return weapon
	var ammo_config: Dictionary = get_special_ammo_config(special_ammo_type)
	weapon["damage"] = float(weapon.get("damage", 0.0)) * float(ammo_config.get("damage_multiplier", 1.0))
	weapon["pierce_count"] = int(weapon.get("pierce_count", 0)) + int(ammo_config.get("pierce_count", 0))
	weapon["splash_radius"] = max(float(weapon.get("splash_radius", 0.0)), float(ammo_config.get("splash_radius", 0.0)))
	weapon["special_ammo_type"] = special_ammo_type
	weapon["special_ammo_config"] = ammo_config.duplicate(true)
	return weapon

func apply_special_ammo(ammo_type: String, duration_override: float = -1.0) -> bool:
	if ammo_type == "" or not has_special_ammo_config(ammo_type):
		return false
	var previous_type: String = special_ammo_type
	var config: Dictionary = get_special_ammo_config(ammo_type)
	var duration: float = duration_override if duration_override >= 0.0 else float(config.get("duration", 8.0))
	special_ammo_type = ammo_type
	if previous_type == ammo_type:
		special_ammo_time = max(special_ammo_time, duration)
	else:
		special_ammo_time = duration
	return true

func clear_special_ammo() -> void:
	special_ammo_type = ""
	special_ammo_time = 0.0

func has_active_special_ammo() -> bool:
	return special_ammo_type != "" and special_ammo_time > 0.0

func get_special_ammo_state() -> Dictionary:
	if not has_active_special_ammo():
		return {"type": "", "time_remaining": 0.0, "label": ""}
	var config: Dictionary = get_special_ammo_config(special_ammo_type)
	return {
		"type": special_ammo_type,
		"time_remaining": special_ammo_time,
		"label": String(config.get("label", special_ammo_type)).to_upper(),
		"config": config.duplicate(true)
	}

func has_special_ammo_config(ammo_type: String) -> bool:
	return GameManager.game_config.get("special_ammo", {}).has(ammo_type)

func get_special_ammo_config(ammo_type: String) -> Dictionary:
	return GameManager.game_config.get("special_ammo", {}).get(ammo_type, {})

func _get_target_category(target: Variant) -> String:
	if target == null:
		return "default"
	if target is Enemy:
		return "enemy"
	if target is Gate:
		return "gate"
	if _matches_script_class(target, "ArmouryCache"):
		return "armoury_cache"
	if _matches_script_class(target, "SurvivorRescue"):
		return "survivor_rescue"
	if target is Obstacle:
		return "obstacle"
	return "default"

func _matches_script_class(target: Variant, class_name_to_match: String) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.get_script() == null:
		return false
	return target.is_class(class_name_to_match)

func _apply_post_hit_effects(weapon: Dictionary, target: Variant, damage: float) -> void:
	if target == null or not (target is Enemy) or not is_instance_valid(target):
		return
	var ammo_type: String = String(weapon.get("special_ammo_type", ""))
	var ammo_config: Dictionary = weapon.get("special_ammo_config", {})
	match ammo_type:
		"incendiary":
			if target.has_method("apply_burn"):
				target.apply_burn(float(ammo_config.get("burn_damage", 2.0)), float(ammo_config.get("burn_duration", 2.0)))
		"explosive":
			var splash_radius: float = float(weapon.get("splash_radius", 0.0))
			if splash_radius > 0.0:
				for nearby in run_manager.enemy_manager.enemies:
					if nearby == target or not is_instance_valid(nearby):
						continue
					if nearby.global_position.distance_to(target.global_position) <= splash_radius:
						nearby.take_damage(damage * 0.5, false)
				run_manager.ui_manager.spawn_explosion(target.global_position, splash_radius)
				AudioManager.play_sfx("explosion")

func apply_temporary_weapon(weapon_id: String, duration: float) -> void:
	if not GameManager.weapon_data.has(weapon_id):
		return
	temporary_weapon_id = weapon_id
	temporary_weapon_time = duration

func unlock_next_weapon() -> void:
	var defs: Array = GameManager.upgrade_data.get("upgrades", {}).get("starting_weapon", {}).get("choices", [])
	var current_idx: int = defs.find(current_weapon_id)
	if current_idx < defs.size() - 1:
		current_weapon_id = String(defs[current_idx + 1])
