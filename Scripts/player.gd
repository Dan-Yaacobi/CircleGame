class_name Player extends CharacterBody2D

enum State { ORBITING, THROUGH_CENTER }

@export var angular_speed: float = 2.0  # radians/sec, positive = clockwise
@export var charge_speed_multiplier: float = 2.0
@export var launch_speed: float = 400.0

@onready var circle: Circle = $".."

var angle: float = 0.0
var state: State = State.ORBITING
var launch_dir: Vector2
var is_charging: bool = false

func _ready():
	angle = (global_position - circle.global_position).angle()

func _physics_process(delta):
	match state:
		State.ORBITING:
			_process_orbit(delta)
		State.THROUGH_CENTER:
			_process_through_center(delta)

func _process_orbit(delta: float) -> void:
	var current_speed = angular_speed
	if is_charging:
		current_speed *= charge_speed_multiplier

	angle += current_speed * delta
	var target_pos = circle.global_position + circle.curr_radius * Vector2(cos(angle), sin(angle))
	velocity = (target_pos - global_position) / delta
	move_and_slide()

func _process_through_center(_delta: float) -> void:
	velocity = launch_dir * launch_speed
	move_and_slide()

	var dist_from_center = global_position.distance_to(circle.global_position)
	if dist_from_center >= circle.curr_radius:
		_snap_to_orbit()

func _snap_to_orbit() -> void:
	state = State.ORBITING
	var offset = (global_position - circle.global_position).normalized()
	global_position = circle.global_position + offset * circle.curr_radius
	angle = offset.angle()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		is_charging = true
	elif event.is_action_released("shoot"):
		if is_charging:
			is_charging = false
			shoot_yourself()

func shoot_yourself() -> void:
	if state != State.ORBITING:
		return
	state = State.THROUGH_CENTER
	launch_dir = (circle.global_position - global_position).normalized()
