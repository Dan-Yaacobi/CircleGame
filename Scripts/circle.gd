class_name Circle extends Node2D

@onready var background_sprite: Sprite2D = $BackgroundSprite
@onready var circle_shape: Line2D = $Line2D
@onready var camera: Camera2D = $Camera2D

var curr_radius: float = 100.0
var target_radius: float = 100.0
var growth_speed: float = 20.0 

var zoom: Vector2 = Vector2(0.2,0.2)

func _ready():
	var mat = background_sprite.material as ShaderMaterial
	mat.set_shader_parameter("texture_size", background_sprite.texture.get_size())
	mat.set_shader_parameter("circle_center", Vector2(0.5, 0.5))
	_apply_radius(curr_radius)

func _process(delta):
	if not is_equal_approx(curr_radius, target_radius):
		curr_radius = move_toward(curr_radius, target_radius, growth_speed * delta)
		_apply_radius(curr_radius)

func set_target_radius(_radius: float) -> void:
	target_radius = _radius

func _apply_radius(radius: float) -> void:
	update_mask_radius(radius)
	circle_shape.set_radius_immediate(radius)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test"):
		set_target_radius(curr_radius + 25)
		camera.zoom_out(zoom)

func update_mask_radius(radius: float):
	var mat = background_sprite.material as ShaderMaterial
	mat.set_shader_parameter("radius_px", radius)

func bend_boundary(angle: float) -> void:
	circle_shape.bend_at(angle)
