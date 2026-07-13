extends Node
class_name WeaponManager

signal weapon_changed(weapon_id: String)
signal limited_ammo_changed(weapon_id: String, current: int, maximum: int)

@export var projectile_scene: PackedScene

var run_manager: Node
var current_weapon_id := ""
var temporary_weapon_id := ""
var temporary_weapon_time := 0.0
var special_ammo_type := ""
var special_ammo_time := 0.0
var ammo_by_weapon: Dictionary = {}

func setup(run: Node) -> void:
	run_manager = run
	if projectile_scene == null:
		projectile_scene = load("res://scenes/gameplay/Projectile.tscn")
	current_weapon_id = GameManager.get_starting_weapon_id()
	if current_weapon_id == "" or not can_use_weapon(current_weapon_id):
		current_weapon_id = "rifle"
	temporary_weapon_id = ""
	temporary_weapon_time = 0.0
	clear_special_ammo()
	_initialize_limited_ammo()
	weapon_changed.emit(current_weapon_id)

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
	var resolved: String = temporary_weapon_id if temporary_weapon_id != "" else current_weapon_id
	if resolved == "" or not GameManager.weapon_data.has(resolved):
		return "rifle"
	return resolved

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
	var resolved_weapon_id := _weapon_id_for_definition(weapon)
	if bool(weapon.get("limited_ammo", false)) and not _consume_limited_ammo(resolved_weapon_id):
		if resolved_weapon_id == get_current_weapon_id():
			set_active_weapon("rifle")
			run_manager.ui_manager.show_status_message("%s EMPTY - RIFLE EQUIPPED" % String(weapon.get("name", "WEAPON")).to_upper(), Color("ffb36b"))
		return
	if run_manager.is_auto_fire_enabled() and not _is_tesla_weapon(weapon):
		_fire_straight_ahead(soldier, weapon)
		return
	if target == null:
		return
	if _is_tesla_weapon(weapon) and soldier.global_position.distance_to(target.global_position) > get_acquisition_range(weapon, false):
		return
	if bool(weapon.get("hitscan", false)):
		_fire_hitscan(soldier, target, weapon)
		return
	_fire_projectile_style_shot(soldier, target, weapon)

func _fire_straight_ahead(soldier: Node, weapon: Dictionary) -> void:
	var muzzle: Vector2 = soldier.global_position + run_manager.road.get_forward_direction() * 28.0
	var endpoint: Vector2 = muzzle + run_manager.road.get_forward_direction() * max(600.0, float(weapon.get("range", 250.0)))
	if bool(weapon.get("hitscan", false)):
		run_manager.ui_manager.spawn_bullet_trail(muzzle, endpoint, Color("90f4ff"))
		var closest: Node2D
		var closest_distance := INF
		for enemy in run_manager.enemy_manager.enemies:
			if not is_instance_valid(enemy):
				continue
			var forward_distance: float = (enemy.global_position - muzzle).dot(run_manager.road.get_forward_direction())
			if forward_distance > 0.0 and forward_distance < closest_distance and abs(enemy.global_position.x - muzzle.x) <= 18.0:
				closest = enemy
				closest_distance = forward_distance
		if closest != null:
			var damage := _apply_direct_target_damage(closest, weapon, muzzle, Color("90f4ff"))
			_apply_post_hit_effects(weapon, closest, damage)
		return
	if projectile_scene == null:
		return
	var projectile_count: int = maxi(1, int(weapon.get("projectile_count", 1)))
	for index in range(projectile_count):
		var projectile: Node2D = projectile_scene.instantiate()
		run_manager.add_child(projectile)
		projectile.initialize(run_manager, muzzle, endpoint, weapon, 0.0)

func _apply_direct_target_damage(target: Variant, weapon: Dictionary, trail_origin: Vector2, trail_color: Color) -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	var direct_damage: float = get_damage_for_target(weapon, target)
	if target is Enemy:
		_apply_enemy_damage(target, direct_damage)
	elif target.has_method("take_damage"):
		target.take_damage(direct_damage, false)
	run_manager.ui_manager.spawn_bullet_trail(trail_origin, target.global_position, trail_color)
	return direct_damage

func _apply_enemy_damage(enemy: Enemy, damage: float) -> void:
	var resolved_damage: float = damage
	if not is_finite(resolved_damage) or resolved_damage <= 0.0:
		resolved_damage = max(1.0, float(get_current_weapon_data().get("damage", 1.0)))
	enemy.hp -= resolved_damage
	enemy.hit_flash = 1.0
	run_manager.ui_manager.spawn_damage_number(enemy.global_position, resolved_damage)
	AudioManager.play_sfx("zombie_hit")
	if enemy.hp <= 0.0:
		enemy.die()

func _get_extra_enemy_targets(primary_target: Node2D, weapon: Dictionary) -> Array:
	var targets: Array = []
	if primary_target == null or not (primary_target is Enemy):
		return targets
	targets.append(primary_target)
	var extra_hits: int = int(weapon.get("pierce_count", 0))
	if extra_hits <= 0:
		return targets
	if not _is_tesla_weapon(weapon):
		for nearby in run_manager.enemy_manager.get_enemies_sorted_from(primary_target.global_position, float(weapon.get("range", 260.0))):
			if nearby == primary_target or targets.has(nearby):
				continue
			targets.append(nearby)
			if targets.size() >= extra_hits + 1:
				break
		return targets
	var jump_origin: Node2D = primary_target
	var jump_range: float = float(weapon.get("chain_jump_range", weapon.get("range", 260.0)))
	while targets.size() < extra_hits + 1:
		var next_target: Node2D = null
		for nearby in run_manager.enemy_manager.get_enemies_sorted_from(jump_origin.global_position, jump_range):
			if nearby == jump_origin or targets.has(nearby):
				continue
			next_target = nearby
			break
		if next_target == null:
			break
		targets.append(next_target)
		jump_origin = next_target
	return targets

func get_acquisition_range(weapon: Dictionary, auto_fire_enabled: bool) -> float:
	var configured_range: float = max(0.0, float(weapon.get("range", 250.0)) + 40.0)
	if not _is_tesla_weapon(weapon):
		return INF if auto_fire_enabled else configured_range
	return min(configured_range, max(0.0, float(weapon.get("max_effective_range", configured_range))))

func _is_tesla_weapon(weapon: Dictionary) -> bool:
	return String(weapon.get("name", "")) == "Tesla Cannon" or String(weapon.get("vfx_placeholder", "")) == "arc"

func uses_targeted_auto_fire(weapon: Dictionary) -> bool:
	return _is_tesla_weapon(weapon)

func _fire_hitscan(soldier: Node, target: Node2D, weapon: Dictionary) -> void:
	var auto_fire_enabled: bool = run_manager.is_auto_fire_enabled()
	var muzzle_position: Vector2 = soldier.global_position + Vector2(0, -28)
	if not (target is Enemy):
		_apply_direct_target_damage(target, weapon, muzzle_position, Color("90f4ff"))
		return
	var targets: Array = _get_extra_enemy_targets(target, weapon)
	if targets.is_empty():
		targets.append(target)
	for enemy_target in targets:
		var damage: float = _apply_direct_target_damage(enemy_target, weapon, muzzle_position, Color("90f4ff"))
		_apply_post_hit_effects(weapon, enemy_target, damage)
	if auto_fire_enabled:
		return
	if _is_tesla_weapon(weapon):
		return
	var candidates: Array = run_manager.enemy_manager.get_enemies_sorted_from(soldier.global_position, float(weapon.get("range", 260)))
	for candidate in candidates:
		if targets.has(candidate):
			continue
		if targets.size() >= int(weapon.get("pierce_count", 0)) + 1:
			break
		var damage: float = _apply_direct_target_damage(candidate, weapon, muzzle_position, Color("90f4ff"))
		_apply_post_hit_effects(weapon, candidate, damage)

func _fire_projectile_style_shot(soldier: Node, target: Node2D, weapon: Dictionary) -> void:
	var muzzle_position: Vector2 = soldier.global_position + Vector2(0, -28)
	if projectile_scene == null:
		return
	var projectile_count: int = maxi(1, int(weapon.get("projectile_count", 1)))
	var spread: float = float(weapon.get("spread", 0.0))
	for index in range(projectile_count):
		var projectile: Node2D = projectile_scene.instantiate()
		run_manager.add_child(projectile)
		var spread_angle := 0.0
		if projectile_count > 1:
			var spread_ratio: float = float(index) / float(projectile_count - 1)
			spread_angle = lerpf(-spread, spread, spread_ratio)
		elif spread > 0.0:
			spread_angle = randf_range(-spread, spread)
		projectile.initialize(run_manager, muzzle_position, target.global_position, weapon, spread_angle)

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
	if _is_tesla_weapon(weapon):
		damage *= 1.0 + UpgradeManager.get_tree_effect_total("tesla_damage")
	if target is Enemy:
		var target_definition: Dictionary = target.definition
		if String(target_definition.get("category", "zombie")) == "animal":
			damage *= 1.0 + UpgradeManager.get_tree_effect_total("animal_damage")
		if not target.mutation_stat_modifiers.is_empty():
			damage *= 1.0 + UpgradeManager.get_tree_effect_total("evolved_damage")
		if _is_tesla_weapon(weapon):
			damage *= 1.0 - clampf(float(target.mutation_stat_modifiers.get("electrical_resistance", 0.0)), 0.0, 0.75)
	var category: String = _get_target_category(target)
	var resolved_ammo_type: String = String(weapon.get("special_ammo_type", special_ammo_type))
	if resolved_ammo_type == "heavy" and category in ["gate", "armoury_cache", "survivor_rescue", "obstacle"]:
		damage *= get_special_ammo_config(resolved_ammo_type).get("object_damage_multiplier", 1.0)
	return damage

func get_effective_weapon_data_for_role(role_id: String) -> Dictionary:
	var weapon: Dictionary = get_weapon_data_for_role(role_id).duplicate(true)
	var role_def: Dictionary = GameManager.game_config.get("soldier_roles", {}).get(role_id, {})
	weapon["damage"] = float(weapon.get("damage", 0.0)) * float(role_def.get("damage_multiplier", 1.0))
	weapon["fire_rate"] = float(weapon.get("fire_rate", 1.0)) * float(role_def.get("fire_rate_multiplier", 1.0))
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
	if duration_override < 0.0:
		duration *= 1.0 + UpgradeManager.get_upgrade_value("special_ammo_duration")
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
				run_manager.enemy_manager.damage_enemies_in_radius(target.global_position, splash_radius, damage * 0.5)
				run_manager.ui_manager.spawn_explosion(target.global_position, splash_radius)
				AudioManager.play_sfx("explosion")
	match String(weapon.get("status_effect", "")):
		"slow":
			target.apply_slow(float(weapon.get("status_value", 0.35)), float(weapon.get("status_duration", 2.0)))
		"burn":
			target.apply_burn(float(weapon.get("status_value", 2.0)), float(weapon.get("status_duration", 2.0)))
		"armour_break":
			if target.has_method("apply_armour_break"):
				target.apply_armour_break(float(weapon.get("status_value", 0.15)), float(weapon.get("status_duration", 3.0)))

func apply_temporary_weapon(weapon_id: String, duration: float) -> void:
	if not GameManager.weapon_data.has(weapon_id):
		return
	temporary_weapon_id = weapon_id
	temporary_weapon_time = duration

func set_active_weapon(weapon_id: String) -> bool:
	if not can_use_weapon(weapon_id):
		return false
	current_weapon_id = weapon_id
	temporary_weapon_id = ""
	temporary_weapon_time = 0.0
	weapon_changed.emit(weapon_id)
	return true

func can_use_weapon(weapon_id: String) -> bool:
	if not GameManager.weapon_data.has(weapon_id):
		return false
	var definition: Dictionary = GameManager.weapon_data.get(weapon_id, {})
	if bool(definition.get("upgrade_only", false)):
		return UpgradeManager.has_tree_effect("tesla_unlock") or SaveManager.save_data.get("weapon_inventory", []).has(weapon_id)
	return true

func get_collectible_weapon_ids(progress: float = 0.0, exclude_current: bool = true) -> Array[String]:
	var candidates: Array[String] = []
	for weapon_id_variant in GameManager.weapon_data.keys():
		var weapon_id := String(weapon_id_variant)
		var definition: Dictionary = GameManager.weapon_data[weapon_id]
		if not bool(definition.get("collectible", false)) or bool(definition.get("upgrade_only", false)):
			continue
		if exclude_current and weapon_id == get_current_weapon_id():
			continue
		var min_progress: float = float(definition.get("min_progress", 0.0))
		if progress < min_progress:
			continue
		candidates.append(weapon_id)
	return candidates

func choose_weighted_weapon(progress: float = 0.0, excluded: Array = []) -> String:
	var candidates := get_collectible_weapon_ids(progress, false)
	for excluded_id in excluded:
		candidates.erase(String(excluded_id))
	if candidates.is_empty():
		return "rifle"
	var rarity_bonus: float = UpgradeManager.get_upgrade_value("loot_rarity_bonus") + (run_manager.get_route_rarity_bonus() if run_manager != null else 0.0)
	var total := 0.0
	for weapon_id in candidates:
		var definition: Dictionary = GameManager.weapon_data[weapon_id]
		var weight: float = maxf(0.01, float(definition.get("pickup_weight", 1.0)))
		if String(definition.get("rarity", "common")) in ["rare", "legendary"]:
			weight *= 1.0 + rarity_bonus * 4.0
		total += weight
	var roll := randf() * total
	for weapon_id in candidates:
		var definition: Dictionary = GameManager.weapon_data[weapon_id]
		var weight: float = maxf(0.01, float(definition.get("pickup_weight", 1.0)))
		if String(definition.get("rarity", "common")) in ["rare", "legendary"]:
			weight *= 1.0 + rarity_bonus * 4.0
		roll -= weight
		if roll <= 0.0:
			return weapon_id
	return candidates.back()

func refill_limited_ammo(amount: int, weapon_id: String = "tesla_cannon") -> int:
	if not GameManager.weapon_data.has(weapon_id) or not bool(GameManager.weapon_data[weapon_id].get("limited_ammo", false)):
		return 0
	var before := int(ammo_by_weapon.get(weapon_id, 0))
	var maximum := get_max_ammo(weapon_id)
	ammo_by_weapon[weapon_id] = clampi(before + max(amount, 0), 0, maximum)
	limited_ammo_changed.emit(weapon_id, int(ammo_by_weapon[weapon_id]), maximum)
	return int(ammo_by_weapon[weapon_id]) - before

func get_limited_ammo_state(weapon_id: String = "") -> Dictionary:
	var resolved_id := weapon_id if weapon_id != "" else get_current_weapon_id()
	var definition: Dictionary = GameManager.weapon_data.get(resolved_id, {})
	if not bool(definition.get("limited_ammo", false)):
		return {"weapon_id":"", "current":0, "maximum":0, "label":""}
	return {"weapon_id":resolved_id, "current":int(ammo_by_weapon.get(resolved_id, 0)), "maximum":get_max_ammo(resolved_id), "label":String(definition.get("name", resolved_id))}

func get_max_ammo(weapon_id: String) -> int:
	var base := int(GameManager.weapon_data.get(weapon_id, {}).get("max_ammo", 0))
	if weapon_id == "tesla_cannon":
		base += int(round(UpgradeManager.get_tree_effect_total("tesla_max_ammo")))
	return max(base, 0)

func _initialize_limited_ammo() -> void:
	ammo_by_weapon.clear()
	for weapon_id_variant in GameManager.weapon_data.keys():
		var weapon_id := String(weapon_id_variant)
		if bool(GameManager.weapon_data[weapon_id].get("limited_ammo", false)):
			ammo_by_weapon[weapon_id] = get_max_ammo(weapon_id) if weapon_id == current_weapon_id else 0

func _consume_limited_ammo(weapon_id: String) -> bool:
	var current := int(ammo_by_weapon.get(weapon_id, 0))
	if current <= 0:
		return false
	if weapon_id == "tesla_cannon" and randf() < UpgradeManager.get_tree_effect_total("tesla_efficiency"):
		return true
	ammo_by_weapon[weapon_id] = max(0, current - 1)
	limited_ammo_changed.emit(weapon_id, int(ammo_by_weapon[weapon_id]), get_max_ammo(weapon_id))
	return true

func _weapon_id_for_definition(weapon: Dictionary) -> String:
	for weapon_id_variant in GameManager.weapon_data.keys():
		var weapon_id := String(weapon_id_variant)
		if String(GameManager.weapon_data[weapon_id].get("name", "")) == String(weapon.get("name", "")):
			return weapon_id
	return get_current_weapon_id()

func unlock_next_weapon() -> void:
	var defs: Array = GameManager.upgrade_data.get("upgrades", {}).get("starting_weapon", {}).get("choices", [])
	var current_idx: int = defs.find(current_weapon_id)
	if current_idx < defs.size() - 1:
		current_weapon_id = String(defs[current_idx + 1])
