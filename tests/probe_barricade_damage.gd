extends SceneTree

func _initialize() -> void:
	var field: Node = load("res://scenes/gameplay/Battlefield.tscn").instantiate()
	root.add_child(field)
	await process_frame
	field.target_distance = 60
	field.scroll_speed = 150.0
	await create_timer(1.0).timeout
	var first_enemy: Node = field.enemy_manager.spawn_enemy("walker", Vector2(360, 720), 0.25)
	field.squad_manager.handle_pointer_input(first_enemy.global_position, true)
	field.update_aim_position(first_enemy.global_position)
	field.set_fire_input_held(true)
	await create_timer(2.0).timeout
	var barricade: Node = field.barricade_manager.active_barricade
	var initial_hp: float = barricade.hp if barricade != null and is_instance_valid(barricade) else -1.0
	var second_enemy: Node = field.enemy_manager.spawn_enemy("walker", Vector2(360, 860), 0.5)
	if barricade != null and is_instance_valid(barricade):
		second_enemy.global_position = barricade.global_position - Vector2(0.0, 24.0)
		second_enemy.call("_attack_barricade_or_explode")
	await process_frame
	var before_manual_hp: float = barricade.hp if barricade != null and is_instance_valid(barricade) else -1.0
	var valid_after_enemy := barricade != null and is_instance_valid(barricade)
	if valid_after_enemy:
		barricade.take_damage(1.0)
		await process_frame
	var after_manual_hp: float = barricade.hp if barricade != null and is_instance_valid(barricade) else -1.0
	var path := "C:/Users/scott/Documents/Small Game/project/reports/probe_barricade_damage.txt"
	DirAccess.make_dir_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("initial_hp=%s\n" % str(initial_hp))
		file.store_string("before_manual_hp=%s\n" % str(before_manual_hp))
		file.store_string("after_manual_hp=%s\n" % str(after_manual_hp))
		file.store_string("valid_after_enemy=%s\n" % str(valid_after_enemy))
		file.store_string("active_barricade_null=%s\n" % str(field.barricade_manager.active_barricade == null))
		file.close()
	quit()
