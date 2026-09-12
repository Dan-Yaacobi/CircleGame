@tool
class_name ScratchCircle extends Node2D

@export var curr_radius: float = 100.0:
	set(value):
		curr_radius = value
		_update_boundary()
@export var max_shoots: int = 5
@export var mask_resolution: int = 96  # low-res paintable mask, kept cheap on purpose
@export var bad_prize_to_lose: int = 3
@export var good_prize_to_win: int = 3
@export_group("Background")
@export var background_texture: Texture2D:
	set(value):
		background_texture = value
		_update_background_texture()
@export_range(0.0, 20.0, 0.1) var edge_softness: float = 2.0:
	set(value):
		edge_softness = value
		_update_boundary()

@export_subgroup("Image Fit")
@export var image_offset: Vector2 = Vector2.ZERO:  # pan the artwork within the ticket, in UV units
	set(value):
		image_offset = value
		_update_image_fit()
@export_range(0.05, 10.0, 0.01) var image_zoom: float = 1.0:  # >1 zooms in
	set(value):
		image_zoom = value
		_update_image_fit()
@export_range(-PI, PI, 0.01) var image_rotation: float = 0.0:  # radians
	set(value):
		image_rotation = value
		_update_image_fit()

@onready var background_sprite: Sprite2D = $BackgroundSprite
@onready var cover_sprite: Sprite2D = $CoverSprite
@onready var circle_shape: Line2D = $Line2D
@onready var prizes: Node = $Prizes
@onready var player: Player = $Player

var shoots_used: int = 0
var mask_image: Image
var mask_texture: ImageTexture

var prize_found: Dictionary[int,int] = {}
var bad_prizes_found: int = 0

func _ready() -> void:
	_update_background_texture()
	_update_boundary()
	_update_image_fit()

	# The paintable scratch mask is runtime-only: building it in the editor
	# (via @tool) would bake the generated Image/ImageTexture into the scene
	# file on save. Same for forcing the cover visible.
	if not Engine.is_editor_hint():
		cover_sprite.visible = true
		_setup_scratch_mask()
		_update_boundary()
		player.set_sprite_frame()
		
	for prize in prizes.get_children():
		if prize is Prize:
			prize.prize_revealed.connect(update_prize_found)
			

func update_prize_found(_bad: bool, id: int) -> void:
	if not _bad:
		if prize_found.has(id):
			prize_found[id] += 1
		else:
			prize_found[id] = 1
	else:
		bad_prizes_found += 1
	check_win()
	
func check_win() -> void:
	if bad_prizes_found >= bad_prize_to_lose:
		lose()
	for prize_id in prize_found.keys():
		if prize_found[prize_id] >= good_prize_to_win:
			win()

func win() -> void:
	print("You Win!")
	
func lose() -> void:
	print("You Lose!")

func _setup_scratch_mask() -> void:
	mask_image = Image.create_empty(mask_resolution, mask_resolution, false, Image.FORMAT_R8)
	mask_image.fill(Color(1, 1, 1, 1))  # fully covered
	mask_texture = ImageTexture.create_from_image(mask_image)
	cover_sprite.texture = mask_texture

func _update_background_texture() -> void:
	if not background_sprite:
		return
	if background_texture:
		background_sprite.texture = background_texture
	if background_sprite.material and background_sprite.texture:
		var bg_mat := background_sprite.material as ShaderMaterial
		bg_mat.set_shader_parameter("texture_size", background_sprite.texture.get_size())
		bg_mat.set_shader_parameter("circle_center", Vector2(0.5, 0.5))

# Keeps the boundary line, background mask and cover sprite in sync with
# curr_radius — runs live in the editor (via @tool) so prizes can be placed
# against the actual ticket bounds without pressing Play.
func _update_boundary() -> void:
	if circle_shape:
		circle_shape.set_radius_immediate(curr_radius)
	if background_sprite and background_sprite.material:
		var bg_mat := background_sprite.material as ShaderMaterial
		bg_mat.set_shader_parameter("radius_px", curr_radius)
		bg_mat.set_shader_parameter("edge_softness", edge_softness)
	if cover_sprite and mask_texture:
		cover_sprite.scale = Vector2.ONE * (curr_radius * 2.0 / mask_resolution)

# How the artwork is framed inside the (fixed) ticket boundary — pan/zoom/rotate.
func _update_image_fit() -> void:
	if not background_sprite or not background_sprite.material:
		return
	var mat := background_sprite.material as ShaderMaterial
	mat.set_shader_parameter("image_offset", image_offset)
	mat.set_shader_parameter("image_zoom", image_zoom)
	mat.set_shader_parameter("image_rotation", image_rotation)

func bend_boundary(angle: float) -> void:
	circle_shape.bend_at(angle)

func can_shoot() -> bool:
	return true
	#return shoots_used < max_shoots

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
