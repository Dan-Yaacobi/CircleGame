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

# Half the pixel size of this frame's actual opaque artwork (not the frame's
# nominal size, which includes any transparent padding and — for a sprite
# sheet — every other frame too). Computed once from real pixel data.
var _footprint_px_radius: float = -1.0

func _ready() -> void:
	sprite.frame = frame
	_footprint_px_radius = _measure_footprint_px_radius()

# Called by the ScratchCircle each time the cover mask changes.
func try_complete_reveal(scratch_circle: Node) -> void:
	if revealed:
		return
	var local_pos: Vector2 = scratch_circle.to_local(global_position)
	var footprint: float = _footprint_radius()
	var fraction: float = scratch_circle.get_revealed_fraction(local_pos, footprint)
	if fraction >= reveal_percentage:
		revealed = true
		prize_revealed.emit(bad, frame)
		scratch_circle.reveal_area(local_pos, _scaled_finish_reveal_radius(footprint))
		reveal_effect.emitting = true

func _footprint_radius() -> float:
	if _footprint_px_radius < 0.0:
		_footprint_px_radius = _measure_footprint_px_radius()
	return _footprint_px_radius * max(scale.x, scale.y)

# finish_reveal_radius is authored at this prize's default size, so it needs
# to grow/shrink with `size` the same way the footprint does — and can never
# go below the footprint itself, or a bigger prize wouldn't fully clear.
func _scaled_finish_reveal_radius(footprint_radius: float) -> float:
	return max(finish_reveal_radius * max(scale.x, scale.y), footprint_radius)

# Scans this frame's own pixels for actual opaque bounds — correctly handles
# both sprite sheets (hframes/vframes) and art that doesn't fill its frame.
func _measure_footprint_px_radius() -> float:
	var tex := sprite.texture
	if not tex:
		return 0.0
	var hframes: int = max(sprite.hframes, 1)
	var vframes: int = max(sprite.vframes, 1)
	var frame_w: int = int(tex.get_width() / float(hframes))
	var frame_h: int = int(tex.get_height() / float(vframes))

	var img := tex.get_image()
	if not img:
		# Texture data isn't CPU-readable (e.g. VRAM compression) — fall back
		# to the frame's nominal size rather than the whole sheet's.
		return max(frame_w, frame_h) * 0.5

	var frame_index: int = max(sprite.frame, 0)
	var fx: int = (frame_index % hframes) * frame_w
	var fy: int = int(frame_index / float(hframes)) * frame_h

	var min_x := frame_w
	var max_x := -1
	var min_y := frame_h
	var max_y := -1
	for y in range(frame_h):
		for x in range(frame_w):
			if img.get_pixel(fx + x, fy + y).a > 0.05:
				min_x = min(min_x, x)
				max_x = max(max_x, x)
				min_y = min(min_y, y)
				max_y = max(max_y, y)

	if max_x < min_x:
		return max(frame_w, frame_h) * 0.5  # fully transparent frame — fall back
	return max(max_x - min_x + 1, max_y - min_y + 1) * 0.5
