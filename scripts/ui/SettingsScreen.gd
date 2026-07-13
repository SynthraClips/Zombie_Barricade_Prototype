extends Control

@onready var shake_check: CheckBox = $Margin/Panel/VBox/Shake
@onready var auto_fire_check: CheckBox = $Margin/Panel/VBox/AutoFire
@onready var hit_flash_check: CheckBox = $Margin/Panel/VBox/HitFlash
@onready var volume_slider: HSlider = $Margin/Panel/VBox/Volume

func _ready() -> void:
	shake_check.button_pressed = bool(SaveManager.save_data.get("settings", {}).get("screenshake", true))
	auto_fire_check.button_pressed = bool(SaveManager.save_data.get("settings", {}).get("auto_fire", GameManager.game_config.get("auto_fire_default", true)))
	hit_flash_check.button_pressed = bool(SaveManager.save_data.get("settings", {}).get("hit_flash", true))
	volume_slider.value = float(SaveManager.save_data.get("settings", {}).get("sfx_volume", 0.8))

func _on_shake_toggled(toggled_on: bool) -> void:
	SaveManager.save_data["settings"]["screenshake"] = toggled_on
	SaveManager.save_game()

func _on_auto_fire_toggled(toggled_on: bool) -> void:
	SaveManager.save_data["settings"]["auto_fire"] = toggled_on
	SaveManager.save_game()

func _on_hit_flash_toggled(toggled_on: bool) -> void:
	SaveManager.save_data["settings"]["hit_flash"] = toggled_on
	SaveManager.save_game()

func _on_volume_changed(value: float) -> void:
	SaveManager.save_data["settings"]["sfx_volume"] = value
	AudioManager.set_sfx_volume(value)
	SaveManager.save_game()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
