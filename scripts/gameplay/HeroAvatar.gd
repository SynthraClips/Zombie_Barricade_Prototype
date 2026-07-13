extends Node2D
class_name HeroAvatar

var run_manager: Node
var hero_id := ""
var hero_name := "Hero"
var call_in_effect := ""
var pulse := 0.0

func initialize(run: Node, definition_id: String, definition: Dictionary) -> void:
	run_manager = run
	hero_id = definition_id
	hero_name = String(definition.get("name", "Hero"))
	call_in_effect = String(definition.get("call_in_effect", ""))
	z_index = 50
	position = _target_position()
	queue_redraw()

func _process(delta: float) -> void:
	if run_manager == null or not is_instance_valid(run_manager):
		queue_free()
		return
	pulse += delta * 5.0
	position = position.lerp(_target_position(), clampf(delta * 8.0, 0.0, 1.0))
	queue_redraw()

func _target_position() -> Vector2:
	var anchor: Vector2 = run_manager.squad_manager.get_anchor_position()
	var desired := anchor + Vector2(0.0, -72.0)
	desired.x = run_manager.road.clamp_lane_x(desired.x, desired.y, 28.0)
	return desired

func _draw() -> void:
	var color := Color("ffd166")
	if hero_id == "engineer_vale":
		color = Color("72d6ff")
	elif hero_id == "mara_hale":
		color = Color("ff7d7d")
	draw_circle(Vector2.ZERO, 25.0 + sin(pulse) * 2.0, Color(color, 0.22))
	draw_circle(Vector2(0, -18), 10.0, color.lightened(0.25))
	draw_rect(Rect2(-12, -8, 24, 30), color)
	draw_line(Vector2(-10, 2), Vector2(-25, 15), color.lightened(0.2), 7.0)
	draw_line(Vector2(10, 2), Vector2(25, 15), color.lightened(0.2), 7.0)
	match call_in_effect:
		"fire_rate_boost":
			for offset in [-18.0, 0.0, 18.0]:
				draw_line(Vector2(offset, -30), Vector2(offset, -48 - sin(pulse) * 6.0), Color("ffd166"), 3.0)
		"barricade_repair":
			draw_rect(Rect2(-4, -36, 8, 22), Color.WHITE)
			draw_rect(Rect2(-11, -29, 22, 8), Color.WHITE)
		"damage_boost":
			draw_arc(Vector2.ZERO, 31.0 + sin(pulse) * 5.0, 0.0, TAU, 24, Color("ff9b73", 0.8), 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(-52, -42), hero_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 104, 14, Color.WHITE)
