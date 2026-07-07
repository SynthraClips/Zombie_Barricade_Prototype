extends Node

signal upgrade_purchased(upgrade_id: String)

var upgrade_defs: Dictionary = {}

func initialize_from_data(data: Dictionary) -> void:
	upgrade_defs = data.get("upgrades", {})
	for upgrade_id in upgrade_defs.keys():
		if not SaveManager.save_data["upgrades"].has(upgrade_id):
			SaveManager.save_data["upgrades"][upgrade_id] = 0
	SaveManager.save_game()

func get_level(upgrade_id: String) -> int:
	return int(SaveManager.save_data["upgrades"].get(upgrade_id, 0))

func get_cost(upgrade_id: String) -> int:
	var def: Dictionary = upgrade_defs.get(upgrade_id, {})
	var level: int = get_level(upgrade_id)
	return int(round(float(def.get("cost_base", 10)) * pow(float(def.get("cost_growth", 1.5)), level)))

func can_purchase(upgrade_id: String) -> bool:
	var def: Dictionary = upgrade_defs.get(upgrade_id, {})
	if def.is_empty():
		return false
	return get_level(upgrade_id) < int(def.get("max_level", 1)) and SaveManager.save_data["banked_coins"] >= get_cost(upgrade_id)

func purchase(upgrade_id: String) -> bool:
	if not can_purchase(upgrade_id):
		return false
	var cost: int = get_cost(upgrade_id)
	if not SaveManager.spend_banked_coins(cost):
		return false
	SaveManager.save_data["upgrades"][upgrade_id] = get_level(upgrade_id) + 1
	var def: Dictionary = upgrade_defs.get(upgrade_id, {})
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
