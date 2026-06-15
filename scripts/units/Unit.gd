class_name Unit
extends Node3D
## An "active ragdoll" combat unit, à la Totally Accurate Battle Simulator.
##
## The unit is a wrapper Node3D that owns:
##   * a self-balancing RigidBody3D torso (a PD controller keeps it upright,
##     producing a constant comedic wobble and recovering from knockbacks),
##   * two joint-connected arm RigidBodies that dangle for extra ragdoll flair.
##
## While alive the unit seeks the nearest enemy, walks into range and attacks.
## When killed, the balancing controller switches off and the whole thing
## collapses into a limp ragdoll, with a death impulse for good measure.

signal died(unit: Unit)

# Collision layers (see project notes): 1=world, 2=unit body, 4=limb.
const LAYER_WORLD := 1
const LAYER_BODY := 2
const LAYER_LIMB := 4

# Balancing PD controller gains (tuned for the default ~3kg torso; scaled by mass).
const BALANCE_STIFFNESS := 40.0
const BALANCE_DAMPING := 9.0
const MOVE_FORCE := 9.0

var team: int = GameManager.Team.A
var stats: Dictionary = {}

var health: float = 100.0
var max_health: float = 100.0
var alive: bool = true
var simulating: bool = false  # AI only runs once the battle has begun

var torso: RigidBody3D
var _arms: Array[RigidBody3D] = []
var _phys_mat: PhysicsMaterial

var _target: Unit = null
var _retarget_timer: float = 0.0
var _attack_timer: float = 0.0
var _health_bar: Sprite3D
var _despawn_timer: float = -1.0
var _arena: Node = null

var _team_color: Color

# Configure must be called before the node enters the tree (before add_child).
func configure(unit_id: String, unit_team: int, world_pos: Vector3, arena: Node) -> void:
	stats = UnitDatabase.get_unit(unit_id)
	team = unit_team
	_arena = arena
	max_health = stats.get("max_health", 100.0)
	health = max_health
	position = world_pos
	_team_color = Color("#4f9dff") if team == GameManager.Team.A else Color("#ff5d5d")

func _ready() -> void:
	add_to_group("units")
	add_to_group(_team_group())
	_phys_mat = PhysicsMaterial.new()
	_phys_mat.friction = 0.9
	_phys_mat.bounce = 0.0
	_build_body()
	_build_health_bar()
	set_physics_process(true)

func _team_group() -> String:
	return "team_a" if team == GameManager.Team.A else "team_b"

func _enemy_group() -> String:
	return "team_b" if team == GameManager.Team.A else "team_a"

# --- Construction ---------------------------------------------------------
func _build_body() -> void:
	var s: float = stats.get("scale", 1.0)
	var radius := 0.34 * s
	var t_height := 1.5 * s   # full capsule height incl. caps
	var mass: float = stats.get("mass", 3.0)

	torso = RigidBody3D.new()
	torso.name = "Torso"
	torso.mass = mass
	torso.can_sleep = false
	torso.linear_damp = 1.4
	torso.angular_damp = 1.0
	torso.physics_material_override = _phys_mat
	torso.collision_layer = LAYER_BODY
	torso.collision_mask = LAYER_WORLD | LAYER_BODY
	torso.gravity_scale = 1.0
	add_child(torso)

	var shape := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = radius
	caps.height = t_height
	shape.shape = caps
	torso.add_child(shape)

	# Place the torso in the world (global transform requires being in-tree).
	torso.global_position = global_position + Vector3(0, t_height * 0.5 + 0.02, 0)

	var accent: Color = stats.get("accent", Color.WHITE)
	var model_path: String = stats.get("model", "")
	if model_path != "" and _attach_model(model_path, s, t_height, radius):
		# A custom model replaces the capsule body, head, weapon and arms.
		return

	# --- Default procedural body ---
	var body_mesh := MeshInstance3D.new()
	var caps_mesh := CapsuleMesh.new()
	caps_mesh.radius = radius
	caps_mesh.height = t_height
	body_mesh.mesh = caps_mesh
	body_mesh.material_override = _make_material(_team_color)
	torso.add_child(body_mesh)

	# Head (visual only, sits on top of the torso)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = radius * 0.85
	head_mesh.height = radius * 1.7
	head.mesh = head_mesh
	head.position = Vector3(0, t_height * 0.5 + radius * 0.5, 0)
	head.material_override = _make_material(_team_color.lightened(0.15))
	torso.add_child(head)

	# Weapon / accent nub on the front, so facing is readable.
	var weapon := MeshInstance3D.new()
	var weapon_mesh := BoxMesh.new()
	weapon_mesh.size = Vector3(0.12, 0.12, 0.9) * s
	weapon.mesh = weapon_mesh
	weapon.position = Vector3(radius * 0.9, t_height * 0.1, radius + 0.3 * s)
	weapon.material_override = _make_material(accent)
	torso.add_child(weapon)

	# Dangling arms as separate jointed rigid bodies.
	_build_arm(-1.0, radius, t_height, s, mass, accent)
	_build_arm(1.0, radius, t_height, s, mass, accent)

## Instantiates a GLB/scene model, scales it to the desired height, grounds it
## on the torso capsule and tints it slightly toward the team colour. Returns
## false if the model could not be loaded (caller falls back to the capsule).
func _attach_model(model_path: String, s: float, t_height: float, radius: float) -> bool:
	if not ResourceLoader.exists(model_path):
		push_warning("Unit: model not found: %s" % model_path)
		return false
	var scene := load(model_path) as PackedScene
	if scene == null:
		return false
	var inst := scene.instantiate()
	if inst == null:
		return false
	var holder := Node3D.new()
	holder.name = "Model"
	torso.add_child(holder)
	holder.add_child(inst)

	var aabb := _merged_local_aabb(inst)
	var size := aabb.size
	var src_h: float = max(size.y, 0.001)
	var target_h: float = stats.get("model_height", 1.85 * s)
	var k: float = target_h / src_h
	inst.scale = Vector3(k, k, k)

	# Centre horizontally and drop the feet onto the capsule bottom.
	var center_x: float = (aabb.position.x + size.x * 0.5) * k
	var center_z: float = (aabb.position.z + size.z * 0.5) * k
	var bottom: float = aabb.position.y * k
	inst.position = Vector3(-center_x, -t_height * 0.5 - bottom, -center_z)

	# Face the enemy half by default (the model faces +Z natively, which is the
	# player's side, so team A is spun around to look toward the enemy at -Z).
	var yaw: float = stats.get("model_yaw_deg", 0.0)
	if team == GameManager.Team.A:
		yaw += 180.0
	holder.rotation = Vector3(0, deg_to_rad(yaw), 0)

	# Subtle team tint so blue/red sides stay readable.
	_tint_model(inst, _team_color)
	return true

## Washes the model toward its team colour using a translucent material overlay,
## which keeps the baked textures intact underneath.
func _tint_model(node: Node, col: Color) -> void:
	var overlay := StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(col.r, col.g, col.b, 0.28)
	for vi in node.find_children("*", "MeshInstance3D", true, false):
		(vi as MeshInstance3D).material_overlay = overlay

## Merged AABB of every VisualInstance3D under `root`, expressed in `root`'s
## local space (no global transforms needed; safe to call right after spawn).
func _merged_local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var have := false
	for vi in root.find_children("*", "VisualInstance3D", true, false):
		var v := vi as VisualInstance3D
		var rel := _relative_transform(root, v)
		var t := rel * v.get_aabb()
		if not have:
			result = t
			have = true
		else:
			result = result.merge(t)
	return result

func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xform = (n as Node3D).transform * xform
		n = n.get_parent()
	return xform

func _build_arm(side: float, radius: float, t_height: float, s: float, body_mass: float, accent: Color) -> void:
	var arm := RigidBody3D.new()
	arm.name = "Arm%s" % ("L" if side < 0 else "R")
	arm.mass = max(0.3, body_mass * 0.12)
	arm.can_sleep = false
	arm.linear_damp = 0.5
	arm.angular_damp = 0.5
	arm.physics_material_override = _phys_mat
	arm.collision_layer = LAYER_LIMB
	arm.collision_mask = LAYER_WORLD  # arms only collide with the ground
	add_child(arm)

	var arm_len := 0.6 * s
	var arm_r := 0.12 * s
	var ashape := CollisionShape3D.new()
	var acaps := CapsuleShape3D.new()
	acaps.radius = arm_r
	acaps.height = arm_len
	ashape.shape = acaps
	arm.add_child(ashape)

	var amesh := MeshInstance3D.new()
	var acaps_mesh := CapsuleMesh.new()
	acaps_mesh.radius = arm_r
	acaps_mesh.height = arm_len
	amesh.mesh = acaps_mesh
	amesh.material_override = _make_material(accent.lerp(_team_color, 0.5))
	arm.add_child(amesh)

	# Shoulder anchor in world space.
	var shoulder := torso.global_position + Vector3(side * (radius + arm_r + 0.02), t_height * 0.25, 0)
	arm.global_position = shoulder - Vector3(0, arm_len * 0.5, 0)
	_arms.append(arm)

	var joint := PinJoint3D.new()
	joint.name = "Shoulder%s" % ("L" if side < 0 else "R")
	add_child(joint)
	joint.global_position = shoulder
	joint.node_a = torso.get_path()
	joint.node_b = arm.get_path()

func _make_material(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.7
	return m

func _build_health_bar() -> void:
	_health_bar = Sprite3D.new()
	_health_bar.texture = _make_bar_texture()
	_health_bar.pixel_size = 0.01
	_health_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar.no_depth_test = true
	_health_bar.position = Vector3(0, 1.7 * stats.get("scale", 1.0), 0)
	_health_bar.modulate = Color(0.3, 1.0, 0.4)
	torso.add_child(_health_bar)

func _make_bar_texture() -> Texture2D:
	var img := Image.create(64, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

# --- Simulation control ---------------------------------------------------
func start_battle() -> void:
	simulating = true

func _physics_process(delta: float) -> void:
	if torso == null:
		return
	_update_health_bar()

	if not alive:
		if _despawn_timer >= 0.0:
			_despawn_timer -= delta
			if _despawn_timer <= 0.0:
				queue_free()
		return

	# Keep the torso upright at all times (so units stand in the placement
	# phase too); only seek/fight once the battle has started.
	_apply_balance(delta)

	if not simulating:
		return

	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or not _is_target_valid():
		_acquire_target()
		_retarget_timer = 0.35

	_attack_timer = max(0.0, _attack_timer - delta)
	if _is_target_valid():
		_pursue_and_attack(delta)

func _apply_balance(_delta: float) -> void:
	var up := torso.global_transform.basis.y
	var axis := up.cross(Vector3.UP)
	var angle := up.angle_to(Vector3.UP)
	var scale_k: float = torso.mass / 3.0
	if axis.length() > 0.0001 and angle > 0.0001:
		axis = axis.normalized()
		var corrective := axis * angle * BALANCE_STIFFNESS * scale_k
		var damp := torso.angular_velocity * BALANCE_DAMPING * scale_k
		torso.apply_torque(corrective - damp)

# --- Targeting & combat ---------------------------------------------------
func _acquire_target() -> void:
	var best: Unit = null
	var best_d := INF
	var my_pos := torso.global_position
	for n in get_tree().get_nodes_in_group(_enemy_group()):
		var u := n as Unit
		if u == null or not u.alive or u.torso == null:
			continue
		var d := my_pos.distance_squared_to(u.torso.global_position)
		if d < best_d:
			best_d = d
			best = u
	_target = best

func _is_target_valid() -> bool:
	return _target != null and is_instance_valid(_target) and _target.alive and _target.torso != null

func _pursue_and_attack(_delta: float) -> void:
	var to_target := _target.torso.global_position - torso.global_position
	to_target.y = 0.0
	var dist := to_target.length()
	var atk_range: float = stats.get("attack_range", 1.8)

	if dist > atk_range * 0.85:
		# Steer toward the target on the horizontal plane.
		var dir := to_target.normalized() if dist > 0.001 else Vector3.ZERO
		var hv := torso.linear_velocity
		hv.y = 0.0
		var desired := dir * float(stats.get("move_speed", 4.0))
		var steer := (desired - hv) * MOVE_FORCE * torso.mass
		torso.apply_central_force(Vector3(steer.x, 0, steer.z))
	if dist <= atk_range and _attack_timer <= 0.0:
		_do_attack(to_target)

func _do_attack(to_target: Vector3) -> void:
	_attack_timer = stats.get("attack_cooldown", 1.0)
	var dir := to_target.normalized() if to_target.length() > 0.001 else Vector3.FORWARD
	if stats.get("is_ranged", false):
		_fire_projectile(dir)
	else:
		# Melee: lunge slightly and strike.
		torso.apply_central_impulse(dir * torso.mass * 0.6)
		if _is_target_valid():
			_target.take_damage(stats.get("attack_damage", 10.0), dir, stats.get("knockback", 4.0))

func _fire_projectile(dir: Vector3) -> void:
	if _arena == null or not _is_target_valid():
		return
	var proj := Projectile.new()
	var muzzle := torso.global_position + Vector3(0, 0.3, 0) + dir * 0.8
	proj.configure(self, _target, muzzle, stats)
	_arena.add_projectile(proj)

# --- Damage & death -------------------------------------------------------
func take_damage(amount: float, hit_dir: Vector3, knockback: float) -> void:
	if not alive:
		return
	health -= amount
	if torso != null:
		var kb := hit_dir.normalized() if hit_dir.length() > 0.001 else Vector3.ZERO
		# Heavier units resist knockback (divide by mass factor).
		var resist: float = clamp(3.0 / torso.mass, 0.25, 1.2)
		torso.apply_central_impulse((kb + Vector3.UP * 0.4) * knockback * resist)
	if health <= 0.0:
		_die(hit_dir)

func _die(hit_dir: Vector3) -> void:
	alive = false
	simulating = false
	remove_from_group(_team_group())
	remove_from_group("units")
	if _health_bar != null:
		_health_bar.visible = false
	# Go limp: collapse into a ragdoll with a final shove.
	if torso != null:
		torso.angular_damp = 0.2
		var shove := hit_dir.normalized() if hit_dir.length() > 0.001 else Vector3(randf() - 0.5, 0, randf() - 0.5)
		torso.apply_central_impulse((shove + Vector3.UP * 0.5) * 4.0)
		torso.apply_torque(Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)) * torso.mass)
	_despawn_timer = 4.0
	died.emit(self)

func _update_health_bar() -> void:
	if _health_bar == null:
		return
	if not alive:
		return
	var frac: float = clamp(health / max_health, 0.0, 1.0)
	_health_bar.scale = Vector3(frac, 1, 1)
	_health_bar.modulate = Color(1.0 - frac, frac, 0.25)
