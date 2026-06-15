class_name Projectile
extends Node3D
## A homing-ish projectile (arrow / bomb). It tracks the position of its
## target while in flight; on impact it deals damage (single-target or AoE)
## and applies knockback. Created and configured by ranged Units.

var _shooter: Unit
var _target: Unit
var _last_target_pos: Vector3
var _speed: float = 20.0
var _damage: float = 10.0
var _knockback: float = 4.0
var _aoe_radius: float = 0.0
var _team: int = 0
var _accent: Color = Color.WHITE
var _life: float = 6.0

func configure(shooter: Unit, target: Unit, start_pos: Vector3, stats: Dictionary) -> void:
	_shooter = shooter
	_target = target
	_team = shooter.team
	position = start_pos
	_last_target_pos = target.torso.global_position if (target and target.torso) else start_pos
	_speed = stats.get("projectile_speed", 20.0)
	_damage = stats.get("attack_damage", 10.0)
	_knockback = stats.get("knockback", 4.0)
	_aoe_radius = stats.get("aoe_radius", 0.0)
	_accent = stats.get("accent", Color.WHITE)

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	if _aoe_radius > 0.0:
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		mesh.mesh = sm
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.08, 0.7)
		mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _accent
	mat.emission_enabled = true
	mat.emission = _accent * 0.6
	mesh.material_override = mat
	add_child(mesh)

func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return

	# Track the target's current position if it's still alive.
	if _target != null and is_instance_valid(_target) and _target.alive and _target.torso != null:
		_last_target_pos = _target.torso.global_position + Vector3(0, 0.4, 0)

	var to := _last_target_pos - global_position
	var dist := to.length()
	if dist <= 0.5:
		_impact()
		return

	var step := _speed * delta
	if step >= dist:
		_impact()
		return
	var dir := to / dist
	global_position += dir * step
	if absf(dir.dot(Vector3.UP)) < 0.99:
		look_at(global_position + dir, Vector3.UP)

func _impact() -> void:
	var hit_pos := global_position
	if _aoe_radius > 0.0:
		_explode(hit_pos)
	else:
		if _target != null and is_instance_valid(_target) and _target.alive:
			var dir := (_target.torso.global_position - hit_pos)
			_target.take_damage(_damage, dir, _knockback)
	queue_free()

func _explode(center: Vector3) -> void:
	var enemy_group := "team_b" if _team == GameManager.Team.A else "team_a"
	for n in get_tree().get_nodes_in_group(enemy_group):
		var u := n as Unit
		if u == null or not u.alive or u.torso == null:
			continue
		var d := center.distance_to(u.torso.global_position)
		if d <= _aoe_radius:
			var falloff: float = clamp(1.0 - d / _aoe_radius, 0.2, 1.0)
			var dir := u.torso.global_position - center
			u.take_damage(_damage * falloff, dir, _knockback)
