class_name CollectedControl extends Control
@onready var sprite: Sprite2D = $Sprite2D

func set_sprite(frame: int) -> void:
	sprite.frame = frame
