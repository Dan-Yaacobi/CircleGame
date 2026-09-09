class_name ScratchCircle extends Node2D

@export var curr_radius: float = 100.0
@export var max_shoots: int = 5
@export var mask_resolution: int = 96  # low-res paintable mask, kept cheap on purpose

@onready var background_sprite: Sprite2D = $BackgroundSprite
@onready var cover_sprite: Sprite2D = $CoverSprite
@onready var circle_shape: Line2D = $Line2D

var shoots_used: int = 0
var mask_image: Image
var mask_texture: ImageTexture

func _ready() -> void:
	circle_shape.set_radius_immediate(curr_radius)

	var bg_mat := background_sprite.material as ShaderMaterial
	bg_mat.set_shader_parameter("texture_size", background_sprite.texture.get_size())
	bg_mat.set_shader_parameter("circle_center", Vector2(0.5, 0.5))
	bg_mat.set_shader_parameter("radius_px", curr_radius)

	_setup_scratch_mask()

func _setup_scratch_mask() -> void:
	mask_image = Image.create_empty(mask_resolution, mask_resolution, false, Image.FORMAT_R8)
	mask_image.fill(Color(1, 1, 1, 1))  # fully covered
	mask_texture = ImageTexture.create_from_image(mask_image)

	cover_sprite.texture = mask_texture
	cover_sprite.scale = Vector2.ONE * (curr_radius * 2.0 / mask_resolution)

func can_shoot() -> bool:
	return shoots_used < max_shoots

func _on_shoot_started() -> void:
	shoots_used += 1

# Called by the player every physics frame while flying through the center.
func _on_player_crossing(world_pos: Vector2, brush_radius: float) -> void:
	var local_pos: Vector2 = to_local(world_pos)
	var uv: Vector2 = local_pos / (curr_radius * 2.0) + Vector2(0.5, 0.5)
	var center_px: Vector2 = uv * mask_resolution
	var brush_px: float = brush_radius / (curr_radius * 2.0) * mask_resolution
	_stamp_circle(center_px, brush_px)
	mask_texture.update(mask_image)

func _stamp_circle(center_px: Vector2, radius_px: float) -> void:
	var min_x := clampi(int(center_px.x - radius_px), 0, mask_resolution - 1)
	var max_x := clampi(int(center_px.x + radius_px), 0, mask_resolution - 1)
	var min_y := clampi(int(center_px.y - radius_px), 0, mask_resolution - 1)
	var max_y := clampi(int(center_px.y + radius_px), 0, mask_resolution - 1)
	var r_sq: float = radius_px * radius_px
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Vector2(x - center_px.x, y - center_px.y).length_squared() <= r_sq:
				mask_image.set_pixel(x, y, Color(0, 0, 0, 0))  # revealed
