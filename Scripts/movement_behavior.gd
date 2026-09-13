class_name MovementBehavior extends Resource

## Reusable position-animation config for any Node2D (prizes, enemies,
## whatever) — it only ever touches .position, so it drops onto anything.
## Usage on the owning node:
##
##   @export var movement: MovementBehavior
##   var _movement_origin: Vector2
##   var _movement_time: float = 0.0
##
##   func _ready():
##       _movement_origin = position
##
##   func _process(delta):
##       if Engine.is_editor_hint():
##           return  # don't let a live preview drift the saved .position
##       if movement:
##           _movement_time += delta
##           movement.apply(self, _movement_origin, _movement_time)
##
## Deliberately stateless (no timers/counters live here) — the resource can
## be shared by many nodes (e.g. several prizes using the same "gentle
## bob" asset) without them fighting over shared progress, the same trap
## a shared ShaderMaterial hit earlier in this project.

enum Type { NONE, VERTICAL, HORIZONTAL, DIAGONAL, CIRCLE }

@export var type: Type = Type.NONE

## Radians/sec — how fast the motion cycles (oscillation or orbit speed).
@export var speed: float = 2.0

## Px — oscillation amplitude for VERTICAL/HORIZONTAL/DIAGONAL (how far it
## swings from its resting point each way). Not used by CIRCLE — its orbit
## radius is each object's own starting distance from the orbit center
## (see apply() below), so several objects scattered at different distances
## keep their layout while all orbiting the same center together, instead
## of each one just circling in place around wherever it started.
@export var distance: float = 12.0

## Direction of travel for DIAGONAL, in degrees (0 = →, 90 = ↑). Vertical
## and horizontal are just this same linear motion at 90°/0°.
@export_range(0.0, 360.0, 1.0) var diagonal_angle_degrees: float = 45.0

# Pure function of elapsed time — no side effects, safe to call from many
# nodes sharing one resource. Doesn't cover CIRCLE: orbiting a shared point
# needs the object's own starting position too — see apply().
func compute_offset(elapsed: float) -> Vector2:
	match type:
		Type.VERTICAL:
			return Vector2(0.0, sin(elapsed * speed) * distance)
		Type.HORIZONTAL:
			return Vector2(sin(elapsed * speed) * distance, 0.0)
		Type.DIAGONAL:
			var dir := Vector2.RIGHT.rotated(deg_to_rad(diagonal_angle_degrees))
			return dir * sin(elapsed * speed) * distance
		_:
			return Vector2.ZERO

## Convenience: positions `node` at `origin` plus this behavior's offset at
## `elapsed` seconds. CIRCLE instead orbits around `center` (defaults to the
## local origin, e.g. a ticket's own center), using `origin`'s own distance
## and angle from `center` as the starting radius/phase — so it eases into
## orbiting from wherever it's already placed rather than snapping onto a
## fixed-radius ring.
func apply(node: Node2D, origin: Vector2, elapsed: float, center: Vector2 = Vector2.ZERO) -> void:
	if type == Type.CIRCLE:
		var from_center := origin - center
		var radius := from_center.length()
		var angle := from_center.angle() + elapsed * speed
		node.position = center + Vector2(cos(angle), sin(angle)) * radius
	else:
		node.position = origin + compute_offset(elapsed)
