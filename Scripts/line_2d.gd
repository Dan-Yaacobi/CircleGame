@tool
extends Line2D

var radius: float = 100.0
@export var segments: int = 64

func _ready():
	width = 4.0
	antialiased = true
	_update_circle()

func set_radius_immediate(new_radius: float) -> void:
	radius = new_radius
	_update_circle()

func _update_circle():
	var pts = PackedVector2Array()
	for i in range(segments + 1):
		var a = TAU * i / segments
		pts.append(radius * Vector2(cos(a), sin(a)))
	points = pts
