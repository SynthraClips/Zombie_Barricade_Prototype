extends Control

var subtitle_label: Label
var bank_label: Label
var best_distance_label: Label
var kills_label: Label
var bosses_label: Label
var missions_label: Label
var quit_button: Button
var root_row: BoxContainer
var main_card: Control
var art_panel: Control
var title_label: Label

var title_pulse := 0.0

func _ready() -> void:
	root_row = get_node_or_null("Layout/RootRow")
	main_card = get_node_or_null("Layout/RootRow/MainCard")
	art_panel = get_node_or_null("Layout/RootRow/ArtPanel")
	title_label = get_node_or_null("Layout/RootRow/MainCard/CardMargin/CardVBox/Title")
	subtitle_label = get_node_or_null("Layout/MainCard/CardMargin/CardVBox/Subtitle")
	bank_label = get_node_or_null("Layout/MainCard/CardMargin/CardVBox/Stats/Bank")
	best_distance_label = get_node_or_null("Layout/MainCard/CardMargin/CardVBox/Stats/BestDistance")
	kills_label = get_node_or_null("Layout/MainCard/CardMargin/CardVBox/Stats/Kills")
	bosses_label = get_node_or_null("Layout/MainCard/CardMargin/CardVBox/Stats/Bosses")
	missions_label = get_node_or_null("Layout/MainCard/CardMargin/CardVBox/Stats/Missions")
	quit_button = get_node_or_null("Layout/MainCard/CardMargin/CardVBox/Buttons/Quit")
	if subtitle_label == null:
		subtitle_label = get_node_or_null("Margin/Panel/VBox/Subtitle")
	if bank_label == null:
		bank_label = get_node_or_null("Margin/Panel/VBox/Bank")
	if quit_button != null:
		quit_button.visible = OS.get_name() != "Web"
	if subtitle_label != null:
		subtitle_label.text = "Hold the road, rescue survivors, and keep the barricade standing."
	_update_layout_for_viewport()
	_refresh()
	queue_redraw()

func _process(delta: float) -> void:
	title_pulse += delta
	_update_layout_for_viewport()
	queue_redraw()

func _refresh() -> void:
	var stats: Dictionary = SaveManager.save_data.get("stats", {})
	if bank_label != null:
		bank_label.text = "Saved Coins: %d" % int(SaveManager.save_data.get("banked_coins", 0))
	if best_distance_label != null:
		best_distance_label.text = "Best Distance: %dm" % int(stats.get("best_distance", 0))
	if kills_label != null:
		kills_label.text = "Zombies Killed: %d" % int(stats.get("lifetime_kills", 0))
	if bosses_label != null:
		bosses_label.text = "Bosses Defeated: %d" % int(stats.get("boss_kills", 0))
	if missions_label != null:
		missions_label.text = "Completed Missions: %d" % int(SaveManager.save_data.get("completed_missions", []).size())

func _on_play_pressed() -> void:
	GameManager.start_run()

func _on_upgrades_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/UpgradeScreen.tscn")

func _on_missions_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MissionScreen.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SettingsScreen.tscn")

func _on_validation_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/validation/ValidationScene.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _draw() -> void:
	var viewport := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport), Color("10161c"))
	draw_polygon(PackedVector2Array([
		Vector2(viewport.x * 0.62, 0),
		Vector2(viewport.x * 0.88, 0),
		Vector2(viewport.x * 0.72, viewport.y),
		Vector2(viewport.x * 0.48, viewport.y)
	]), [Color("20272f")])
	for index in 6:
		var offset: float = fmod(title_pulse * 34.0 + index * 160.0, viewport.y + 180.0) - 180.0
		draw_rect(Rect2(viewport.x * 0.665, offset, 20, 90), Color("d7d7d7", 0.08))
	draw_rect(Rect2(viewport.x * 0.58, viewport.y * 0.18, viewport.x * 0.22, 18), Color("5e4634", 0.9))
	draw_rect(Rect2(viewport.x * 0.575, viewport.y * 0.18 - 12, viewport.x * 0.23, 8), Color("8e6a49", 0.9))
	for index in 4:
		var x := viewport.x * 0.56 + index * 46.0
		draw_rect(Rect2(x, viewport.y * 0.78, 18, 54), Color("365a7a", 0.9))
		draw_circle(Vector2(x + 9, viewport.y * 0.78 - 12), 10.0, Color("d6c3a6", 0.85))
	for index in 5:
		var zx := viewport.x * 0.63 + index * 34.0
		draw_rect(Rect2(zx, viewport.y * 0.14 + sin(title_pulse * 0.6 + index) * 6.0, 16, 36), Color("657d52", 0.55))
		draw_circle(Vector2(zx + 8, viewport.y * 0.14 - 10 + sin(title_pulse * 0.6 + index) * 6.0), 8.0, Color("88a967", 0.55))

func _update_layout_for_viewport() -> void:
	if root_row == null or main_card == null:
		return
	var viewport_width: float = get_viewport_rect().size.x
	var compact: bool = viewport_width < 980.0
	if art_panel != null:
		art_panel.visible = not compact
		art_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not compact else 0
	main_card.custom_minimum_size.x = 0.0 if compact else 420.0
	main_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 30 if compact else 38)
