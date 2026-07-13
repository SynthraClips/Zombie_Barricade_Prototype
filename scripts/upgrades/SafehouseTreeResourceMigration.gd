extends Node

const REGISTRY_PATH := "res://yggdrasil/registry.tres"
const GROUP_DIR := "res://yggdrasil/Small Game"
const GROUP_PATH := GROUP_DIR + "/small_game.tres"
const TREE_PATH := GROUP_DIR + "/safehouse_upgrade_tree.tres"
const CONFIRM_FLAG := "--confirm-yggdrasil-migration-overwrite"

func _ready() -> void:
	call_deferred("_migrate")

func _migrate() -> void:
	var definitions := _load_definitions()
	if definitions.is_empty():
		_fail("Could not load data/safehouse_upgrade_tree.json")
		return
	if FileAccess.file_exists(TREE_PATH):
		var existing: YggdrasilTree = ResourceLoader.load(TREE_PATH, "YggdrasilTree", ResourceLoader.CACHE_MODE_IGNORE)
		if existing != null and not existing.nodes.is_empty() and not OS.get_cmdline_user_args().has(CONFIRM_FLAG):
			_fail("Refusing to overwrite populated %s without %s" % [TREE_PATH, CONFIRM_FLAG])
			return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GROUP_DIR))
	var tree := _build_tree(definitions)
	var error := ResourceSaver.save(tree, TREE_PATH)
	if error != OK:
		_fail("Could not save tree: %s" % error_string(error))
		return
	_ensure_resource_uid(TREE_PATH)
	var saved_tree: YggdrasilTree = ResourceLoader.load(TREE_PATH, "YggdrasilTree", ResourceLoader.CACHE_MODE_IGNORE)
	var group := YggdrasilGroup.new()
	group.name = "Small Game"
	group.trees = [saved_tree]
	error = ResourceSaver.save(group, GROUP_PATH)
	if error != OK:
		_fail("Could not save group: %s" % error_string(error))
		return
	_ensure_resource_uid(GROUP_PATH)
	var saved_group: YggdrasilGroup = ResourceLoader.load(GROUP_PATH, "YggdrasilGroup", ResourceLoader.CACHE_MODE_IGNORE)
	var registry := YggdrasilRegistry.new()
	registry.groups = [saved_group]
	error = ResourceSaver.save(registry, REGISTRY_PATH)
	if error != OK:
		_fail("Could not save registry: %s" % error_string(error))
		return
	_ensure_resource_uid(REGISTRY_PATH)
	print("SAFEHOUSE_YGGDRASIL_MIGRATION_OK registry=%s group=%s tree=%s nodes=%d connections=%d" % [
		REGISTRY_PATH, GROUP_PATH, TREE_PATH, saved_tree.nodes.size(), _connection_count(saved_tree)
	])
	get_tree().quit(0)

func _ensure_resource_uid(path: String) -> void:
	var uid := ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()
	ResourceSaver.set_uid(path, uid)

func _load_definitions() -> Dictionary:
	var file := FileAccess.open("res://data/safehouse_upgrade_tree.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _build_tree(definitions: Dictionary) -> YggdrasilTree:
	var tree := YggdrasilTree.new()
	tree.id = "safehouse_upgrade_tree"
	tree.name = "Safehouse Upgrade Tree"
	tree.version = int(definitions.get("tree_version", 1))
	tree.size = Vector2(2200, 1500)
	tree.bg_color = Color("151c22")
	tree.allocation = false
	tree.preallocation = false
	tree.revealed = true
	tree.multiallocation = false
	tree.node_size[YggdrasilNode.NodeType.MEDIUM] = Vector2(170, 76)
	var stable_id_attribute := YggdrasilAttribute.new()
	stable_id_attribute.id = "stable_upgrade_id"
	stable_id_attribute.name = "Stable Upgrade ID"
	stable_id_attribute.effect = "Stable ID: #"
	stable_id_attribute.value_count = 1
	tree.attributes[stable_id_attribute.id] = stable_id_attribute
	var branch_attribute := YggdrasilAttribute.new()
	branch_attribute.id = "safehouse_branch"
	branch_attribute.name = "Safehouse Branch"
	branch_attribute.effect = "Branch: #"
	branch_attribute.value_count = 1
	tree.attributes[branch_attribute.id] = branch_attribute
	var root := YggdrasilNode.new()
	root.id = 1
	root.external_id = "safehouse_root"
	root.name = "SAFEHOUSE"
	root.description = "Permanent preparations between runs"
	root.type = YggdrasilNode.NodeType.MEDIUM
	root.is_root = true
	root.position = Vector2(-900, 0)
	root.attributes = {"stable_upgrade_id": ["safehouse_root"], "safehouse_branch": ["Root"]}
	tree.nodes.append(root)
	var branch_y := {"Arsenal": -520.0, "Squad": -260.0, "Barricade": 0.0, "Logistics": 260.0, "Heroes": 520.0}
	var branch_index := {"Arsenal": 0, "Squad": 0, "Barricade": 0, "Logistics": 0, "Heroes": 0}
	var numeric_id_by_upgrade: Dictionary = {}
	var id_counter := 2
	for definition in definitions.get("nodes", []):
		var upgrade_id: String = String(definition.get("id", ""))
		var branch: String = String(definition.get("branch", ""))
		var index: int = int(branch_index.get(branch, 0))
		var node := YggdrasilNode.new()
		node.id = id_counter
		node.external_id = upgrade_id
		node.name = String(definition.get("display_name", upgrade_id))
		node.description = String(definition.get("description", ""))
		node.type = YggdrasilNode.NodeType.MEDIUM
		node.position = Vector2(-600.0 + index * 330.0, float(branch_y.get(branch, 0.0)))
		node.attributes = {"stable_upgrade_id": [upgrade_id], "safehouse_branch": [branch]}
		tree.nodes.append(node)
		numeric_id_by_upgrade[upgrade_id] = id_counter
		branch_index[branch] = index + 1
		id_counter += 1
	for definition in definitions.get("nodes", []):
		var upgrade_id: String = String(definition.get("id", ""))
		var node: YggdrasilNode = tree.nodes[int(numeric_id_by_upgrade[upgrade_id]) - 1]
		var prerequisites: Array = definition.get("prerequisite_ids", [])
		if prerequisites.is_empty():
			_connect(root, node)
		else:
			for prerequisite in prerequisites:
				var parent_id: int = int(numeric_id_by_upgrade.get(String(prerequisite), 0))
				if parent_id > 0:
					_connect(tree.nodes[parent_id - 1], node)
	tree.id_counter = id_counter
	return tree

func _connect(from_node: YggdrasilNode, to_node: YggdrasilNode) -> void:
	if not from_node.out_nodes.has(to_node.id):
		from_node.out_nodes.append(to_node.id)
		from_node.line_data[to_node.id] = YggdrasilLineData.new()
	if not to_node.in_nodes.has(from_node.id):
		to_node.in_nodes.append(from_node.id)

func _connection_count(tree: YggdrasilTree) -> int:
	var count := 0
	for node: YggdrasilNode in tree.nodes:
		count += node.out_nodes.size()
	return count

func _fail(message: String) -> void:
	push_error("Safehouse Yggdrasil migration: %s" % message)
	get_tree().quit(1)
