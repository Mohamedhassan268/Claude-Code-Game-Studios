class_name PersonView
extends Node3D
## A stand-in person, kept a readable size on screen at any zoom. A rigged character replaces the body in Phase 3.

const SCREEN_SIZE := 0.022
const BOB_PER_SECOND := 9.0
const BOB_HEIGHT := 0.05
const MARKER_SPIN_PER_SECOND := 1.6
const BODY_COLOUR := Color(0.93, 0.62, 0.25)
const INJURED_COLOUR := Color(0.85, 0.25, 0.25)
const DEAD_COLOUR := Color(0.3, 0.3, 0.32)
const WELL := Color(0.25, 0.85, 0.45)
const UNEASY := Color(0.95, 0.75, 0.2)
const DISTRESSED := Color(0.9, 0.2, 0.2)

var _body: MeshInstance3D
var _marker: MeshInstance3D
var _body_paint: StandardMaterial3D
var _marker_paint: StandardMaterial3D
var _clock := 0.0
var _walking := false


func _ready() -> void:
	_body_paint = StandardMaterial3D.new()
	_body_paint.albedo_color = BODY_COLOUR
	_body = _part(CapsuleMesh.new(), _body_paint, Vector3(0.0, 0.75, 0.0))
	var capsule: CapsuleMesh = _body.mesh
	capsule.radius = 0.28
	capsule.height = 1.1
	var head := SphereMesh.new()
	head.radius = 0.24
	head.height = 0.48
	_part(head, _body_paint, Vector3(0.0, 1.55, 0.0))
	_marker_paint = StandardMaterial3D.new()
	_marker_paint.albedo_color = WELL
	_marker_paint.emission_enabled = true
	_marker_paint.emission = WELL
	var marker_shape := TorusMesh.new()
	marker_shape.inner_radius = 0.16
	marker_shape.outer_radius = 0.28
	_marker = _part(marker_shape, _marker_paint, Vector3(0.0, 2.25, 0.0))
	_marker.rotation.x = PI / 2.0
	_marker.visible = false


## Updates this person for a moment in the run.
func show_state(world_position: Vector3, record: Dictionary, is_selected: bool, is_walking: bool, camera_distance: float) -> void:
	position = world_position
	scale = Vector3.ONE * camera_distance * SCREEN_SIZE
	_walking = is_walking
	var is_alive: bool = record["alive"]
	_body_paint.albedo_color = DEAD_COLOUR if not is_alive else INJURED_COLOUR if record["injured"] else BODY_COLOUR
	rotation.z = 0.0 if is_alive else PI / 2.0
	_marker.visible = is_selected and is_alive
	_paint_marker(mood_of(record))


## How a person is doing from 0 (distressed) to 1 (well): their lowest need, pulled down by stress.
static func mood_of(record: Dictionary) -> float:
	var lowest := 1.0
	for value: float in record["needs"].values():
		lowest = minf(lowest, value)
	return clampf(lowest * (1.0 - 0.5 * float(record["stress"])), 0.0, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	_body.position.y = 0.75 + (absf(sin(_clock * BOB_PER_SECOND)) * BOB_HEIGHT if _walking else 0.0)
	_marker.rotation.z += MARKER_SPIN_PER_SECOND * delta


func _paint_marker(mood: float) -> void:
	var colour := DISTRESSED.lerp(UNEASY, mood * 2.0) if mood < 0.5 else UNEASY.lerp(WELL, mood * 2.0 - 1.0)
	_marker_paint.albedo_color = colour
	_marker_paint.emission = colour


func _part(mesh: PrimitiveMesh, paint: StandardMaterial3D, at: Vector3) -> MeshInstance3D:
	mesh.material = paint
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	add_child(part)
	return part
