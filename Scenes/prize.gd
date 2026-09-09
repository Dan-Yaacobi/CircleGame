extends Node2D

@export var size: Vector2
@export_range(0.0, 1.0) var reveal_percentage: float = 0.5  # fraction of this prize that must be scratched off
@export var finish_reveal_radius: float = 40.0  # bonus reveal radius once the threshold is hit

var revealed: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	scale = size

# Called by the ScratchCircle each time the cover mask changes.
func try_complete_reveal(scratch_circle: Node) -> void:
	if revealed:
		return
	var local_pos: Vector2 = scratch_circle.to_local(global_position)
	var fraction: float = scratch_circle.get_revealed_fraction(local_pos, _footprint_radius())
	if fraction >= reveal_percentage:
		revealed = true
		scratch_circle.reveal_area(local_pos, finish_reveal_radius)

func _footprint_radius() -> float:
	var tex_size: Vector2 = sprite.texture.get_size()
	return max(tex_size.x, tex_size.y) * 0.5 * max(scale.x, scale.y)
