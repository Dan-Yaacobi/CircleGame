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

@export_group("Glow")
@export var glow_color: Color = Color(1.0, 0.85, 0.3, 1.0):
	set(value):
		glow_color = value
		_update_glow_uniform("glow_color", value)
@export_range(0.0, 16.0, 0.1) var outline_width: float = 2.0:  # px, crisp core ring thickness
	set(value):
		outline_width = value
		_update_glow_uniform("outline_width", value)
@export_range(0.0, 32.0, 0.1) var glow_spread: float = 6.0:  # px, extra soft halo past the ring
	set(value):
		glow_spread = value
		_update_glow_uniform("glow_spread", value)
@export_range(0.01, 1.0, 0.01) var glow_softness: float = 0.5:  # 0 = hard ring, 1 = soft cloud
	set(value):
		glow_softness = value
		_update_glow_uniform("glow_softness", value)
@export_range(0.0, 5.0, 0.05) var glow_intensity: float = 1.5:  # brightness of the glow
	set(value):
		glow_intensity = value
		_update_glow_uniform("glow_intensity", value)
@export_range(0.0, 10.0, 0.1) var pulse_speed: float = 2.0:  # cycles/sec, 0 disables pulsing
	set(value):
		pulse_speed = value
		_update_glow_uniform("pulse_speed", value)
@export_range(0.0, 1.0, 0.01) var pulse_amount: float = 0.35:  # how much the pulse changes intensity
	set(value):
		pulse_amount = value
		_update_glow_uniform("pulse_amount", value)
@export_range(4, 32, 1) var ring_samples: int = 10:  # angular resolution of the silhouette scan (cost knob)
	set(value):
		ring_samples = value
		_update_glow_uniform("ring_samples", value)
@export_range(0.0, 1.0, 0.01) var alpha_threshold: float = 0.5:  # alpha above which a texel counts as "sprite"
	set(value):
		alpha_threshold = value
		_update_glow_uniform("alpha_threshold", value)

@export_range(0.0, 1.0) var reveal_percentage: float = 0.5  # fraction of this prize that must be scratched off
@export var finish_reveal_radius: float = 40.0  # bonus reveal radius once the threshold is hit
@onready var reveal_effect: CPUParticles2D = $RevealEffect
@onready var bad_reveal_effect: CPUParticles2D = $BadRevealEffect

var revealed: bool = false

@onready var sprite: Sprite2D = $Sprite2D

# Half the pixel size of this frame's actual opaque artwork (not the frame's
# nominal size, which includes any transparent padding and — for a sprite
# sheet — every other frame too). Computed once from real pixel data.
var _footprint_px_radius: float = -1.0

func _ready() -> void:
	sprite.frame = frame
	_footprint_px_radius = _measure_footprint_px_radius()
	_update_glow_frame_uniforms()
	_apply_all_glow_uniforms()

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
		if bad:
			bad_reveal_effect.emitting = true
		else:
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

# Pushes every glow export to the shader at once — used on _ready() to cover
# values that were assigned (from the scene file or defaults) before `sprite`
# existed, since the individual setters above no-op until then.
func _apply_all_glow_uniforms() -> void:
	_update_glow_uniform("glow_color", glow_color)
	_update_glow_uniform("outline_width", outline_width)
	_update_glow_uniform("glow_spread", glow_spread)
	_update_glow_uniform("glow_softness", glow_softness)
	_update_glow_uniform("glow_intensity", glow_intensity)
	_update_glow_uniform("pulse_speed", pulse_speed)
	_update_glow_uniform("pulse_amount", pulse_amount)
	_update_glow_uniform("ring_samples", ring_samples)
	_update_glow_uniform("alpha_threshold", alpha_threshold)

func _update_glow_uniform(param_name: String, value) -> void:
	if not sprite:
		return
	var mat := sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter(param_name, value)

# Tells the glow shader exactly which sub-rectangle of the shared sprite
# sheet is "this icon", so its silhouette scan never bleeds into a neighbor.
func _update_glow_frame_uniforms() -> void:
	var mat := sprite.material as ShaderMaterial
	if not mat or not sprite.texture:
		return
	var hframes: int = max(sprite.hframes, 1)
	var vframes: int = max(sprite.vframes, 1)
	var frame_index: int = max(sprite.frame, 0)
	var col: int = frame_index % hframes
	var row: int = int(frame_index / float(hframes))
	var frame_uv_size := Vector2(1.0 / hframes, 1.0 / vframes)
	var frame_uv_origin := Vector2(col, row) * frame_uv_size
	var tex_size: Vector2 = sprite.texture.get_size()
	var frame_pixel_size := Vector2(tex_size.x / hframes, tex_size.y / vframes)

	mat.set_shader_parameter("frame_uv_origin", frame_uv_origin)
	mat.set_shader_parameter("frame_uv_size", frame_uv_size)
	mat.set_shader_parameter("frame_pixel_size", frame_pixel_size)

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
