extends Node2D

const SCREEN_WIDTH := 1080.0
const SCREEN_HEIGHT := 1280.0
const ROAD_CENTER_X := 540.0
const ROAD_TOP_HALF_WIDTH := 250.0
const ROAD_BOTTOM_HALF_WIDTH := 450.0
const ROAD_MARGIN := 40.0

var line_offset := 0.0

func _process(delta: float) -> void:
	var run: Node = get_parent()
	if run == null or not run.running or get_tree().paused:
		return
	line_offset += run.scroll_speed * delta
	queue_redraw()

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
	draw_rect(Rect2(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT), Color("182026"))
	var road_points := PackedVector2Array([
		Vector2(ROAD_CENTER_X - ROAD_TOP_HALF_WIDTH, 0),
		Vector2(ROAD_CENTER_X + ROAD_TOP_HALF_WIDTH, 0),
		Vector2(ROAD_CENTER_X + ROAD_BOTTOM_HALF_WIDTH, SCREEN_HEIGHT),
		Vector2(ROAD_CENTER_X - ROAD_BOTTOM_HALF_WIDTH, SCREEN_HEIGHT)
	])
	draw_polygon(road_points, [Color("2f3844")])
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
