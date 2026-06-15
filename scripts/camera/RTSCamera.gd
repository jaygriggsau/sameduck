class_name RTSCamera
extends Camera3D
## A simple RTS-style camera: WASD / arrow keys pan across the battlefield,
## Q / E rotate, mouse wheel (or +/-) zooms. The camera orbits a focus point
## on the ground so the view always looks down at the action.

@export var pan_speed: float = 14.0
@export var rotate_speed: float = 1.6
@export var zoom_speed: float = 2.5
@export var min_zoom: float = 8.0
@export var max_zoom: float = 34.0

var focus: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _zoom: float = 20.0
var _pitch_ratio: float = 0.62  # height/distance feel

func _ready() -> void:
	current = true
	_update_transform()

func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		move.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		move.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		move.x += 1.0

	if move != Vector3.ZERO:
		# Move relative to the current yaw so panning matches the view.
		var basis := Basis(Vector3.UP, _yaw)
		focus += basis * move.normalized() * pan_speed * delta

	if Input.is_physical_key_pressed(KEY_Q):
		_yaw += rotate_speed * delta
	if Input.is_physical_key_pressed(KEY_E):
		_yaw -= rotate_speed * delta
	if Input.is_physical_key_pressed(KEY_EQUAL):
		_zoom = max(min_zoom, _zoom - zoom_speed * delta * 10.0)
	if Input.is_physical_key_pressed(KEY_MINUS):
		_zoom = min(max_zoom, _zoom + zoom_speed * delta * 10.0)

	_update_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = max(min_zoom, _zoom - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = min(max_zoom, _zoom + zoom_speed)

func _update_transform() -> void:
	var dir := Basis(Vector3.UP, _yaw) * Vector3(0, _pitch_ratio, 1).normalized()
	global_position = focus + dir * _zoom
	look_at(focus, Vector3.UP)
