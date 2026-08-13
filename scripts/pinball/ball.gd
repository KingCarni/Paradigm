@tool
class_name PinballBall
extends RigidBody3D

## The physical pinball.
##
## @tool so its greybox sphere is visible in the editor. Geometry is built
## parametrically from [member radius]; physics feel (mass, damping, restitution,
## friction) is applied from [PinballTuning] and can be re-applied live while
## tuning. Gravity is integrated manually (see PinballTuning.gravity_vector) so the
## flat playfield behaves like an inclined table, plus the documented
## anti-tunnelling velocity clamp.

@export var tuning: PinballTuning
@export var radius: float = 0.4:
	set(value):
		radius = value
		_rebuild()

var _reset_pending: bool = false
var _reset_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")
	gravity_scale = 0.0
	continuous_cd = true
	# The active ball must never sleep: a sleeping RigidBody3D ignores plunger /
	# bumper / slingshot impulses and can miss collisions ("dead ball").
	can_sleep = false
	contact_monitor = false
	apply_physics_from_tuning()

## (Re)apply mass / damping / restitution / friction from the tuning resource.
## Called on spawn and by the live tuning panel so changes take effect immediately.
func apply_physics_from_tuning() -> void:
	if tuning == null:
		return
	mass = tuning.ball_mass
	linear_damp = tuning.ball_linear_damp
	angular_damp = tuning.ball_angular_damp
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = tuning.ball_friction
	phys_mat.bounce = tuning.ball_restitution
	physics_material_override = phys_mat

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta("greybox_generated"):
			remove_child(child)
			child.queue_free()

	var shape := SphereShape3D.new()
	shape.radius = radius
	var col := CollisionShape3D.new()
	col.shape = shape
	col.set_meta("greybox_generated", true)
	add_child(col)

	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var mesh := MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.set_meta("greybox_generated", true)
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
