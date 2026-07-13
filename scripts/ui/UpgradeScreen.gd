extends Control

const TREE_NODE_SCENE := preload("res://scenes/ui/SafehouseTreeNode.tscn")
const TREE_CONNECTION_SCENE := preload("res://scenes/ui/SafehouseTreeConnection.tscn")
const TREE_TOOLTIP_SCENE := preload("res://scenes/ui/SafehouseTreeTooltip.tscn")
const TREE_LOADER_PATH := "Small Game/Safehouse Upgrade Tree"

@onready var coins_label: Label = $Root/Header/Coins
@onready var tree_host: Control = $Root/Body/TreePanel/TreeHost
@onready var error_panel: Label = $Root/Body/TreePanel/ErrorPanel
@onready var title_label: Label = $Root/Body/Details/Title
@onready var branch_label: Label = $Root/Body/Details/Branch
@onready var description_label: Label = $Root/Body/Details/Description
@onready var effect_label: Label = $Root/Body/Details/Effect
@onready var prerequisites_label: Label = $Root/Body/Details/Prerequisites
@onready var cost_label: Label = $Root/Body/Details/Cost
@onready var state_label: Label = $Root/Body/Details/State
@onready var purchase_button: Button = $Root/Body/Details/Purchase
@onready var confirmation: ConfirmationDialog = $PurchaseConfirmation

var tree_view: YggdrasilTreeView
var tree_resource: YggdrasilTree
var selected_upgrade_id := ""
var node_buttons: Dictionary = {}
var numeric_id_by_upgrade: Dictionary = {}
var upgrade_id_by_numeric: Dictionary = {}

func _ready() -> void:
	# Always enter the Safehouse from the authoritative project save. This also
	# makes returning from a run and a fresh executable launch behave identically.
	SaveManager.load_save()
	UpgradeManager.synchronize_loaded_save()
	purchase_button.pressed.connect(_request_purchase)
	confirmation.confirmed.connect(_confirm_purchase)
	UpgradeManager.tree_upgrade_purchased.connect(_on_upgrade_purchased)
	_build_tree()
	_refresh_all()

func _build_tree() -> void:
	if not FileAccess.file_exists("res://addons/yggdrasil/plugin.cfg"):
		_show_tree_error("Yggdrasil is unavailable. Permanent upgrades are safe; enable the plugin to restore the tree view.")
		return
	if not UpgradeManager.validation_errors.is_empty():
		_show_tree_error("Upgrade definitions failed validation:\n%s" % "\n".join(UpgradeManager.validation_errors))
		return
	tree_resource = YggdrasilLoader.load_tree(TREE_LOADER_PATH, true)
	if tree_resource == null:
		_show_tree_error("The registered upgrade tree could not be loaded. Your progression remains intact.")
		return
	var topology_errors := SafehouseUpgradeTree.validate_yggdrasil_tree(tree_resource, UpgradeManager.tree_defs)
	if not topology_errors.is_empty():
		_show_tree_error("Upgrade tree topology failed validation:\n%s" % "\n".join(topology_errors))
		return
	_index_registered_nodes()
	var builder := YggdrasilBuilder.new(tree_resource)
	builder.set_parent(tree_host)
	builder.set_save_path("user://safehouse_tree_visual_state.ignore")
	builder.set_node_scene(TREE_NODE_SCENE)
	builder.set_line_scene(TREE_CONNECTION_SCENE)
	builder.set_tooltip_scene(TREE_TOOLTIP_SCENE)
	builder.node_created_callback(_on_yggdrasil_node_created)
	builder.line_created_callback(_on_yggdrasil_line_created)
	tree_view = builder.build()
	if tree_view == null:
		_show_tree_error("The upgrade tree could not be built. Your progression remains intact.")
		return
	call_deferred("_focus_tree_start")
	error_panel.hide()

func _focus_tree_start() -> void:
	if tree_view == null:
		return
	await get_tree().process_frame
	var zoom := 0.4
	tree_view.camera.set_camera_zoom(zoom)
	# The graph is wider than the portrait viewport. Start at the root and first
	# tier so the progression entry point is obvious instead of opening midway
	# through the branches.
	var half_tree_width: float = tree_resource.size.x * 0.5 * zoom
	var half_view_width: float = tree_host.size.x * 0.5
	tree_view.main_container.offset_transform_position = Vector2(max(half_tree_width - half_view_width, 0.0), 0.0)

func _fit_tree_to_view() -> void:
	if tree_view == null or tree_resource == null:
		return
	var medium_size: Vector2 = tree_resource.node_size.get(YggdrasilNode.NodeType.MEDIUM, Vector2(170.0, 76.0))
	var min_position := Vector2(INF, INF)
	var max_position := Vector2(-INF, -INF)
	for node: YggdrasilNode in tree_resource.nodes:
		min_position = min_position.min(node.position - medium_size * 0.5)
		max_position = max_position.max(node.position + medium_size * 0.5)
	var graph_size: Vector2 = max_position - min_position
	var available_size: Vector2 = tree_host.size - Vector2(24.0, 24.0)
	var fit_zoom: float = min(available_size.x / max(graph_size.x, 1.0), available_size.y / max(graph_size.y, 1.0))
	fit_zoom = clampf(fit_zoom, 0.18, 0.6)
	tree_view.camera.set_camera_zoom(fit_zoom)
	var graph_center: Vector2 = (min_position + max_position) * 0.5
	tree_view.main_container.offset_transform_position = -graph_center * fit_zoom

func _index_registered_nodes() -> void:
	numeric_id_by_upgrade.clear()
	upgrade_id_by_numeric.clear()
	for node: YggdrasilNode in tree_resource.nodes:
		var stable_id := SafehouseUpgradeTree.get_stable_id(node)
		numeric_id_by_upgrade[stable_id] = node.id
		upgrade_id_by_numeric[node.id] = stable_id

func _on_yggdrasil_node_created(node: YggdrasilNodeButton) -> void:
	var registered_stable_id: String = String(upgrade_id_by_numeric.get(node.id, ""))
	if registered_stable_id == "safehouse_root":
		node.external_id = "safehouse_root"
		node.get_node("Name").text = "UPGRADES"
		node.get_node("Badge").text = "S"
		node.get_node("Cost").text = "TREE ROOT"
		node.disabled = true
		return
	var upgrade_id: String = registered_stable_id
	node.external_id = upgrade_id
	var definition := UpgradeManager.get_tree_definition(upgrade_id)
	node_buttons[upgrade_id] = node
	node.get_node("Name").text = String(definition.get("display_name", upgrade_id))
	node.get_node("Badge").text = String(definition.get("branch", "?")).left(1).to_upper()
	node.get_node("Cost").text = "%d COINS" % int(definition.get("cost", 0))
	node.pressed.connect(_select_upgrade.bind(upgrade_id))

func _on_yggdrasil_line_created(line: YggdrasilConnection, from_id: int, to_id: int) -> void:
	var child_id: String = String(upgrade_id_by_numeric.get(to_id, ""))
	if child_id != "" and UpgradeManager.is_tree_upgrade_owned(child_id):
		line.default_color = Color("5ba7bf")

func _select_upgrade(upgrade_id: String) -> void:
	selected_upgrade_id = upgrade_id
	_refresh_all()

func _refresh_all() -> void:
	coins_label.text = "COINS  %d" % int(SaveManager.save_data.get("banked_coins", 0))
	for upgrade_id in node_buttons:
		var node: SafehouseTreeNode = node_buttons[upgrade_id]
		node.set_safehouse_state(UpgradeManager.get_tree_node_state(upgrade_id))
		node.set_selected(upgrade_id == selected_upgrade_id)
	_refresh_details()

func _refresh_details() -> void:
	if selected_upgrade_id.is_empty():
		title_label.text = "SELECT AN UPGRADE"
		branch_label.text = "ARSENAL  •  SQUAD  •  BARRICADE  •  LOGISTICS  •  HEROES"
		description_label.text = "Pan with the middle mouse button and zoom with the wheel. Select a node to inspect its permanent effect."
		effect_label.text = ""
		prerequisites_label.text = ""
		cost_label.text = ""
		state_label.text = ""
		purchase_button.disabled = true
		return
	var definition := UpgradeManager.get_tree_definition(selected_upgrade_id)
	var state := UpgradeManager.get_tree_node_state(selected_upgrade_id)
	title_label.text = String(definition.get("display_name", selected_upgrade_id)).to_upper()
	branch_label.text = String(definition.get("branch", "Upgrades")).to_upper()
	description_label.text = String(definition.get("description", ""))
	effect_label.text = "EFFECT  %s" % _effect_text(definition)
	var prerequisites: Array = definition.get("prerequisite_ids", [])
	prerequisites_label.text = "REQUIRES  None" if prerequisites.is_empty() else "REQUIRES  %s" % _prerequisite_names(prerequisites)
	cost_label.text = "COST  %d COINS   •   AVAILABLE  %d COINS" % [int(definition.get("cost", 0)), int(SaveManager.save_data.get("banked_coins", 0))]
	state_label.text = "STATUS  %s" % state.to_upper()
	purchase_button.text = "PURCHASE" if state != "purchased" else "PURCHASED"
	purchase_button.disabled = not UpgradeManager.can_purchase_tree_upgrade(selected_upgrade_id)

func _effect_text(definition: Dictionary) -> String:
	var effect_type: String = String(definition.get("effect_type", "")).replace("_", " ").capitalize()
	var value = definition.get("effect_value", 0)
	if value is float and absf(float(value)) < 1.0 and not String(definition.get("effect_type", "")) in ["hero_duration", "hero_cooldown"]:
		return "+%d%% %s" % [int(round(float(value) * 100.0)), effect_type]
	return "+%s %s" % [str(value), effect_type]

func _prerequisite_names(ids: Array) -> String:
	var names: Array[String] = []
	for id in ids:
		names.append(String(UpgradeManager.get_tree_definition(String(id)).get("display_name", id)))
	return ", ".join(names)

func _request_purchase() -> void:
	if not UpgradeManager.can_purchase_tree_upgrade(selected_upgrade_id):
		_refresh_all()
		return
	var definition := UpgradeManager.get_tree_definition(selected_upgrade_id)
	confirmation.dialog_text = "Purchase %s for %d coins?\n\n%s" % [definition.get("display_name", selected_upgrade_id), definition.get("cost", 0), _effect_text(definition)]
	confirmation.popup_centered(Vector2i(520, 260))

func _confirm_purchase() -> void:
	purchase_button.disabled = true
	if not UpgradeManager.purchase_tree_upgrade(selected_upgrade_id):
		state_label.text = "PURCHASE FAILED — progression was not changed."
	_refresh_all()

func _on_upgrade_purchased(_upgrade_id: String) -> void:
	_refresh_all()

func _show_tree_error(message: String) -> void:
	error_panel.text = message
	error_panel.show()
	purchase_button.disabled = true

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func _on_reset_view_pressed() -> void:
	_fit_tree_to_view()

func _on_zoom_in_pressed() -> void:
	if tree_view != null:
		tree_view.camera.set_camera_zoom(min(tree_view.main_container.offset_transform_scale.x + 0.1, 1.0))

func _on_zoom_out_pressed() -> void:
	if tree_view != null:
		tree_view.camera.set_camera_zoom(max(tree_view.main_container.offset_transform_scale.x - 0.1, 0.2))
