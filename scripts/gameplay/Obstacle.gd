extends Node2D
class_name Obstacle

var run_manager: Node
var obstacle_type := "barrel"
var hp := 30.0
var max_hp := 30.0
var reward_id := "coins_small"
var hit_flash := 0.0

func initialize(run: Node, type_id: String, spawn_position: Vector2) -> void:
	run_manager = run
	obstacle_type = type_id
	global_position = spawn_position
	if obstacle_type == "crate":
		max_hp = 40.0
	else:
		max_hp = 28.0
	hp = max_hp
	var reward_table: Array = GameManager.reward_data.get("obstacle_reward_table", [])
	reward_id = String(reward_table[randi() % max(reward_table.size(), 1)])

func update_obstacle(delta: float) -> void:
	position += Vector2.DOWN * run_manager.scroll_speed * delta
	hit_flash = max(hit_flash - delta * 3.0, 0.0)
	queue_redraw()
	if position.y > 1380:
		queue_free()

func take_damage(amount: float) -> void:
	hp -= amount
	hit_flash = 1.0
	run_manager.ui_manager.spawn_damage_number(global_position, amount, Color("ffd98f"))
	if hp <= 0.0:
		run_manager.register_obstacle_destroyed()
		run_manager.reward_manager.spawn_reward(reward_id, global_position)
		queue_free()

func _draw() -> void:
	var base_color := Color("8b5a2b") if obstacle_type == "crate" else Color("a75b3f")
	if hit_flash > 0.0:
		base_color = base_color.lerp(Color.WHITE, hit_flash)
	draw_rect(Rect2(-22, -22, 44, 44), base_color)
	draw_rect(Rect2(-26, -36, 52, 6), Color("22262b"))
	draw_rect(Rect2(-26, -36, 52 * (hp / max(max_hp, 1.0)), 6), Color("f4b266"))
	draw_string(ThemeDB.fallback_font, Vector2(-10, -42), str(int(hp)), HORIZONTAL_ALIGNMENT_LEFT, 32, 16, Color.WHITE)
