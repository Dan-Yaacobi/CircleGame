@tool
class_name Prize extends Node2D

signal prize_revealed(_bad: bool, id: int)

@export var frame: int:
	set(value):
		frame = value
		$Sprite2D.frame = frame
		
@export var size: Vector2:
	set(value):
		size = value
		scale = value
@export var bad: bool

@export_range(0.0, 1.0) var reveal_percentage: float = 0.5  # fraction of this prize that must be scratched off
@export var finish_reveal_radius: float = 40.0  # bonus reveal radius once the threshold is hit
@onready var reveal_effect: CPUParticles2D = $RevealEffect

var revealed: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	sprite.frame = frame
	
# Called by the ScratchCircle each time the cover mask changes.
func try_complete_reveal(scratch_circle: Node) -> void:
	if revealed:
		return
	var local_pos: Vector2 = scratch_circle.to_local(global_position)
	var fraction: float = scratch_circle.get_revealed_fraction(local_pos, _footprint_radius())
	if fraction >= reveal_percentage:
		revealed = true
		prize_revealed.emit(bad, frame)
		scratch_circle.reveal_area(local_pos, finish_reveal_radius)
		reveal_effect.emitting = true

func _footprint_radius() -> float:
	var tex_size: Vector2 = sprite.texture.get_size()
	return max(tex_size.x, tex_size.y) * 0.5 * max(size.x, size.y)
