extends Node

signal upgrade_purchased(upgrade_id: String)
signal tree_upgrade_purchased(upgrade_id: String)
signal progression_synchronized

var upgrade_defs: Dictionary = {}
var tree_defs: Dictionary = {}
var tree_nodes_by_id: Dictionary = {}
var validation_errors: Array[String] = []
var purchase_in_progress := false

func initialize_from_data(data: Dictionary) -> void:
	upgrade_defs = data.get("upgrades", {})
	_load_tree_definitions()
	for upgrade_id in upgrade_defs.keys():
		if not SaveManager.save_data["upgrades"].has(upgrade_id):
			SaveManager.save_data["upgrades"][upgrade_id] = 0
	synchronize_loaded_save()

func _load_tree_definitions() -> void:
	var file := FileAccess.open("res://data/safehouse_upgrade_tree.json", FileAccess.READ)
	if file == null:
		validation_errors = ["Missing safehouse upgrade tree definitions."]
		push_error(validation_errors[0])
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		validation_errors = ["Safehouse upgrade tree JSON could not be parsed."]
		push_error(validation_errors[0])
		return
	tree_defs = parsed
	validation_errors = SafehouseUpgradeTree.validate(tree_defs)
	tree_nodes_by_id.clear()
	for node in tree_defs.get("nodes", []):
		if node is Dictionary:
			tree_nodes_by_id[String(node.get("id", ""))] = node
	for error in validation_errors:
		push_error("Safehouse upgrade tree: %s" % error)

func synchronize_loaded_save() -> void:
	if tree_defs.is_empty():
		return
	if not SaveManager.save_data.has("permanent_upgrade_ids"):
		SaveManager.save_data["permanent_upgrade_ids"] = []
	var owned: Array = SaveManager.save_data.get("permanent_upgrade_ids", [])
	var changed := false
	for node in tree_defs.get("nodes", []):
		if not node is Dictionary:
			continue
		var node_id: String = String(node.get("id", ""))
		for legacy_id in node.get("legacy_ids", []):
			if int(SaveManager.save_data.get("upgrades", {}).get(String(legacy_id), 0)) > 0 and not owned.has(node_id):
				owned.append(node_id)
				changed = true
	for owned_id in owned:
		if not tree_nodes_by_id.has(String(owned_id)):
			push_warning("Ignoring obsolete permanent upgrade id: %s" % owned_id)
	SaveManager.save_data["permanent_upgrade_ids"] = owned
	SaveManager.save_data["upgrade_tree_version"] = int(tree_defs.get("tree_version", 1))
	if changed:
		print("Migrated legacy permanent upgrades to stable Safehouse tree IDs.")
		SaveManager.save_game()
	progression_synchronized.emit()

func get_level(upgrade_id: String) -> int:
	return max(0, int(SaveManager.save_data["upgrades"].get(upgrade_id, 0)))

func get_cost(upgrade_id: String) -> int:
	var def: Dictionary = upgrade_defs.get(upgrade_id, {})
	var level: int = get_level(upgrade_id)
	return max(0, int(round(float(def.get("cost_base", 10)) * pow(float(def.get("cost_growth", 1.5)), level))))

func can_purchase(upgrade_id: String) -> bool:
	var def: Dictionary = upgrade_defs.get(upgrade_id, {})
	if def.is_empty():
		return false
	return get_level(upgrade_id) < int(def.get("max_level", 1)) and SaveManager.save_data["banked_coins"] >= get_cost(upgrade_id)

func purchase(upgrade_id: String) -> bool:
	if not can_purchase(upgrade_id):
		return false
	var def: Dictionary = upgrade_defs.get(upgrade_id, {})
	var cost: int = get_cost(upgrade_id)
	if not SaveManager.spend_banked_coins(cost):
		return false
	SaveManager.save_data["upgrades"][upgrade_id] = min(get_level(upgrade_id) + 1, int(def.get("max_level", 1)))
	if def.get("type", "") == "choice":
		var choices: Array = def.get("choices", [])
		var idx: int = min(get_level(upgrade_id), max(choices.size() - 1, 0))
		SaveManager.save_data["upgrade_choices"][upgrade_id] = String(choices[idx])
		if upgrade_id == "starting_barricade_tier" and SaveManager.save_data["upgrade_choices"][upgrade_id] == "metal_wall":
			MissionManager.increment_progress("unlock_barricade", 1)
	SaveManager.save_game()
	upgrade_purchased.emit(upgrade_id)
	AudioManager.play_sfx("upgrade_purchased")
	return true

func get_tree_definition(upgrade_id: String) -> Dictionary:
	return tree_nodes_by_id.get(upgrade_id, {})

func get_owned_tree_ids() -> Array:
	return SaveManager.save_data.get("permanent_upgrade_ids", []).duplicate()

func is_tree_upgrade_owned(upgrade_id: String) -> bool:
	return SaveManager.save_data.get("permanent_upgrade_ids", []).has(upgrade_id)

func are_tree_prerequisites_met(upgrade_id: String) -> bool:
	var definition := get_tree_definition(upgrade_id)
	if definition.is_empty():
		return false
	for prerequisite in definition.get("prerequisite_ids", []):
		if not is_tree_upgrade_owned(String(prerequisite)):
			return false
	return true

func can_purchase_tree_upgrade(upgrade_id: String) -> bool:
	if purchase_in_progress or not validation_errors.is_empty():
		return false
	var definition := get_tree_definition(upgrade_id)
	if definition.is_empty() or not bool(definition.get("enabled", false)):
		return false
	if is_tree_upgrade_owned(upgrade_id) or not are_tree_prerequisites_met(upgrade_id):
		return false
	return _requirements_met(definition) and SaveManager.can_afford_resources(get_tree_costs(upgrade_id))

func purchase_tree_upgrade(upgrade_id: String) -> bool:
	if not can_purchase_tree_upgrade(upgrade_id):
		return false
	purchase_in_progress = true
	var snapshot: Dictionary = SaveManager.save_data.duplicate(true)
	var definition := get_tree_definition(upgrade_id)
	var costs := get_tree_costs(upgrade_id)
	if not SaveManager.spend_resources(costs, false):
		purchase_in_progress = false
		return false
	var owned: Array = SaveManager.save_data.get("permanent_upgrade_ids", [])
	owned.append(upgrade_id)
	SaveManager.save_data["permanent_upgrade_ids"] = owned
	_apply_tree_effect_to_legacy_progression(definition)
	var saved := SaveManager.save_game()
	if not saved:
		SaveManager.save_data = snapshot
		# Restore the last coherent project save if the failed write opened and
		# truncated the target before reporting its error.
		SaveManager.save_game()
		purchase_in_progress = false
		push_error("Safehouse upgrade purchase rolled back because saving failed: %s" % upgrade_id)
		return false
	purchase_in_progress = false
	tree_upgrade_purchased.emit(upgrade_id)
	upgrade_purchased.emit(upgrade_id)
	AudioManager.play_sfx("upgrade_purchased")
	return true

func _apply_tree_effect_to_legacy_progression(definition: Dictionary) -> void:
	_apply_single_tree_effect(String(definition.get("effect_type", "")), definition.get("effect_value"))
	for extra_effect in definition.get("additional_effects", []):
		if extra_effect is Dictionary:
			_apply_single_tree_effect(String(extra_effect.get("effect_type", "")), extra_effect.get("effect_value"))

func _apply_single_tree_effect(effect_type: String, effect_value: Variant) -> void:
	if effect_type == "hero_unlock":
		var heroes: Dictionary = SaveManager.save_data.get("heroes", {})
		var unlocked: Array = heroes.get("unlocked", [])
		if not unlocked.has(String(effect_value)):
			unlocked.append(String(effect_value))
		heroes["unlocked"] = unlocked
		SaveManager.save_data["heroes"] = heroes
		return
	if effect_type in ["weapon_unlock", "tesla_unlock"]:
		var weapon_id := String(effect_value) if effect_type == "weapon_unlock" else "tesla_cannon"
		var inventory: Array = SaveManager.save_data.get("weapon_inventory", ["rifle"])
		if not inventory.has(weapon_id):
			inventory.append(weapon_id)
		SaveManager.save_data["weapon_inventory"] = inventory
		return
	if not upgrade_defs.has(effect_type):
		return
	var old_definition: Dictionary = upgrade_defs[effect_type]
	if String(old_definition.get("type", "")) == "choice":
		SaveManager.save_data["upgrades"][effect_type] = max(1, int(SaveManager.save_data["upgrades"].get(effect_type, 0)))
		SaveManager.save_data["upgrade_choices"][effect_type] = String(effect_value)
		return
	SaveManager.save_data["upgrades"][effect_type] = min(
		int(SaveManager.save_data["upgrades"].get(effect_type, 0)) + 1,
		int(old_definition.get("max_level", 1))
	)

func get_tree_node_state(upgrade_id: String) -> String:
	var definition := get_tree_definition(upgrade_id)
	if definition.is_empty() or not bool(definition.get("enabled", false)):
		return "disabled"
	if is_tree_upgrade_owned(upgrade_id):
		return "purchased"
	if not are_tree_prerequisites_met(upgrade_id):
		return "locked"
	if not _requirements_met(definition):
		return "locked"
	if not SaveManager.can_afford_resources(get_tree_costs(upgrade_id)):
		return "unaffordable"
	return "available"

func get_tree_costs(upgrade_id: String) -> Dictionary:
	var definition := get_tree_definition(upgrade_id)
	var costs: Dictionary = definition.get("costs", {}).duplicate(true)
	if costs.is_empty():
		costs["coins"] = max(0, int(definition.get("cost", 0)))
	return {
		"coins": max(0, int(costs.get("coins", 0))),
		"supplies": max(0, int(costs.get("supplies", 0))),
		"survivors": max(0, int(costs.get("survivors", 0)))
	}

func format_tree_cost(upgrade_id: String) -> String:
	var costs := get_tree_costs(upgrade_id)
	var parts: Array[String] = []
	for resource_id in ["coins", "supplies", "survivors"]:
		var amount := int(costs.get(resource_id, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, resource_id.capitalize()])
	return "Free" if parts.is_empty() else " + ".join(parts)

func has_tree_effect(effect_type: String, effect_value: Variant = null) -> bool:
	for upgrade_id in get_owned_tree_ids():
		var definition := get_tree_definition(String(upgrade_id))
		if String(definition.get("effect_type", "")) != effect_type:
			for extra_effect in definition.get("additional_effects", []):
				if extra_effect is Dictionary and String(extra_effect.get("effect_type", "")) == effect_type and (effect_value == null or extra_effect.get("effect_value") == effect_value):
					return true
			continue
		if effect_value == null or definition.get("effect_value") == effect_value:
			return true
	return false

func get_tree_effect_total(effect_type: String) -> float:
	var total := 0.0
	for upgrade_id in get_owned_tree_ids():
		var definition := get_tree_definition(String(upgrade_id))
		if String(definition.get("effect_type", "")) == effect_type:
			total += float(definition.get("effect_value", 0.0))
		for extra_effect in definition.get("additional_effects", []):
			if extra_effect is Dictionary and String(extra_effect.get("effect_type", "")) == effect_type:
				total += float(extra_effect.get("effect_value", 0.0))
	return total

func _requirements_met(definition: Dictionary) -> bool:
	var requirements: Dictionary = definition.get("requirements", {})
	if int(SaveManager.save_data.get("survivors", 0)) < int(requirements.get("survivor_count", 0)):
		return false
	var defeated: Array = SaveManager.save_data.get("defeated_boss_ids", [])
	for boss_id in requirements.get("boss_defeats", []):
		if not defeated.has(String(boss_id)):
			return false
	var discovered: Array = SaveManager.save_data.get("discovered_mutations", [])
	for mutation_id in requirements.get("mutation_research", []):
		if not discovered.has(String(mutation_id)):
			return false
	return true

func get_upgrade_value(upgrade_id: String) -> float:
	var def: Dictionary = upgrade_defs.get(upgrade_id, {})
	var level: int = get_level(upgrade_id)
	if def.get("type", "") == "flat":
		return float(def.get("base", 0.0)) + float(def.get("per_level", 0.0)) * level
	if def.get("type", "") == "multiplier":
		return float(def.get("base", 0.0)) + float(def.get("per_level", 0.0)) * level
	return 0.0

func get_choice_value(upgrade_id: String) -> String:
	return String(SaveManager.save_data["upgrade_choices"].get(upgrade_id, ""))

func get_max_level(upgrade_id: String) -> int:
	return int(upgrade_defs.get(upgrade_id, {}).get("max_level", 1))

func is_maxed(upgrade_id: String) -> bool:
	return get_level(upgrade_id) >= get_max_level(upgrade_id)

func get_display_name(upgrade_id: String) -> String:
	var def: Dictionary = upgrade_defs.get(upgrade_id, {})
	return String(def.get("title", upgrade_id.replace("_", " ").capitalize()))
