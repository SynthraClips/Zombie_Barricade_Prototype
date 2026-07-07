extends Node2D

const SCREEN_WIDTH := 720.0
const SCREEN_HEIGHT := 1280.0
const ROAD_CENTER_X := 360.0
const ROAD_TOP_HALF_WIDTH := 165.0
const ROAD_BOTTOM_HALF_WIDTH := 300.0
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

func screen_x_to_lane_x(screen_x: float, y: float) -> float:
	return clamp_lane_x(screen_x, y)

func get_squad_y() -> float:
	return SCREEN_HEIGHT - 170.0

func get_spawn_y() -> float:
	return -150.0

func get_gate_row_positions(y: float, gate_count: int) -> Array[float]:
	var edges: Vector2 = get_lane_edges_at_y(y)
	var side_padding: float = 44.0 if gate_count <= 2 else 30.0
	var usable_left: float = edges.x + side_padding
	var usable_right: float = edges.y - side_padding
	if gate_count <= 1:
		return [ROAD_CENTER_X]
	if gate_count == 2:
		return [
			lerpf(usable_left, ROAD_CENTER_X, 0.22),
			lerpf(ROAD_CENTER_X, usable_right, 0.78)
		]
	if gate_count == 3:
		return [
			usable_left,
			ROAD_CENTER_X,
			usable_right
		]
	var positions: Array[float] = []
	for index in gate_count:
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
