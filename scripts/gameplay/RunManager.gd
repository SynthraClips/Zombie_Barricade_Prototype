extends Node2D
class_name RunManager

signal coins_changed(value: int)
signal distance_changed(value: float)
signal wave_changed(value: int)
signal squad_changed(value: int)
signal run_ended(victory: bool)

@onready var road: Node2D = $Road
@onready var camera: Camera2D = $Camera2D
@onready var squad_manager: Node = $SquadManager
@onready var weapon_manager: Node = $WeaponManager
@onready var enemy_manager: Node = $EnemyManager
@onready var wave_spawner: Node = $WaveSpawner
@onready var barricade_manager: Node = $BarricadeManager
@onready var reward_manager: Node = $RewardManager
@onready var gate_manager: Node = $GateManager
@onready var ui_manager: CanvasLayer = $UI

var coins := 0
var distance_travelled := 0.0
var elapsed_time := 0.0
var current_wave := 1
var running := true
var target_distance := 300.0
var scroll_speed := 90.0
var max_squad_size := 8
var aim_position := Vector2(360, 520)
var fire_input_held := false
var shake_time := 0.0
var shake_strength := 0.0
var run_stats := {
	"kills": 0,
	"boss_kills": 0,
	"obstacles_destroyed": 0,
	"coins_earned": 0
}

func _ready() -> void:
	target_distance = float(GameManager.game_config.get("target_distance", 300))
	scroll_speed = float(GameManager.game_config.get("base_scroll_speed", 90.0))
	max_squad_size = int(GameManager.game_config.get("max_squad_size", 8))
	squad_manager.setup(self)
	weapon_manager.setup(self)
	enemy_manager.setup(self)
	wave_spawner.setup(self)
	barricade_manager.setup(self)
	reward_manager.setup(self)
	gate_manager.setup(self)
	ui_manager.setup(self)
	aim_position = Vector2(360, road.get_squad_y() - 260.0)
	coins_changed.emit(coins)
	distance_changed.emit(distance_travelled)
	wave_changed.emit(current_wave)
	squad_changed.emit(squad_manager.get_soldier_count())

func _process(delta: float) -> void:
	if not running:
		_update_camera(delta)
		return
	_sync_pointer_target()
	if Input.is_action_just_pressed("deploy_barricade"):
		if not barricade_manager.deploy_current_barricade():
			ui_manager.show_status_message("BARRICADE RECHARGING", Color("ffb36b"))
	if Input.is_action_just_pressed("pause_run"):
		ui_manager.toggle_pause()
	_update_camera(delta)
	if get_tree().paused:
		return
	elapsed_time += delta
	distance_travelled += scroll_speed * delta / 10.0
	road.queue_redraw()
	squad_manager.update_squad(delta)
	reward_manager.update_rewards(delta)
	gate_manager.update_gates(delta)
	barricade_manager.update_barricade(delta)
	enemy_manager.update_enemies(delta)
	wave_spawner.update_spawner(delta)
	distance_changed.emit(distance_travelled)
	if distance_travelled >= target_distance:
		finish_run(true)

func _update_camera(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	else:
		camera.offset = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if not running or get_tree().paused:
		return
	if event is InputEventMouseMotion:
		update_aim_position(event.position)
		squad_manager.handle_pointer_input(event.position)
	elif event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			update_aim_position(button_event.position)
			set_fire_input_held(button_event.pressed)
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			update_aim_position(touch_event.position)
			squad_manager.handle_pointer_input(touch_event.position, true)
			set_fire_input_held(true)
		else:
			squad_manager.release_touch_input()
			set_fire_input_held(false)
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		update_aim_position(drag_event.position)
		squad_manager.handle_pointer_input(drag_event.position, true)
		set_fire_input_held(true)

func _sync_pointer_target() -> void:
	if squad_manager.touch_input_active:
		return
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	update_aim_position(mouse_position)
	squad_manager.handle_pointer_input(mouse_position)
	set_fire_input_held(Input.is_action_pressed("fire_weapon"))

func update_aim_position(screen_position: Vector2) -> void:
	aim_position = screen_position

func get_aim_position() -> Vector2:
	return aim_position

func should_fire() -> bool:
	if not running or get_tree().paused:
		return false
	if is_auto_fire_enabled():
		return true
	return fire_input_held

func is_auto_fire_enabled() -> bool:
	return bool(SaveManager.save_data.get("settings", {}).get("auto_fire", GameManager.game_config.get("auto_fire_default", true)))

func set_fire_input_held(value: bool) -> void:
	fire_input_held = value

func extend_target_distance(amount: int) -> void:
	target_distance += max(amount, 0)
	distance_changed.emit(distance_travelled)

func add_screen_shake(duration: float, strength: float) -> void:
	if not SaveManager.save_data.get("settings", {}).get("screenshake", true):
		return
	shake_time = max(shake_time, duration)
	shake_strength = max(shake_strength, strength)

func add_coins(amount: int) -> void:
	var bonus_multiplier: float = 1.0 + UpgradeManager.get_upgrade_value("coin_gain")
	var final_amount: int = int(round(amount * bonus_multiplier))
	coins += final_amount
	run_stats["coins_earned"] += final_amount
	coins_changed.emit(coins)

func spend_run_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

func set_wave(value: int) -> void:
	current_wave = value
	wave_changed.emit(current_wave)

func register_kill(enemy_id: String) -> void:
	run_stats["kills"] += 1
	SaveManager.save_data["stats"]["lifetime_kills"] += 1
	MissionManager.increment_progress("kills", 1)
	if enemy_id == "boss":
		run_stats["boss_kills"] += 1
		SaveManager.save_data["stats"]["boss_kills"] += 1
		MissionManager.increment_progress("boss_kills", 1)

func register_obstacle_destroyed() -> void:
	run_stats["obstacles_destroyed"] += 1
	SaveManager.save_data["stats"]["lifetime_obstacles_destroyed"] += 1
	MissionManager.increment_progress("obstacles_destroyed", 1)

func on_squad_count_changed() -> void:
	squad_changed.emit(squad_manager.get_soldier_count())

func get_difficulty_multiplier() -> float:
	var distance_factor: float = distance_travelled / max(target_distance, 1.0)
	var wave_factor: float = float(current_wave - 1) * 0.12
	var time_factor: float = elapsed_time / 90.0
	return 1.0 + distance_factor * 0.55 + wave_factor + time_factor * 0.25

func finish_run(victory: bool) -> void:
	if not running:
		return
	running = false
	var summary := {
		"victory": victory,
		"distance": int(distance_travelled),
		"coins_earned": run_stats["coins_earned"],
		"kills": run_stats["kills"],
		"boss_kills": run_stats["boss_kills"],
		"obstacles_destroyed": run_stats["obstacles_destroyed"],
		"final_soldiers": squad_manager.get_soldier_count()
	}
	GameManager.end_run(victory, summary)
	run_ended.emit(victory)
	ui_manager.show_end_screen(victory, summary)
