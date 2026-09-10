@tool
class_name ScratchCircle extends Node2D

@export var curr_radius: float = 100.0:
	set(value):
		curr_radius = value
		_update_boundary()
@export var max_shoots: int = 5
@export var mask_resolution: int = 96  # low-res paintable mask, kept cheap on purpose

@onready var background_sprite: Sprite2D = $BackgroundSprite
@onready var cover_sprite: Sprite2D = $CoverSprite
@onready var circle_shape: Line2D = $Line2D
@onready var prizes: Node = $Prizes
@onready var player: Player = $Player

var shoots_used: int = 0
var mask_image: Image
var mask_texture: ImageTexture

func _ready() -> void:
	
	var bg_mat := background_sprite.material as ShaderMaterial
	bg_mat.set_shader_parameter("texture_size", background_sprite.texture.get_size())
	bg_mat.set_shader_parameter("circle_center", Vector2(0.5, 0.5))

	_setup_scratch_mask()
	_update_boundary()
	if !Engine.is_editor_hint():
		player.set_sprite_frame()
		
func _setup_scratch_mask() -> void:
	mask_image = Image.create_empty(mask_resolution, mask_resolution, false, Image.FORMAT_R8)
	mask_image.fill(Color(1, 1, 1, 1))  # fully covered
	mask_texture = ImageTexture.create_from_image(mask_image)
	cover_sprite.texture = mask_texture

# Keeps the boundary line, background mask and cover sprite in sync with
# curr_radius — runs live in the editor (via @tool) so prizes can be placed
# against the actual ticket bounds without pressing Play.
func _update_boundary() -> void:
	if circle_shape:
		circle_shape.set_radius_immediate(curr_radius)
	if background_sprite and background_sprite.material:
		(background_sprite.material as ShaderMaterial).set_shader_parameter("radius_px", curr_radius)
	if cover_sprite and mask_texture:
		cover_sprite.scale = Vector2.ONE * (curr_radius * 2.0 / mask_resolution)

func bend_boundary(angle: float) -> void:
	circle_shape.bend_at(angle)

func can_shoot() -> bool:
	return true
	return shoots_used < max_shoots

func _on_shoot_started() -> void:
	shoots_used += 1

# Called by the player every physics frame while flying through the center.
func _on_player_crossing(world_pos: Vector2, brush_radius: float) -> void:
	var local_pos: Vector2 = to_local(world_pos)
	_stamp_circle(_local_to_mask_px(local_pos), _radius_to_mask_px(brush_radius))
	mask_texture.update(mask_image)
	_check_prizes()

func _check_prizes() -> void:
	if not prizes:
		return
	for prize in prizes.get_children():
		if prize.has_method("try_complete_reveal"):
			prize.try_complete_reveal(self)

# Fraction (0..1) of the mask that is revealed within `radius` of `local_center`.
func get_revealed_fraction(local_center: Vector2, radius: float) -> float:
	var center_px := _local_to_mask_px(local_center)
	var radius_px := _radius_to_mask_px(radius)
	var min_x := clampi(int(center_px.x - radius_px), 0, mask_resolution - 1)
	var max_x := clampi(int(center_px.x + radius_px), 0, mask_resolution - 1)
	var min_y := clampi(int(center_px.y - radius_px), 0, mask_resolution - 1)
	var max_y := clampi(int(center_px.y + radius_px), 0, mask_resolution - 1)
	var r_sq: float = radius_px * radius_px
	var total := 0
	var revealed := 0
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Vector2(x - center_px.x, y - center_px.y).length_squared() <= r_sq:
				total += 1
				if mask_image.get_pixel(x, y).r < 0.5:
					revealed += 1
	if total == 0:
		return 0.0
	return float(revealed) / float(total)

# Force-reveals a circular area, e.g. a prize's bonus radius once completed.
func reveal_area(local_center: Vector2, radius: float) -> void:
	_stamp_circle(_local_to_mask_px(local_center), _radius_to_mask_px(radius))
	mask_texture.update(mask_image)

func _local_to_mask_px(local_pos: Vector2) -> Vector2:
	var uv: Vector2 = local_pos / (curr_radius * 2.0) + Vector2(0.5, 0.5)
	return uv * mask_resolution

func _radius_to_mask_px(radius: float) -> float:
	return radius / (curr_radius * 2.0) * mask_resolution

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
