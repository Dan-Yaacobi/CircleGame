@tool
extends Line2D

var radius: float = 100.0
@export var segments: int = 64

## Game-juice bend: when something touches the boundary, the segments near
## the touch angle dent inward and spring back over time.
@export var bend_strength: float = 18.0  # px, max inward push at the touch point
@export_range(0.01, PI, 0.01) var bend_spread: float = 0.6  # radians, angular half-width affected
@export var bend_falloff: float = 2.0  # higher = tighter/sharper dent around the touch point
@export var bend_recovery_speed: float = 6.0  # how fast the dent springs back, per second

var _bend_angle: float = 0.0
var _bend_intensity: float = 0.0  # 0..1

func _ready():
	width = 4.0
	antialiased = true
	_update_circle()

func _process(delta: float) -> void:
	if _bend_intensity <= 0.0:
		return
	_bend_intensity = move_toward(_bend_intensity, 0.0, bend_recovery_speed * delta)
	_update_circle()

func set_radius_immediate(new_radius: float) -> void:
	radius = new_radius
	_update_circle()

# Call whenever something touches the boundary at local angle `angle` (radians).
func bend_at(angle: float, strength: float = 1.0) -> void:
	_bend_angle = angle
	_bend_intensity = clampf(strength, 0.0, 1.0)
	_update_circle()

func _update_circle():
	var pts = PackedVector2Array()
	for i in range(segments + 1):
		var a = TAU * i / segments
		var r = radius - _bend_offset(a)
		pts.append(r * Vector2(cos(a), sin(a)))
	points = pts

func _bend_offset(a: float) -> float:
	if _bend_intensity <= 0.0:
		return 0.0
	var diff = wrapf(a - _bend_angle, -PI, PI)
	var t = clampf(1.0 - abs(diff) / bend_spread, 0.0, 1.0)
	return bend_strength * _bend_intensity * pow(t, bend_falloff)
