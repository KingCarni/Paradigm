class_name PinballBall
extends RigidBody3D

## The physical pinball.
##
## Builds its own greybox sphere geometry and collision from [PinballTuning] so
## the .tscn stays trivial. Applies a custom gravity vector (see PinballTuning)
## in _integrate_forces rather than relying on default gravity, which lets the
## flat playfield behave like an inclined table while keeping one authoritative
## gravity source. Also enforces the documented max-velocity anti-tunnelling clamp.

@export var tuning: PinballTuning

var _reset_pending: bool = false
var _reset_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")

	# We integrate gravity ourselves for full control / single tuning source.
	gravity_scale = 0.0
	mass = tuning.ball_mass
	linear_damp = tuning.ball_linear_damp
	angular_damp = tuning.ball_angular_damp
	# Continuous collision detection is essential for high-speed reliability at
	# 120 Hz (see docs/PHYSICS_SPIKE.md pass criteria on tunnelling).
	continuous_cd = true
	# The active ball must never sleep: a sleeping RigidBody3D ignores plunger /
	# bumper / slingshot impulses (they don't reliably wake it) and can miss
	# collisions, producing a "dead ball". This surfaced in the headless self-test.
	can_sleep = false
	contact_monitor = false

	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = tuning.ball_friction
	phys_mat.bounce = tuning.ball_restitution
	physics_material_override = phys_mat

	_build_geometry()

func _build_geometry() -> void:
	var shape := SphereShape3D.new()
	shape.radius = tuning.ball_radius
	var col := CollisionShape3D.new()
	col.shape = shape
	col.name = "Collision"
	add_child(col)

	var sphere := SphereMesh.new()
	sphere.radius = tuning.ball_radius
	sphere.height = tuning.ball_radius * 2.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.name = "Mesh"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.9)
	mat.metallic = 0.7
	mat.roughness = 0.25
	sphere.material = mat
	add_child(mesh)

## Queue a teleport + velocity reset. Applied safely inside _integrate_forces.
func reset_to(pos: Vector3) -> void:
	_reset_position = pos
	_reset_pending = true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_pending:
		var t := state.transform
		t.origin = _reset_position
		state.transform = t
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_reset_pending = false
		return

	# Simulated-incline gravity: mostly -Y (holds ball to the flat field) with a
	# +Z pull toward the drain.
	state.linear_velocity += tuning.gravity_vector() * state.step

	var v := state.linear_velocity
	var max_v := tuning.max_ball_velocity
	if v.length() > max_v:
		state.linear_velocity = v.normalized() * max_v
