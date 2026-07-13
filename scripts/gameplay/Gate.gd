extends Area2D
class_name Gate

var run_manager: Node
var gate_manager: Node
var effect_definition: Dictionary = {}
var row_id := 0
var current_value := 0
var pulse := 0.0
var collected := false
var damage_progress := 0.0

func initialize(run: Node, manager: Node, effect: Dictionary, world_position: Vector2, gate_row_id: int = 0) -> void:
	run_manager = run
	gate_manager = manager
	effect_definition = effect.duplicate(true)
	row_id = gate_row_id
	current_value = int(effect_definition.get("start_value", 0))
	damage_progress = 0.0
	collected = false
	global_position = world_position
	# Gates remain Areas for projectile/world queries, but selection is exclusively
	# resolved from the stable squad anchor in update_gate().
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = true

func update_gate(delta: float) -> void:
	if collected:
		return
	pulse += delta * 4.0
	global_position += Vector2.DOWN * run_manager.scroll_speed * delta
	queue_redraw()
	var anchor: Vector2 = run_manager.squad_manager.get_anchor_position()
	var gate_width: float = float(GameManager.gate_data.get("gate_width", 120.0))
	var neutral_gap: float = float(GameManager.gate_data.get("lane_margin", 14.0)) * 0.5
	if abs(anchor.x - global_position.x) <= gate_width * 0.5 - neutral_gap and abs(anchor.y - global_position.y) <= 68.0:
		collect()
		return
	if global_position.y > 1400.0:
		gate_manager.unregister_gate(self)
		queue_free()

func take_damage(_amount: float, _explosive_hit: bool = false) -> void:
	if collected:
		return
	var damage: float = max(_amount, 0.0)
	var step_damage: float = gate_manager.get_damage_per_value_step(effect_definition)
	effect_definition["damage_per_value_step"] = step_damage
	damage_progress += damage
	var improved := false
	while damage_progress >= step_damage:
		damage_progress -= step_damage
		improved = _apply_improvement_step() or improved
	if improved:
		AudioManager.play_sfx("zombie_hit")
		run_manager.ui_manager.spawn_reward_popup(global_position + Vector2(0, -26), _format_value_label(), _get_gate_color())
		queue_redraw()

func collect() -> void:
	if collected:
		return
	collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var result: Dictionary = gate_manager.consume_gate(self)
	run_manager.ui_manager.spawn_reward_popup(global_position, String(result.get("popup", "GATE")), Color(result.get("color", "#ffffff")))
	if int(result.get("delta", 0)) < 0:
		run_manager.add_screen_shake(0.08, 3.0)
	clear_without_collect()

func clear_without_collect() -> void:
	collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	gate_manager.unregister_gate(self)
	queue_free()

func get_effect_definition() -> Dictionary:
	return effect_definition.duplicate(true)

func _draw() -> void:
	var base_color := _get_gate_color()
	var outline: Color = base_color.lightened(0.15)
	var half_width: float = float(GameManager.gate_data.get("gate_width", 120.0)) * 0.5
	draw_rect(Rect2(-half_width, -56, half_width * 2.0, 112), Color(base_color, 0.18))
	draw_rect(Rect2(-half_width, -56, half_width * 2.0, 112), outline, false, 5.0)
	draw_rect(Rect2(-half_width + 14.0, -56, 8, 112), outline)
	draw_rect(Rect2(half_width - 22.0, -56, 8, 112), outline)
	draw_circle(Vector2.ZERO, 18.0 + sin(pulse) * 3.0, Color(base_color, 0.25))
	var step_damage: float = max(0.01, gate_manager.get_damage_per_value_step(effect_definition))
	var progress_ratio: float = clampf(damage_progress / step_damage, 0.0, 1.0)
	draw_rect(Rect2(-34, 34, 68, 10), Color(0.08, 0.08, 0.08, 0.75))
	draw_rect(Rect2(-34, 34, 68.0 * progress_ratio, 10), Color.WHITE if progress_ratio >= 0.98 else outline)
	draw_rect(Rect2(-34, 34, 68, 10), outline, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-44, -70), _format_value_label(), HORIZONTAL_ALIGNMENT_LEFT, 96, 18, Color.WHITE)

func _format_value_label() -> String:
	return gate_manager.format_gate_label(effect_definition)

func _get_gate_color() -> Color:
	return Color(effect_definition.get("color", "#ffd166"))

func _apply_improvement_step() -> bool:
	var gate_type: String = String(effect_definition.get("type", ""))
	match gate_type:
		"add_soldiers":
			var previous_value: int = int(effect_definition.get("value", 0))
			var next_positive: int = int(effect_definition.get("value", 0)) + int(effect_definition.get("improvement_step", 1))
			effect_definition["value"] = mini(next_positive, int(GameManager.gate_data.get("max_value", 12)))
			current_value = int(effect_definition["value"])
			effect_definition["start_value"] = current_value
			effect_definition["label"] = gate_manager.format_gate_label(effect_definition)
			return current_value > previous_value
		"remove_soldiers":
			var next_value: int = max(0, int(effect_definition.get("value", 0)) - int(effect_definition.get("improvement_step", 1)))
			if next_value == int(effect_definition.get("value", 0)):
				return false
			effect_definition["value"] = next_value
			current_value = -next_value
			effect_definition["start_value"] = current_value
			effect_definition["label"] = gate_manager.format_gate_label(effect_definition)
			effect_definition["color"] = "#ffd166" if next_value == 0 else "#ff8080"
			return true
		"multiply_soldiers", "coins", "heal_soldiers", "barricade_repair":
			effect_definition["value"] = int(effect_definition.get("value", 0)) + int(effect_definition.get("improvement_step", 1))
		"barricade_cooldown_reset":
			return false
		"fire_rate_boost", "damage_boost", "temporary_shield":
			effect_definition["value"] = float(effect_definition.get("value", 0.0)) + float(effect_definition.get("improvement_step", 0.0))
		"weapon_pickup", "risk_gate":
			return false
		_:
			return false
	effect_definition["label"] = gate_manager.format_gate_label(effect_definition)
	return true
