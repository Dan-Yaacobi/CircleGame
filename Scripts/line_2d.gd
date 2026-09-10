@tool
extends Line2D

var radius: float = 100.0
@export var segments: int = 64

## Game-juice bend: on impact, the segments near the touch angle dent inward
## and spring back like a damped spring (with a little overshoot/wobble).
@export var bend_strength: float = 30.0  # px, max inward push at the touch point
@export_range(0.01, PI, 0.01) var bend_spread: float = 0.5  # radians, angular half-width affected
@export var bend_falloff: float = 2.0  # higher = tighter/sharper dent around the touch point
@export var bend_stiffness: float = 140.0  # spring tension — higher snaps back faster/harder
@export var bend_damping: float = 10.0  # higher settles the wobble faster, less bounce

var _bend_angle: float = 0.0
var _bend_intensity: float = 0.0  # spring displacement, 1.0 = full dent, oscillates through 0
var _bend_velocity: float = 0.0

func _ready():
	width = 4.0
	antialiased = true
	_update_circle()

func _process(delta: float) -> void:
	if absf(_bend_intensity) < 0.001 and absf(_bend_velocity) < 0.001:
		return
	var accel = -bend_stiffness * _bend_intensity - bend_damping * _bend_velocity
	_bend_velocity += accel * delta
	_bend_intensity += _bend_velocity * delta
	_update_circle()

func set_radius_immediate(new_radius: float) -> void:
	radius = new_radius
	_update_circle()

# Call at the moment of impact, e.g. when the coin lands back on the boundary.
func bend_at(angle: float, strength: float = 1.0) -> void:
	_bend_angle = angle
	_bend_intensity = maxf(strength, 0.0)
	_bend_velocity = 0.0
	_update_circle()

func _update_circle():
	var pts = PackedVector2Array()
	for i in range(segments + 1):
		var a = TAU * i / segments
		var r = radius - _bend_offset(a)
		pts.append(r * Vector2(cos(a), sin(a)))
	points = pts

func _bend_offset(a: float) -> float:
	if absf(_bend_intensity) < 0.001:
		return 0.0
	var diff = wrapf(a - _bend_angle, -PI, PI)
	var t = clampf(1.0 - abs(diff) / bend_spread, 0.0, 1.0)
	return bend_strength * _bend_intensity * pow(t, bend_falloff)
