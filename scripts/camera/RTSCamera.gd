class_name RTSCamera
extends Camera3D
## A dual-mode battlefield camera.
##
## ORBIT mode (menus / deployment): WASD / arrows pan across the ground, Q/E
## rotate, mouse wheel zooms. The camera always looks at a focus point.
##
## FLY mode (during battles): a free-roam camera. Hold the right mouse button
## to mouselook, WASD to fly relative to where you're looking, E/Q to rise /
## descend, and the mouse wheel to change fly speed. Releasing the right mouse
## button frees the cursor so HUD buttons stay clickable.
##
## The mode follows GameManager state automatically (FLY while a battle is in
## progress, ORBIT otherwise).

enum Mode { ORBIT, FLY }

@export var pan_speed: float = 14.0
@export var rotate_speed: float = 1.6
@export var zoom_speed: float = 2.5
@export var min_zoom: float = 8.0
@export var max_zoom: float = 34.0

@export var look_sensitivity: float = 0.0045
@export var fly_speed: float = 16.0
@export var min_fly_speed: float = 4.0
@export var max_fly_speed: float = 60.0

# ORBIT state
var focus: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _zoom: float = 20.0
var _pitch_ratio: float = 0.62

# FLY state
var _mode: int = Mode.ORBIT
var _fly_yaw: float = 0.0
var _fly_pitch: float = -0.5
var _looking: bool = false

func _ready() -> void:
	current = true
	_update_orbit_transform()

func _process(delta: float) -> void:
	var desired := Mode.FLY if GameManager.state == GameManager.State.BATTLE else Mode.ORBIT
	if desired != _mode:
		_switch_mode(desired)
	if _mode == Mode.ORBIT:
		_process_orbit(delta)
	else:
		_process_fly(delta)

func _switch_mode(new_mode: int) -> void:
	_mode = new_mode
	if new_mode == Mode.FLY:
		# Seed the free camera from the current orbit orientation to avoid a jump.
		var e := global_transform.basis.get_euler()
		_fly_pitch = e.x
		_fly_yaw = e.y
	else:
		# Returning to orbit: release the cursor and refocus on the field.
		_release_look()
		focus = Vector3(global_position.x, 0, global_position.z) + Vector3(0, 0, 2)
		_update_orbit_transform()

# --- ORBIT ----------------------------------------------------------------
func _process_orbit(delta: float) -> void:
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
		var basis := Basis(Vector3.UP, _yaw)
		focus += basis * move.normalized() * pan_speed * delta

	if Input.is_physical_key_pressed(KEY_Q):
		_yaw += rotate_speed * delta
	if Input.is_physical_key_pressed(KEY_E):
		_yaw -= rotate_speed * delta

	_update_orbit_transform()

func _update_orbit_transform() -> void:
	var dir := Basis(Vector3.UP, _yaw) * Vector3(0, _pitch_ratio, 1).normalized()
	global_position = focus + dir * _zoom
	look_at(focus, Vector3.UP)

# --- FLY ------------------------------------------------------------------
func _process_fly(delta: float) -> void:
	global_transform.basis = Basis.from_euler(Vector3(_fly_pitch, _fly_yaw, 0.0))

	var dir := Vector3.ZERO
	var b := global_transform.basis
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir -= b.z
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir += b.z
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir += b.x
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir -= b.x
	if Input.is_physical_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q):
		dir -= Vector3.UP

	var boost := 2.2 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	if dir != Vector3.ZERO:
		global_position += dir.normalized() * fly_speed * boost * delta
		global_position.y = max(global_position.y, 0.5)  # don't sink below the field

# --- Input ----------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if _mode == Mode.ORBIT:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom = max(min_zoom, _zoom - zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = min(max_zoom, _zoom + zoom_speed)
		return

	# FLY mode
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_begin_look()
			else:
				_release_look()
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			fly_speed = min(max_fly_speed, fly_speed + 2.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			fly_speed = max(min_fly_speed, fly_speed - 2.0)
	elif event is InputEventMouseMotion and _looking:
		_fly_yaw -= event.relative.x * look_sensitivity
		_fly_pitch = clamp(_fly_pitch - event.relative.y * look_sensitivity, -1.45, 1.45)

func _begin_look() -> void:
	_looking = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release_look() -> void:
	if _looking:
		_looking = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	# Safety: never leave the game with a captured/hidden cursor.
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
