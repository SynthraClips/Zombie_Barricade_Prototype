extends Node

var failures: Array[String] = []
var passes := 0

func _ready() -> void:
	SaveManager.load_profile_index()
	if not SaveManager.profile_exists(0):
		SaveManager.create_profile(0, "Upgrade Tests")
	SaveManager.select_profile(0)
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	var original: Dictionary = SaveManager.save_data.duplicate(true)
	_test_definition_validation()
	_test_purchase_rules()
	_test_save_and_migration()
	_test_effects()
	await _test_ui()
	await _test_main_menu_save_display()
	SaveManager.save_data = original
	SaveManager.save_game()
	print("SAFEHOUSE TREE TESTS: %d passed, %d failed" % [passes, failures.size()])
	for failure in failures:
		push_error("[SAFEHOUSE TEST FAIL] %s" % failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)

func _reset_progress(coins: int = 0) -> void:
	SaveManager.save_data = SaveManager._default_save_data()
	SaveManager.save_data["banked_coins"] = coins
	SaveManager.save_data["supplies"] = coins
	SaveManager.save_data["survivors"] = coins
	for upgrade_id in UpgradeManager.upgrade_defs:
		SaveManager.save_data["upgrades"][upgrade_id] = 0
	UpgradeManager.purchase_in_progress = false

func _test_definition_validation() -> void:
	_expect(UpgradeManager.validation_errors.is_empty(), "production definitions validate")
	_expect(UpgradeManager.tree_nodes_by_id.size() == 25, "tree has 25 stable upgrade ids")
	_expect(FileAccess.file_exists("res://yggdrasil/registry.tres"), "registered Yggdrasil registry exists")
	_expect(FileAccess.file_exists("res://yggdrasil/Small Game/small_game.tres"), "registered Small Game group exists")
	_expect(FileAccess.file_exists("res://yggdrasil/Small Game/safehouse_upgrade_tree.tres"), "registered Safehouse tree resource exists")
	_expect(ResourceLoader.get_resource_uid("res://yggdrasil/registry.tres") != ResourceUID.INVALID_ID, "Yggdrasil registry has a persistent resource UID")
	_expect(ResourceLoader.get_resource_uid("res://yggdrasil/Small Game/small_game.tres") != ResourceUID.INVALID_ID, "registered Small Game group has a persistent resource UID")
	_expect(ResourceLoader.get_resource_uid("res://yggdrasil/Small Game/safehouse_upgrade_tree.tres") != ResourceUID.INVALID_ID, "registered Safehouse tree has a persistent resource UID")
	var registered_group: YggdrasilGroup = null
	for group: YggdrasilGroup in YggdrasilLoader.get_registry().groups:
		if group.name == "Small Game":
			registered_group = group
			break
	_expect(registered_group != null, "Yggdrasil registry exposes the Small Game group")
	var registered_tree: YggdrasilTree = YggdrasilLoader.load_tree("Small Game/Safehouse Upgrade Tree", true)
	_expect(registered_tree != null, "Safehouse tree loads by registered group/tree path")
	_expect(registered_tree != null and registered_tree.nodes.size() == 26, "registered tree contains root plus 25 upgrade nodes")
	_expect(registered_tree != null and SafehouseUpgradeTree.validate_yggdrasil_tree(registered_tree, UpgradeManager.tree_defs).is_empty(), "registered topology matches authoritative upgrade prerequisites")
	_expect(registered_tree != null and registered_tree.nodes.any(func(node: YggdrasilNode): return node.is_root), "registered tree contains a root node")
	var resource_ids: Array[String] = []
	if registered_tree != null:
		for resource_node: YggdrasilNode in registered_tree.nodes:
			var resource_id := SafehouseUpgradeTree.get_stable_id(resource_node)
			if resource_id != "safehouse_root":
				resource_ids.append(resource_id)
	_expect(resource_ids.size() == 25 and resource_ids.duplicate().all(func(id): return resource_ids.count(id) == 1), "registered stable upgrade IDs are unique")
	_expect(SaveManager.save_data.get("permanent_upgrade_ids", []).all(func(id): return id is String), "player ownership remains independent of Yggdrasil numeric node IDs")
	var mapped_legacy_ids: Array[String] = []
	for definition in UpgradeManager.tree_defs.get("nodes", []):
		for legacy_id in definition.get("legacy_ids", []):
			mapped_legacy_ids.append(String(legacy_id))
	_expect(UpgradeManager.upgrade_defs.keys().all(func(id): return mapped_legacy_ids.has(String(id))), "all existing permanent upgrade ids map into the Safehouse tree")
	var duplicate: Dictionary = UpgradeManager.tree_defs.duplicate(true)
	duplicate["nodes"].append(duplicate["nodes"][0].duplicate(true))
	_expect(_contains_error(SafehouseUpgradeTree.validate(duplicate), "Duplicate upgrade id"), "duplicate ids are rejected")
	var missing: Dictionary = UpgradeManager.tree_defs.duplicate(true)
	missing["nodes"][0]["prerequisite_ids"] = ["missing_node"]
	_expect(_contains_error(SafehouseUpgradeTree.validate(missing), "Missing prerequisite"), "missing prerequisites are reported")
	var circular: Dictionary = UpgradeManager.tree_defs.duplicate(true)
	circular["nodes"][0]["prerequisite_ids"] = [circular["nodes"][1]["id"]]
	circular["nodes"][1]["prerequisite_ids"] = [circular["nodes"][0]["id"]]
	_expect(_contains_error(SafehouseUpgradeTree.validate(circular), "Circular prerequisite"), "circular dependencies are reported")
	var invalid: Dictionary = UpgradeManager.tree_defs.duplicate(true)
	invalid["nodes"][0]["effect_type"] = "not_a_real_effect"
	_expect(_contains_error(SafehouseUpgradeTree.validate(invalid), "Unknown effect type"), "invalid effect types are reported")

func _test_purchase_rules() -> void:
	_reset_progress(1000)
	var first := "arsenal_rifle_damage_01"
	var dependent := "arsenal_rifle_damage_02"
	_expect(UpgradeManager.can_purchase_tree_upgrade(first), "available upgrade can be purchased")
	_expect(not UpgradeManager.can_purchase_tree_upgrade(dependent), "locked upgrade cannot be purchased")
	SaveManager.save_data["banked_coins"] = 0
	_expect(not UpgradeManager.can_purchase_tree_upgrade(first), "unaffordable upgrade cannot be purchased")
	SaveManager.save_data["banked_coins"] = 1000
	var before_coins := int(SaveManager.save_data["banked_coins"])
	_expect(UpgradeManager.purchase_tree_upgrade(first), "purchase transaction succeeds")
	var costs: Dictionary = UpgradeManager.get_tree_costs(first)
	_expect(int(SaveManager.save_data["banked_coins"]) == before_coins - int(costs.get("coins", 0)), "mixed resources are deducted exactly once")
	_expect(not UpgradeManager.purchase_tree_upgrade(first), "duplicate purchase is blocked")
	_expect(int(SaveManager.save_data["banked_coins"]) == before_coins - int(costs.get("coins", 0)), "rapid repeated confirmation cannot double charge")
	_expect(UpgradeManager.can_purchase_tree_upgrade(dependent), "purchase unlocks dependent node")

func _test_save_and_migration() -> void:
	_reset_progress(321)
	_expect(UpgradeManager.purchase_tree_upgrade("logistics_reward_bonus_01"), "save test upgrade purchases")
	var expected_coins := int(SaveManager.save_data["banked_coins"])
	SaveManager.load_save()
	UpgradeManager.synchronize_loaded_save()
	_expect(UpgradeManager.is_tree_upgrade_owned("logistics_reward_bonus_01"), "purchased upgrade survives save and reload")
	_expect(int(SaveManager.save_data["banked_coins"]) == expected_coins, "currency survives save and reload")
	var value_once := UpgradeManager.get_upgrade_value("coin_gain")
	UpgradeManager.synchronize_loaded_save()
	_expect(is_equal_approx(UpgradeManager.get_upgrade_value("coin_gain"), value_once), "loading does not apply modifiers twice")
	SaveManager.save_data["permanent_upgrade_ids"].append("obsolete_test_upgrade")
	UpgradeManager.synchronize_loaded_save()
	_expect(SaveManager.save_data["permanent_upgrade_ids"].has("obsolete_test_upgrade"), "unknown old ids are ignored without data loss")
	_reset_progress(0)
	SaveManager.save_data["upgrades"]["soldier_damage"] = 1
	UpgradeManager.synchronize_loaded_save()
	_expect(UpgradeManager.is_tree_upgrade_owned("arsenal_rifle_damage_01"), "legacy upgrade ids migrate to stable ids")

func _test_effects() -> void:
	_reset_progress(5000)
	var cases := {
		"arsenal_rifle_damage_01": "soldier_damage",
		"squad_starting_soldier_01": "starting_soldiers",
		"barricade_max_health_01": "barricade_hp",
		"logistics_reward_bonus_01": "coin_gain",
		"hero_duration_01": "hero_duration"
	}
	for upgrade_id in cases:
		var effect_type: String = cases[upgrade_id]
		var before := UpgradeManager.get_upgrade_value(effect_type)
		var bought := UpgradeManager.purchase_tree_upgrade(upgrade_id)
		_expect(bought and UpgradeManager.get_upgrade_value(effect_type) > before, "%s gameplay modifier changes correctly" % effect_type)

func _test_ui() -> void:
	_reset_progress(1000)
	SaveManager.save_game()
	var scene: PackedScene = load("res://scenes/ui/UpgradeScreen.tscn")
	_expect(scene != null, "upgrade page scene loads")
	var screen: Control = scene.instantiate()
	get_tree().root.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(screen.get("tree_view") != null, "Yggdrasil tree resource builds")
	_expect(screen.has_node("Root/Header/Coins") and screen.has_node("Root/Body/Details/Purchase") and screen.has_node("Root/Footer/Back"), "required upgrade UI nodes exist")
	_expect(screen.get_node("Root/Header/Title").text == "UPGRADES" and "COINS" in screen.get_node("Root/Header/Coins").text, "upgrade header uses Upgrades and Coins terminology")
	_expect(screen.get("node_buttons").size() == 25, "all upgrade nodes render")
	var root_node: Control = screen.tree_view.nodes_container.get_children().filter(func(node: Control): return node.external_id == "safehouse_root")[0]
	_expect(root_node.get_node("Name").text == "UPGRADES", "upgrade tree root has no player-facing Safehouse title")
	var root_visible_rect: Rect2 = Rect2(root_node.global_position, root_node.size * screen.tree_view.main_container.offset_transform_scale)
	_expect(root_visible_rect.intersects(screen.tree_host.get_global_rect()), "Safehouse root is visible when the upgrade page opens")
	_expect(screen.has_method("_on_back_pressed"), "back navigation handler exists")
	_expect(int(SaveManager.save_data.get("banked_coins", 0)) == 1000, "upgrade page reloads authoritative save before rendering")
	screen._show_tree_error("Controlled fallback test")
	_expect(screen.error_panel.visible and screen.error_panel.text == "Controlled fallback test", "missing plugin/resource state presents a controlled error panel")
	screen.queue_free()
	await get_tree().process_frame

func _test_main_menu_save_display() -> void:
	_reset_progress(777)
	SaveManager.save_game()
	var menu_scene: PackedScene = load("res://scenes/main/MainMenu.tscn")
	var menu: Control = menu_scene.instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	var bank: Label = menu.get_node("Layout/RootRow/MainCard/CardMargin/CardVBox/Stats/Bank")
	_expect(bank.text.find("Coins 777") >= 0 and bank.text.find("Supplies 777") >= 0 and bank.text.find("Survivors 777") >= 0, "main menu displays all authoritative progression resources after startup")
	menu.queue_free()
	await get_tree().process_frame

func _contains_error(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if fragment in error:
			return true
	return false
