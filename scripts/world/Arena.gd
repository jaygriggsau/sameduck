class_name Arena
extends Node3D
## The 3D battlefield. Builds the ground, lighting and camera, handles unit
## placement during the deployment phase, spawns the enemy army, and runs the
## battle simulation (activating unit AI and detecting when a side is wiped).

signal budget_changed(remaining: int)
signal counts_changed(team_a: int, team_b: int)

const FIELD_X := 44.0   # width
const FIELD_Z := 30.0   # depth
const MARGIN := 1.5     # neutral strip at the centre line

var mode: int = GameManager.Mode.CAMPAIGN
var budget_total: int = 0
var budget_remaining: int = 0
var selected_unit_id: String = ""
var sandbox_team: int = GameManager.Team.A  # which team sandbox placement adds to

var _units_root: Node3D
var _projectiles_root: Node3D
var _camera: RTSCamera
var _battle_running: bool = false
var _count_timer: float = 0.0

func _ready() -> void:
	add_to_group("arena")
	_build_environment()
	_build_camera()
	_units_root = Node3D.new()
	_units_root.name = "Units"
	add_child(_units_root)
	_projectiles_root = Node3D.new()
	_projectiles_root.name = "Projectiles"
	add_child(_projectiles_root)

# --- Setup entry points ---------------------------------------------------
func setup_campaign(level: Dictionary) -> void:
	mode = GameManager.Mode.CAMPAIGN
	budget_total = level.get("budget", 500)
	budget_remaining = budget_total
	budget_changed.emit(budget_remaining)
	_spawn_enemy_army(level.get("enemies", []))
	_emit_counts()

func setup_sandbox() -> void:
	mode = GameManager.Mode.SANDBOX
	budget_total = 0
	budget_remaining = 0
	budget_changed.emit(budget_remaining)
	_emit_counts()

# --- Environment ----------------------------------------------------------
func _build_environment() -> void:
	# Lighting + sky
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3a6ea5")
	sky_mat.sky_horizon_color = Color("#bcd2e8")
	sky_mat.ground_horizon_color = Color("#bcd2e8")
	sky_mat.ground_bottom_color = Color("#6b7a5a")
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	# Ground (visual)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(FIELD_X, FIELD_Z)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("#5d7a4a")
	gmat.roughness = 1.0
	ground.material_override = gmat
	add_child(ground)

	# Centre line + zone tints
	_add_zone_strip(Vector3(0, 0.01, FIELD_Z * 0.25), Vector2(FIELD_X, FIELD_Z * 0.5), Color(0.3, 0.5, 1.0, 0.10))  # player (+z)
	_add_zone_strip(Vector3(0, 0.01, -FIELD_Z * 0.25), Vector2(FIELD_X, FIELD_Z * 0.5), Color(1.0, 0.3, 0.3, 0.10))  # enemy (-z)
	_add_zone_strip(Vector3(0, 0.02, 0), Vector2(FIELD_X, 0.25), Color(1, 1, 1, 0.5))  # centre line

	# Ground collision
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = Unit.LAYER_WORLD
	floor_body.collision_mask = 0
	floor_body.physics_material_override = _ground_material()
	add_child(floor_body)
	var fshape := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(FIELD_X, 1.0, FIELD_Z)
	fshape.shape = fbox
	fshape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(fshape)

	# Boundary walls (invisible) keep bodies on the field.
	_add_wall(Vector3(FIELD_X * 0.5, 2, 0), Vector3(1, 4, FIELD_Z))
	_add_wall(Vector3(-FIELD_X * 0.5, 2, 0), Vector3(1, 4, FIELD_Z))
	_add_wall(Vector3(0, 2, FIELD_Z * 0.5), Vector3(FIELD_X, 4, 1))
	_add_wall(Vector3(0, 2, -FIELD_Z * 0.5), Vector3(FIELD_X, 4, 1))

func _ground_material() -> PhysicsMaterial:
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.0
	return pm

func _add_zone_strip(pos: Vector3, size: Vector2, col: Color) -> void:
	var m := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = size
	m.mesh = pl
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	add_child(m)

func _add_wall(pos: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = Unit.LAYER_WORLD
	wall.collision_mask = 0
	wall.position = pos
	add_child(wall)
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	s.shape = b
	wall.add_child(s)

func _build_camera() -> void:
	_camera = RTSCamera.new()
	_camera.focus = Vector3(0, 0, 2)
	add_child(_camera)

# --- Placement ------------------------------------------------------------
func set_selected_unit(id: String) -> void:
	selected_unit_id = id

func set_sandbox_team(team: int) -> void:
	sandbox_team = team

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.state != GameManager.State.PLACEMENT:
		return
	if event is InputEventMouseButton and event.pressed:
		var point = _ground_point(event.position)
		if point == null:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_deploy(point)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_try_remove(point)

# Projects a screen position onto the ground plane (y = 0).
func _ground_point(screen_pos: Vector2):
	if _camera == null:
		return null
	var from := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t

func _in_player_zone(p: Vector3) -> bool:
	return p.z > MARGIN and p.z < FIELD_Z * 0.5 - 1.0 and absf(p.x) < FIELD_X * 0.5 - 1.0

func _in_enemy_zone(p: Vector3) -> bool:
	return p.z < -MARGIN and p.z > -FIELD_Z * 0.5 + 1.0 and absf(p.x) < FIELD_X * 0.5 - 1.0

func _try_deploy(point: Vector3) -> void:
	if selected_unit_id == "" or not UnitDatabase.has_unit(selected_unit_id):
		return
	var team: int
	if mode == GameManager.Mode.SANDBOX:
		team = sandbox_team
		# In sandbox, place within the chosen team's half.
		if team == GameManager.Team.A and not _in_player_zone(point):
			return
		if team == GameManager.Team.B and not _in_enemy_zone(point):
			return
		_spawn_unit(selected_unit_id, team, point)
	else:
		if not _in_player_zone(point):
			return
		var cost: int = UnitDatabase.get_unit(selected_unit_id).get("cost", 0)
		if cost > budget_remaining:
			return
		budget_remaining -= cost
		budget_changed.emit(budget_remaining)
		_spawn_unit(selected_unit_id, GameManager.Team.A, point)
	_emit_counts()

func _try_remove(point: Vector3) -> void:
	# Remove (and refund, in campaign) the nearest friendly unit to the click.
	var removable_team := sandbox_team if mode == GameManager.Mode.SANDBOX else GameManager.Team.A
	var group := "team_a" if removable_team == GameManager.Team.A else "team_b"
	var best: Unit = null
	var best_d := 4.0  # only remove if reasonably close
	for n in get_tree().get_nodes_in_group(group):
		var u := n as Unit
		if u == null or u.torso == null:
			continue
		var d := point.distance_to(u.torso.global_position)
		if d < best_d:
			best_d = d
			best = u
	if best != null:
		if mode == GameManager.Mode.CAMPAIGN:
			budget_remaining += int(best.stats.get("cost", 0))
			budget_changed.emit(budget_remaining)
		best.queue_free()
		await get_tree().process_frame
		_emit_counts()

func _spawn_unit(id: String, team: int, point: Vector3) -> void:
	var u := Unit.new()
	u.configure(id, team, Vector3(point.x, 0, point.z), self)
	_units_root.add_child(u)

func _spawn_enemy_army(enemies: Array) -> void:
	# Lay the enemy army out in rows on the far half.
	var flat: Array = []
	for entry in enemies:
		for i in entry.get("count", 1):
			flat.append(entry.unit)
	var n := flat.size()
	if n == 0:
		return
	var per_row := int(ceil(sqrt(float(n)) * 1.6))
	per_row = max(per_row, 1)
	var spacing := 2.4
	var idx := 0
	for id in flat:
		var row := idx / per_row
		var col := idx % per_row
		var count_in_row: int = min(per_row, n - row * per_row)
		var x := (col - (count_in_row - 1) * 0.5) * spacing
		var z := -4.0 - row * spacing
		z = max(z, -FIELD_Z * 0.5 + 1.5)
		_spawn_unit(id, GameManager.Team.B, Vector3(x, 0, z))
		idx += 1

func add_projectile(p: Projectile) -> void:
	_projectiles_root.add_child(p)

# --- Battle ---------------------------------------------------------------
func start_battle() -> void:
	_battle_running = true
	for n in get_tree().get_nodes_in_group("units"):
		var u := n as Unit
		if u != null:
			u.start_battle()

func _physics_process(delta: float) -> void:
	if not _battle_running:
		return
	_count_timer -= delta
	if _count_timer <= 0.0:
		_count_timer = 0.4
		var a := _count_team("team_a")
		var b := _count_team("team_b")
		counts_changed.emit(a, b)
		if a == 0 or b == 0:
			_battle_running = false
			GameManager.report_battle_result(a > 0)

func _count_team(group: String) -> int:
	var c := 0
	for n in get_tree().get_nodes_in_group(group):
		var u := n as Unit
		if u != null and u.alive:
			c += 1
	return c

func _emit_counts() -> void:
	counts_changed.emit(_count_team("team_a"), _count_team("team_b"))

func has_units(team: int) -> bool:
	var group := "team_a" if team == GameManager.Team.A else "team_b"
	return _count_team(group) > 0
