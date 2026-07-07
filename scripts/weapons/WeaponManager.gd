extends Node
class_name WeaponManager

@export var projectile_scene: PackedScene

var run_manager: Node
var current_weapon_id := ""
var temporary_weapon_id := ""
var temporary_weapon_time := 0.0

func setup(run: Node) -> void:
	run_manager = run
	if projectile_scene == null:
		projectile_scene = load("res://scenes/gameplay/Projectile.tscn")
	current_weapon_id = GameManager.get_starting_weapon_id()

func _process(delta: float) -> void:
	if temporary_weapon_time > 0.0:
		temporary_weapon_time -= delta
		if temporary_weapon_time <= 0.0:
			temporary_weapon_id = ""

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
	var weapon: Dictionary = get_weapon_data_for_role(String(soldier.get("role_id")))
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
		var direct_damage: float = _compute_damage(float(weapon.get("damage", 5)))
		if target.has_method("collect") and target.has_method("take_damage"):
			target.take_damage(direct_damage, false)
		else:
			target.take_damage(direct_damage)
		run_manager.ui_manager.spawn_bullet_trail(soldier.global_position + Vector2(0, -28), target.global_position, Color("90f4ff"))
		return
	if auto_fire_enabled and target != null:
		var auto_damage: float = _compute_damage(float(weapon.get("damage", 5)))
		target.take_damage(auto_damage, false)
		run_manager.ui_manager.spawn_bullet_trail(soldier.global_position + Vector2(0, -28), target.global_position, Color("90f4ff"))
		return
	var candidates: Array = run_manager.enemy_manager.get_enemies_sorted_from(soldier.global_position, INF if auto_fire_enabled else float(weapon.get("range", 260)))
	var pierce: int = int(weapon.get("pierce_count", 0))
	var damage: float = _compute_damage(float(weapon.get("damage", 5)))
	var hit_count: int = 0
	for candidate in candidates:
		if hit_count > pierce:
			break
		candidate.take_damage(damage, false)
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
