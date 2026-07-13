extends RefCounted
class_name SafehouseUpgradeTree

const VALID_EFFECT_TYPES := [
	"soldier_damage", "fire_rate", "critical_chance", "starting_soldiers",
	"starting_support_role", "route_reward_bonus", "barricade_hp",
	"barricade_cooldown", "barricade_repair", "barricade_auto_repair",
	"coin_gain", "pickup_magnet", "loot_rarity_bonus", "hero_duration",
	"hero_cooldown", "hero_power", "report_reward_bonus", "special_ammo_duration", "starting_weapon",
	"starting_barricade_tier"
]

static func validate(definitions: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var nodes: Array = definitions.get("nodes", [])
	var ids: Dictionary = {}
	var legacy_ids: Dictionary = {}
	for raw_node in nodes:
		if not raw_node is Dictionary:
			errors.append("Upgrade node is not a dictionary.")
			continue
		var node: Dictionary = raw_node
		var id: String = String(node.get("id", ""))
		if id.is_empty():
			errors.append("Upgrade node has an empty id.")
		elif ids.has(id):
			errors.append("Duplicate upgrade id: %s" % id)
		ids[id] = true
		if int(node.get("cost", -1)) < 0:
			errors.append("Negative cost: %s" % id)
		if not VALID_EFFECT_TYPES.has(String(node.get("effect_type", ""))):
			errors.append("Unknown effect type for %s: %s" % [id, node.get("effect_type", "")])
		if not node.has("enabled"):
			errors.append("Missing enabled flag: %s" % id)
		var icon_path: String = String(node.get("icon", ""))
		if not icon_path.is_empty() and not ResourceLoader.exists(icon_path):
			errors.append("Missing icon for %s: %s" % [id, icon_path])
		for legacy_id in node.get("legacy_ids", []):
			var legacy: String = String(legacy_id)
			if legacy_ids.has(legacy):
				errors.append("Legacy id collision: %s" % legacy)
			legacy_ids[legacy] = id
	for raw_node in nodes:
		if not raw_node is Dictionary:
			continue
		var node: Dictionary = raw_node
		for prerequisite in node.get("prerequisite_ids", []):
			if not ids.has(String(prerequisite)):
				errors.append("Missing prerequisite for %s: %s" % [node.get("id", ""), prerequisite])
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	var by_id: Dictionary = {}
	for raw_node in nodes:
		if raw_node is Dictionary:
			by_id[String(raw_node.get("id", ""))] = raw_node
	for id in by_id:
		_detect_cycle(String(id), by_id, visiting, visited, errors)
	return errors

static func validate_yggdrasil_tree(tree: YggdrasilTree, definitions: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if tree == null:
		return ["Registered Yggdrasil tree could not be loaded."]
	var definitions_by_id: Dictionary = {}
	for definition in definitions.get("nodes", []):
		if definition is Dictionary and bool(definition.get("enabled", false)):
			definitions_by_id[String(definition.get("id", ""))] = definition
	var stable_to_node: Dictionary = {}
	var numeric_to_stable: Dictionary = {}
	var root_count := 0
	for node: YggdrasilNode in tree.nodes:
		var stable_id := get_stable_id(node)
		if node.is_root:
			root_count += 1
		if stable_id.is_empty():
			errors.append("Yggdrasil node %d lacks a stable upgrade ID." % node.id)
			continue
		if stable_to_node.has(stable_id):
			errors.append("Duplicate Yggdrasil stable upgrade ID: %s" % stable_id)
		stable_to_node[stable_id] = node
		numeric_to_stable[node.id] = stable_id
		if stable_id != "safehouse_root" and not definitions_by_id.has(stable_id):
			errors.append("Yggdrasil node references unknown upgrade ID: %s" % stable_id)
	if root_count == 0:
		errors.append("Yggdrasil tree has no root node.")
	for upgrade_id in definitions_by_id:
		if not stable_to_node.has(upgrade_id):
			errors.append("Enabled upgrade lacks a Yggdrasil node: %s" % upgrade_id)
		continue
		var node: YggdrasilNode = stable_to_node[upgrade_id]
		var actual_prerequisites: Array[String] = []
		for numeric_id in node.in_nodes:
			var incoming_id: String = String(numeric_to_stable.get(int(numeric_id), ""))
			if incoming_id != "" and incoming_id != "safehouse_root":
				actual_prerequisites.append(incoming_id)
		actual_prerequisites.sort()
		var expected_prerequisites: Array[String] = []
		for prerequisite in definitions_by_id[upgrade_id].get("prerequisite_ids", []):
			expected_prerequisites.append(String(prerequisite))
		expected_prerequisites.sort()
		if actual_prerequisites != expected_prerequisites:
			errors.append("Yggdrasil connections disagree with prerequisites for %s: expected %s, found %s" % [upgrade_id, expected_prerequisites, actual_prerequisites])
	return errors

static func get_stable_id(node: YggdrasilNode) -> String:
	# Yggdrasil owns external_id and rewrites it to the editor-facing node ID
	# when a tree is saved. The project-owned stable ID must therefore come
	# from the dedicated attribute so editor layout edits cannot break saves.
	var values: Array = node.attributes.get("stable_upgrade_id", [])
	if not values.is_empty():
		return String(values[0])
	return String(node.external_id)

static func _detect_cycle(id: String, by_id: Dictionary, visiting: Dictionary, visited: Dictionary, errors: Array[String]) -> void:
	if visited.has(id):
		return
	if visiting.has(id):
		errors.append("Circular prerequisite chain includes: %s" % id)
		return
	visiting[id] = true
	for prerequisite in by_id.get(id, {}).get("prerequisite_ids", []):
		_detect_cycle(String(prerequisite), by_id, visiting, visited, errors)
	visiting.erase(id)
	visited[id] = true
