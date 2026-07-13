extends Node2D
class_name RewardManager

@export var reward_scene: PackedScene

var run_manager: Node
var rewards: Array[Node] = []
var last_collected_reward: Dictionary = {}

func setup(run: Node) -> void:
	run_manager = run
	if reward_scene == null:
		reward_scene = load("res://scenes/gameplay/RewardPickup.tscn")
	for child in get_children():
		child.queue_free()
	rewards.clear()
	last_collected_reward = {}

func update_rewards(delta: float) -> void:
	rewards = rewards.filter(func(item): return is_instance_valid(item))
	for reward in rewards:
		if not is_instance_valid(reward):
			continue
		var anchor_position: Vector2 = run_manager.squad_manager.get_anchor_position()
		var collect_radius: float = float(GameManager.game_config.get("pickup_collect_radius", 72.0))
		if reward.global_position.distance_to(anchor_position) <= collect_radius:
			reward.collect()

func spawn_reward(reward_id: String, world_position: Vector2) -> void:
	var resolved_reward_id := _resolve_spawn_reward_id(reward_id)
	var collect_radius: float = float(GameManager.game_config.get("pickup_collect_radius", 72.0))
	if world_position.distance_to(run_manager.squad_manager.get_anchor_position()) <= collect_radius:
		collect_reward(resolved_reward_id)
		return
	var reward: Node = reward_scene.instantiate()
	add_child(reward)
	reward.initialize(run_manager, resolved_reward_id, world_position)
	rewards.append(reward)

func unregister_reward(reward: Node) -> void:
	rewards.erase(reward)

func collect_reward(reward_id: String) -> void:
	run_manager.register_pickup_collected(reward_id)
	last_collected_reward = apply_reward_by_id(reward_id)
	print("Collected reward: %s" % last_collected_reward)

func apply_reward_by_id(reward_id: String) -> Dictionary:
	var reward_def: Dictionary = get_reward_definition(reward_id)
	var gate_compatible_type: String = String(reward_def.get("type", "coins"))
	if gate_compatible_type == "add_soldier":
		gate_compatible_type = "add_soldiers"
	var normalized_def: Dictionary = reward_def.duplicate(true)
	if gate_compatible_type == "add_soldiers" and bool(GameManager.game_config.get("allow_pickup_soldier_overcap", false)):
		normalized_def["allow_overcap"] = true
		normalized_def["overcap_limit"] = int(GameManager.game_config.get("pickup_soldier_overcap_limit", 0))
	normalized_def["reward_id"] = reward_id
	return apply_reward_effect(gate_compatible_type, normalized_def)

func apply_reward_effect(reward_type: String, reward_def: Dictionary) -> Dictionary:
	var normalized_type: String = reward_type
	if normalized_type == "add_soldier":
		normalized_type = "add_soldiers"
	var value = reward_def.get("value", 0)
	var label: String = String(reward_def.get("label", normalized_type)).to_upper()
	var color := Color(reward_def.get("color", "#ffffff"))
	var rarity_label: String = String(reward_def.get("rarity", "common")).capitalize()
	var result := {
		"type": normalized_type,
		"value": value,
		"popup": label,
		"color": color,
		"delta": 0,
		"rarity": rarity_label
	}
	match normalized_type:
		"coins":
			var coins_added: int = run_manager.add_coins(int(value))
			if coins_added <= 0 and int(value) > 0:
				run_manager.coins += int(value)
				run_manager.run_stats["coins_earned"] += int(value)
				run_manager.coins_changed.emit(run_manager.coins)
				coins_added = int(value)
			SaveManager.save_data["stats"]["coins_collected"] += coins_added
			MissionManager.increment_progress("coins_collected", coins_added)
			result["applied"] = coins_added
			result["delta"] = coins_added
			result["popup"] = "+%d COINS" % coins_added
		"supplies":
			var supplies_added: int = run_manager.add_supplies(int(value))
			result["applied"] = supplies_added
			result["delta"] = supplies_added
			result["popup"] = "+%d SUPPLIES" % supplies_added
		"survivors":
			var survivors_added: int = run_manager.add_survivors(int(value))
			result["applied"] = survivors_added
			result["delta"] = survivors_added
			result["popup"] = "+%d SURVIVORS" % survivors_added
		"add_soldiers":
			var added: int = run_manager.squad_manager.add_soldiers(
				int(value),
				bool(reward_def.get("allow_overcap", false)),
				int(reward_def.get("overcap_limit", -1))
			)
			result["applied"] = added
			result["delta"] = added
			result["popup"] = "+%d SOLDIERS" % added
		"add_role_soldier":
			var role_id: String = String(reward_def.get("role_id", "rifleman"))
			var role_added: int = run_manager.squad_manager.add_role_soldiers(
				role_id,
				int(value),
				bool(reward_def.get("allow_overcap", false)),
				int(reward_def.get("overcap_limit", -1))
			)
			result["applied"] = role_added
			result["delta"] = role_added
			result["popup"] = "+%d %s" % [role_added, role_id.replace("_", " ").to_upper()]
		"remove_soldiers":
			var removed: int = run_manager.squad_manager.remove_soldiers(int(value))
			result["applied"] = removed
			result["delta"] = -removed
			result["popup"] = "-%d SOLDIERS" % removed
		"multiply_soldiers":
			var gained: int = run_manager.squad_manager.multiply_soldiers(int(value))
			result["applied"] = gained
			result["delta"] = gained
			result["popup"] = "x%d SQUAD" % int(value)
		"fire_rate_boost", "damage_boost", "temporary_shield":
			var boost_value: float = float(value)
			run_manager.squad_manager.apply_reward_boost(normalized_type, boost_value)
			result["applied"] = boost_value
			if normalized_type == "temporary_shield":
				result["popup"] = "+%d SHIELD" % int(round(boost_value))
			else:
				result["popup"] = "+%d%% %s" % [int(round(boost_value * 100.0)), "FIRE RATE" if normalized_type == "fire_rate_boost" else "DAMAGE"]
		"extend_distance":
			var distance_added: int = int(value)
			run_manager.extend_target_distance(distance_added)
			result["applied"] = distance_added
			result["popup"] = "+%dM ROUTE" % distance_added
		"heal_soldiers":
			var healed: int = run_manager.squad_manager.heal_soldiers(int(value))
			result["applied"] = healed
			result["delta"] = healed
			result["popup"] = "MEDICAL +%d" % healed
		"barricade_repair":
			var repaired: float = run_manager.barricade_manager.repair_active_barricade(float(value))
			result["applied"] = repaired
			result["popup"] = "+%d BARRICADE HP" % int(round(repaired))
		"barricade_cooldown_reset":
			run_manager.barricade_manager.reset_cooldown()
			result["applied"] = 1
			result["popup"] = "BARRICADE READY"
		"weapon_pickup":
			var weapon_id: String = String(reward_def.get("weapon_id", ""))
			if weapon_id == "":
				weapon_id = run_manager.weapon_manager.choose_weighted_weapon(run_manager.distance_travelled / max(run_manager.target_distance, 1.0), [run_manager.weapon_manager.get_current_weapon_id()])
			if bool(GameManager.weapon_data.get(weapon_id, {}).get("limited_ammo", false)):
				run_manager.weapon_manager.refill_limited_ammo(run_manager.weapon_manager.get_max_ammo(weapon_id), weapon_id)
			var equipped: bool = run_manager.weapon_manager.set_active_weapon(weapon_id)
			result["applied"] = weapon_id if equipped else ""
			result["popup"] = "%s EQUIPPED" % String(GameManager.weapon_data.get(weapon_id, {}).get("name", weapon_id)).to_upper()
		"tesla_ammo":
			var ammo_added: int = run_manager.weapon_manager.refill_limited_ammo(int(value), "tesla_cannon")
			result["applied"] = ammo_added
			result["delta"] = ammo_added
			result["popup"] = "+%d TESLA AMMO" % ammo_added
		"night_section":
			var started: bool = run_manager.road.request_night_section()
			result["applied"] = started
			result["popup"] = "NIGHT ROUTE" if started else "NIGHT ALREADY ACTIVE"
		"hero_cooldown":
			run_manager.hero_cooldown_remaining = max(0.0, run_manager.hero_cooldown_remaining - float(value))
			result["applied"] = value
			result["popup"] = "HERO COOLDOWN -%ds" % int(value)
		"hero_duration_gate":
			if run_manager.hero_active:
				run_manager.hero_time_remaining += float(value)
			result["applied"] = value
			result["popup"] = "HERO DURATION +%ds" % int(value)
		"special_ammo":
			var ammo_type: String = String(reward_def.get("ammo_type", ""))
			var duration: float = float(reward_def.get("duration", -1.0))
			var applied: bool = run_manager.weapon_manager.apply_special_ammo(ammo_type, duration)
			result["applied"] = applied
			result["popup"] = String(reward_def.get("label", ammo_type)).to_upper()
		"unlock_specialist":
			var specialist_id: String = String(reward_def.get("specialist_id", ""))
			var unlocked_specialist: bool = run_manager.unlock_specialist(specialist_id)
			result["applied"] = unlocked_specialist
			result["popup"] = String(reward_def.get("label", "SPECIALIST")).to_upper()
		"risk_gate":
			var nested_reward := {
				"type": String(reward_def.get("reward_type", "add_soldiers")),
				"value": reward_def.get("reward_value", value),
				"label": reward_def.get("label", "Risk Gate"),
				"color": reward_def.get("color", "#ff7d7d")
			}
			var nested_result: Dictionary = apply_reward_effect(String(nested_reward.get("type", "add_soldiers")), nested_reward)
			var boss_pool: Array = reward_def.get("boss_pool", [])
			if not boss_pool.is_empty():
				var boss_started: bool = run_manager.wave_spawner.try_spawn_event_boss(boss_pool, "GATE CHALLENGE")
				if not boss_started:
					run_manager.wave_spawner.trigger_alarm_wave({"alarm_spawn_count": 5, "alarm_spawn_pool": ["armoured_walker", "mutated_boar", "runner"]}, Vector2(run_manager.road.get_center_x(), run_manager.road.get_spawn_y()))
				run_manager.ui_manager.show_status_message("OPTIONAL BOSS INCOMING" if boss_started else "ELITE FALLBACK HORDE", Color("ff6b6b"))
			else:
				var spawn_count: int = int(reward_def.get("spawn_enemy_count", 2))
				var spawn_pool: Array = reward_def.get("spawn_pool", ["runner", "exploder"])
				for index in range(spawn_count):
					var enemy_id: String = String(spawn_pool[index % max(1, spawn_pool.size())])
					var spawn_x: float = run_manager.road.get_random_lane_x(run_manager.road.get_spawn_y(), 64.0)
					run_manager.enemy_manager.spawn_enemy(enemy_id, Vector2(spawn_x, run_manager.road.get_spawn_y()), run_manager.get_difficulty_multiplier())
				run_manager.ui_manager.show_status_message("RISK HORDE INCOMING", Color("ff6b6b"))
			result["applied"] = nested_result.get("applied", 0)
			result["delta"] = nested_result.get("delta", 0)
			result["popup"] = "%s / %s" % [String(nested_result.get("popup", "RISK")), "BOSS" if not boss_pool.is_empty() else "HORDE"]
	AudioManager.play_sfx("reward_pickup")
	if rarity_label in ["Rare", "Military", "Legendary"]:
		result["popup"] = "%s | %s" % [rarity_label.to_upper(), String(result.get("popup", label))]
	last_collected_reward = result.duplicate(true)
	return result

func get_reward_definition(reward_id: String) -> Dictionary:
	if reward_id.begins_with("weapon::"):
		var weapon_id := reward_id.trim_prefix("weapon::")
		var weapon: Dictionary = GameManager.weapon_data.get(weapon_id, {})
		return {
			"type":"weapon_pickup", "weapon_id":weapon_id,
			"value":1, "rarity":String(weapon.get("rarity", "common")),
			"color":"#d9a8ff", "label":String(weapon.get("name", weapon_id)),
			"icon":String(weapon.get("icon", ""))
		}
	return GameManager.reward_data.get("rewards", {}).get(reward_id, {})

func _resolve_spawn_reward_id(reward_id: String) -> String:
	if reward_id == "ammo_cache" and not UpgradeManager.has_tree_effect("tesla_unlock"):
		return "supplies_small"
	if reward_id != "weapon_pickup" and reward_id != "armoury_weapon_drop":
		return reward_id
	var weapon_id: String = run_manager.weapon_manager.choose_weighted_weapon(run_manager.distance_travelled / max(run_manager.target_distance, 1.0), [run_manager.weapon_manager.get_current_weapon_id()])
	return "weapon::%s" % weapon_id
