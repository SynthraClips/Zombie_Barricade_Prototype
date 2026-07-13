extends Node2D

const SCREEN_WIDTH := 1080.0
const SCREEN_HEIGHT := 1280.0
const ROAD_CENTER_X := 540.0
const ROAD_TOP_HALF_WIDTH := 250.0
const ROAD_BOTTOM_HALF_WIDTH := 450.0
const ROAD_MARGIN := 40.0

var line_offset := 0.0
var night_active := false
var night_blend := 0.0
var night_end_distance := INF
var next_night_check_distance := 0.0
var next_building_distance := 18.0
var buildings: Array[Dictionary] = []
var last_building_id := ""
var building_textures: Dictionary = {}
var night_lamp_texture: Texture2D

func _ready() -> void:
	var definitions: Dictionary = GameManager.environment_data.get("buildings", {}).get("definitions", {})
	for building_id in definitions:
		var placeholder_path := String(definitions[building_id].get("placeholder", ""))
		if placeholder_path != "" and ResourceLoader.exists(placeholder_path):
			building_textures[String(building_id)] = load(placeholder_path)
	var lamp_path := String(GameManager.environment_data.get("night", {}).get("lamp_placeholder", ""))
	if lamp_path != "" and ResourceLoader.exists(lamp_path):
		night_lamp_texture = load(lamp_path)

func _process(delta: float) -> void:
	var run: Node = get_parent()
	if run == null or not run.running or get_tree().paused:
		return
	line_offset += run.scroll_speed * delta
	_update_environment(run, delta)
	queue_redraw()

func is_night() -> bool:
	return night_active

func request_night_section() -> bool:
	var run: Node = get_parent()
	if run == null or night_active:
		return false
	_start_night(run)
	return true

func get_environment_spawn_weight_multiplier(enemy_id: String) -> float:
	if not night_active:
		return 1.0
	return max(0.01, float(GameManager.environment_data.get("night", {}).get("enemy_weight_multipliers", {}).get(enemy_id, 1.0)))

func get_latest_building_event_bias() -> String:
	if last_building_id == "":
		return ""
	return String(GameManager.environment_data.get("buildings", {}).get("definitions", {}).get(last_building_id, {}).get("event_bias", ""))

func _update_environment(run: Node, delta: float) -> void:
	var night_config: Dictionary = GameManager.environment_data.get("night", {})
	var blend_target := 1.0 if night_active else 0.0
	night_blend = move_toward(night_blend, blend_target, delta / max(0.1, float(night_config.get("transition_seconds", 2.5))))
	if night_active and run.distance_travelled >= night_end_distance:
		night_active = false
		next_night_check_distance = run.distance_travelled + float(night_config.get("minimum_day_gap", 190.0))
		run.ui_manager.show_status_message("DAWN BREAKS", Color("ffd8a3"))
	elif not night_active and bool(night_config.get("enabled", true)) and run.distance_travelled >= max(float(night_config.get("minimum_distance", 230.0)), next_night_check_distance):
		next_night_check_distance = run.distance_travelled + 75.0
		if randf() <= float(night_config.get("chance_per_check", 0.62)):
			_start_night(run)
	if run.distance_travelled >= next_building_distance:
		_spawn_building(run)
		next_building_distance = run.distance_travelled + float(GameManager.environment_data.get("buildings", {}).get("spawn_interval_distance", 42.0)) * randf_range(0.75, 1.25)
	for building in buildings:
		building["y"] = float(building.get("y", 0.0)) + run.scroll_speed * delta
	buildings = buildings.filter(func(building): return float(building.get("y", 0.0)) < SCREEN_HEIGHT + 180.0)

func _start_night(run: Node) -> void:
	var night_config: Dictionary = GameManager.environment_data.get("night", {})
	night_active = true
	night_end_distance = run.distance_travelled + float(night_config.get("section_duration_distance", 145.0))
	run.run_stats["night_sections"] = int(run.run_stats.get("night_sections", 0)) + 1
	run.ui_manager.show_status_message("NIGHT SECTION AHEAD", Color("9ec9ff"))

func _spawn_building(run: Node) -> void:
	var config: Dictionary = GameManager.environment_data.get("buildings", {})
	var definitions: Dictionary = config.get("definitions", {})
	if definitions.is_empty():
		return
	var candidates: Array[String] = []
	var total := 0.0
	for id_variant in definitions.keys():
		var id := String(id_variant)
		if id == last_building_id and definitions.size() > 1:
			continue
		candidates.append(id)
		total += max(0.01, float(definitions[id].get("weight", 1.0)))
	var roll := randf() * total
	var selected_id: String = String(candidates.back())
	for id in candidates:
		roll -= max(0.01, float(definitions[id].get("weight", 1.0)))
		if roll <= 0.0:
			selected_id = id
			break
	last_building_id = selected_id
	buildings.append({"id":selected_id,"side":-1 if randi() % 2 == 0 else 1,"y":-130.0,"scale":randf_range(0.8,1.12)})
	while buildings.size() > int(config.get("max_visible", 6)):
		buildings.pop_front()
	var event_bias := String(definitions[selected_id].get("event_bias", ""))
	var progress: float = run.distance_travelled / max(run.target_distance, 1.0)
	var boss_chance: float = float(definitions[selected_id].get("boss_chance", 0.0))
	var boss_spawned: bool = false
	if boss_chance > 0.0 and progress >= float(definitions[selected_id].get("boss_min_progress", 0.0)) and randf() < boss_chance:
		boss_spawned = run.wave_spawner.try_spawn_event_boss(definitions[selected_id].get("boss_pool", []), "%s BOSS" % String(definitions[selected_id].get("label", "BUILDING")).to_upper())
	if not boss_spawned and event_bias == "animals" and randf() < 0.28:
		var spawn_x := get_random_lane_x(get_spawn_y(), 70.0)
		run.enemy_manager.spawn_enemy("mutated_dog" if randf() < 0.65 else "mutated_boar", Vector2(spawn_x, get_spawn_y() - 40.0), run.get_difficulty_multiplier())
	elif not boss_spawned and event_bias == "supplies" and randf() < 0.22:
		run.reward_manager.spawn_reward("supplies_small", Vector2(get_random_lane_x(get_spawn_y(), 70.0), get_spawn_y()))

func get_lane_edges_at_y(y: float) -> Vector2:
	var t: float = clampf(y / SCREEN_HEIGHT, 0.0, 1.0)
	var half_width: float = lerpf(ROAD_TOP_HALF_WIDTH, ROAD_BOTTOM_HALF_WIDTH, t)
	return Vector2(ROAD_CENTER_X - half_width, ROAD_CENTER_X + half_width)

func clamp_lane_x(x: float, y: float, padding: float = ROAD_MARGIN) -> float:
	var edges: Vector2 = get_lane_edges_at_y(y)
	return clampf(x, edges.x + padding, edges.y - padding)

func screen_x_to_lane_x(screen_x: float, y: float, padding: float = ROAD_MARGIN) -> float:
	return clamp_lane_x(screen_x, y, padding)

func get_squad_y() -> float:
	return SCREEN_HEIGHT - 170.0

func get_center_x() -> float:
	return ROAD_CENTER_X

func get_spawn_y() -> float:
	return -150.0

func get_forward_direction() -> Vector2:
	return Vector2.UP

func get_usable_road_width(y: float) -> float:
	var edges := get_lane_edges_at_y(y)
	return edges.y - edges.x

func get_random_lane_x(y: float, padding: float = ROAD_MARGIN, random: RandomNumberGenerator = null) -> float:
	var edges := get_lane_edges_at_y(y)
	var left := edges.x + padding
	var right := edges.y - padding
	if random != null:
		return random.randf_range(left, right)
	return randf_range(left, right)

func get_gate_row_positions(y: float, gate_count: int) -> Array[float]:
	var edges: Vector2 = get_lane_edges_at_y(y)
	var side_padding: float = float(GameManager.gate_data.get("lane_margin", 14.0))
	var usable_left: float = edges.x + side_padding
	var usable_right: float = edges.y - side_padding
	if gate_count <= 1:
		return [ROAD_CENTER_X]
	if gate_count == 2:
		var lane_width := (usable_right - usable_left) / 3.0
		return [usable_left + lane_width * 0.5, usable_right - lane_width * 0.5]
	if gate_count == 3:
		var lane_width := (usable_right - usable_left) / 3.0
		return [usable_left + lane_width * 0.5, usable_left + lane_width * 1.5, usable_left + lane_width * 2.5]
	var positions: Array[float] = []
	for index in range(gate_count):
		var t: float = float(index + 1) / float(gate_count + 1)
		positions.append(lerpf(usable_left, usable_right, t))
	return positions

func _draw() -> void:
	var night_config: Dictionary = GameManager.environment_data.get("night", {})
	var background := Color("182026").lerp(Color(night_config.get("background_color", "#101827")), night_blend)
	var road_color := Color("2f3844").lerp(Color(night_config.get("road_color", "#273244")), night_blend)
	draw_rect(Rect2(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT), background)
	var road_points := PackedVector2Array([
		Vector2(ROAD_CENTER_X - ROAD_TOP_HALF_WIDTH, 0),
		Vector2(ROAD_CENTER_X + ROAD_TOP_HALF_WIDTH, 0),
		Vector2(ROAD_CENTER_X + ROAD_BOTTOM_HALF_WIDTH, SCREEN_HEIGHT),
		Vector2(ROAD_CENTER_X - ROAD_BOTTOM_HALF_WIDTH, SCREEN_HEIGHT)
	])
	draw_polygon(road_points, [road_color])
	_draw_buildings()
	var shoulder_points := PackedVector2Array([
		Vector2(ROAD_CENTER_X - ROAD_TOP_HALF_WIDTH - 18.0, 0),
		Vector2(ROAD_CENTER_X + ROAD_TOP_HALF_WIDTH + 18.0, 0),
		Vector2(ROAD_CENTER_X + ROAD_BOTTOM_HALF_WIDTH + 28.0, SCREEN_HEIGHT),
		Vector2(ROAD_CENTER_X - ROAD_BOTTOM_HALF_WIDTH - 28.0, SCREEN_HEIGHT)
	])
	draw_polyline(shoulder_points, Color("7f8b97"), 8.0, true)
	var lane_band_color := Color("ffffff", 0.035)
	for lane_offset in [-92.0, 92.0]:
		draw_polygon(PackedVector2Array([
			Vector2(ROAD_CENTER_X + lane_offset - 22.0, 0),
			Vector2(ROAD_CENTER_X + lane_offset + 22.0, 0),
			Vector2(ROAD_CENTER_X + lane_offset * 1.45 + 34.0, SCREEN_HEIGHT),
			Vector2(ROAD_CENTER_X + lane_offset * 1.45 - 34.0, SCREEN_HEIGHT)
		]), [lane_band_color])
	var y := fmod(line_offset, 120.0) - 120.0
	while y < SCREEN_HEIGHT:
		draw_rect(Rect2(348, y, 24, 72), Color("d8d8d8"))
		y += 120.0
	draw_line(Vector2(ROAD_CENTER_X - ROAD_TOP_HALF_WIDTH, 0), Vector2(ROAD_CENTER_X - ROAD_BOTTOM_HALF_WIDTH, SCREEN_HEIGHT), Color("a7b0b8"), 6.0)
	draw_line(Vector2(ROAD_CENTER_X + ROAD_TOP_HALF_WIDTH, 0), Vector2(ROAD_CENTER_X + ROAD_BOTTOM_HALF_WIDTH, SCREEN_HEIGHT), Color("a7b0b8"), 6.0)
	if night_blend > 0.01:
		var moonlight := Color(night_config.get("moonlight_color", "#8fb9e8"), night_blend * 0.12)
		draw_circle(Vector2(900, 105), 56.0, moonlight)
		for lamp_x in [118.0, 962.0]:
			draw_circle(Vector2(lamp_x, 360), 92.0, Color("ffd88a", night_blend * 0.08))
			if night_lamp_texture != null:
				draw_texture_rect(night_lamp_texture, Rect2(lamp_x - 20.0, 300.0, 40.0, 96.0), false, Color(1.0, 1.0, 1.0, maxf(0.35, night_blend)))

func _draw_buildings() -> void:
	var definitions: Dictionary = GameManager.environment_data.get("buildings", {}).get("definitions", {})
	for building in buildings:
		var definition: Dictionary = definitions.get(String(building.get("id", "")), {})
		var side := int(building.get("side", -1))
		var y := float(building.get("y", 0.0))
		var size_scale := float(building.get("scale", 1.0))
		var width := 120.0 * size_scale
		var height := 96.0 * size_scale
		var x := 18.0 if side < 0 else SCREEN_WIDTH - width - 18.0
		var building_texture: Texture2D = building_textures.get(String(building.get("id", "")))
		if building_texture != null:
			draw_texture_rect(building_texture, Rect2(x, y, width, height), false, Color.WHITE)
		else:
			draw_rect(Rect2(x, y, width, height), Color(definition.get("color", "#555555")))
		draw_rect(Rect2(x, y, width, height), Color("20252b"), false, 4.0)
		if night_blend > 0.1 and bool(definition.get("lit_at_night", false)):
			draw_rect(Rect2(x + 18.0, y + 24.0, 22.0, 18.0), Color("ffd477", 0.75 * night_blend))
		draw_string(ThemeDB.fallback_font, Vector2(x + 5.0, y + height + 15.0), String(definition.get("label", "Building")), HORIZONTAL_ALIGNMENT_LEFT, width, 11, Color("d8dde3"))
