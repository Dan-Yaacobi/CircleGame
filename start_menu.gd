extends Node2D

@onready var next_button: Button = $Control/NextButton
@onready var choose_button: Button = $Control/ChooseButton
@onready var sprite: Sprite2D = $Sprite2D
const LEVEL_1: String = "res://Scenes/Levels/Level1.tscn"

const SCRATCH_CIRCLE: String = "res://Scenes/ScratchCircle.tscn"

func _on_next_button_pressed() -> void:
	var total_frames = sprite.hframes * sprite.vframes
	sprite.frame = (sprite.frame + 1) % total_frames

func _on_choose_button_pressed() -> void:
	GlobalVariables.frame_number = sprite.frame
	get_tree().change_scene_to_file(LEVEL_1)
