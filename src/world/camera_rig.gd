class_name CameraRig
extends Node3D
## A Sims-style camera: pan with WASD or the middle mouse button, orbit with the right mouse button or Q and E, zoom with the wheel.

const ORBIT_PER_PIXEL := 0.006
const PAN_PER_PIXEL := 0.0016
const KEY_ORBIT_PER_SECOND := 1.2
const KEY_PAN_PER_SECOND := 0.7
const ZOOM_STEP := 1.12
const LOWEST_TILT := 0.12
const HIGHEST_TILT := 1.45
const FOLLOW_SPEED := 4.0

var target := Vector3.ZERO
var yaw := 0.5
var tilt := 0.75
var distance := 100.0
var nearest := 1.0
var farthest := 1000.0
var follow: Variant = null  # A world position to stay centred on, or null.
var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.far = 20000.0
	camera.near = 0.05
	add_child(camera)
	apply()


## Sets where the camera starts, and how far it may zoom.
func frame(centre: Vector3, map_size: float) -> void:
	target = centre
	distance = map_size * 1.1
	nearest = map_size * 0.008
	farthest = map_size * 3.0
	apply()


## Moves the camera to its current position around the target.
func apply() -> void:
	var offset := Vector3(sin(yaw) * cos(tilt), sin(tilt), cos(yaw) * cos(tilt)) * distance
	camera.global_position = target + offset
	camera.look_at(target)


func _process(delta: float) -> void:
	var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") + _wasd()
	if keys != Vector2.ZERO:
		follow = null
		_pan(keys * KEY_PAN_PER_SECOND * delta * distance)
	yaw += (float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))) * KEY_ORBIT_PER_SECOND * delta
	if follow is Vector3:
		target = target.lerp(follow, minf(FOLLOW_SPEED * delta, 1.0))
	apply()


func _wasd() -> Vector2:
	return Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance / ZOOM_STEP, nearest)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance * ZOOM_STEP, farthest)
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= event.relative.x * ORBIT_PER_PIXEL
			tilt = clampf(tilt + event.relative.y * ORBIT_PER_PIXEL, LOWEST_TILT, HIGHEST_TILT)
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			follow = null
			_pan(-event.relative * PAN_PER_PIXEL * distance)


func _pan(by: Vector2) -> void:
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	target += right * by.x + forward * by.y
