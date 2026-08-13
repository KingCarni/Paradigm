class_name Bumper
extends StaticBody3D

## A pop bumper.
##
## The solid cylinder body gives the ball a natural elastic bounce (restitution),
## and an overlapping Area3D adds a configurable outward "pop" impulse for that
## satisfying kick. Emits GameEvents.component_hit with context so scoring /
## combat / upgrades can react later WITHOUT this component knowing about them
## (docs/ARCHITECTURE.md communication rules). It knows nothing about progression.

@export var tuning: PinballTuning
@export var radius: float = 1.0
@export var height: float = 1.6

## Minimum seconds between pops from the same bumper, so a resting/grinding ball
## does not machine-gun impulses.
@export var retrigger_cooldown: float = 0.08

var _cooldown: float = 0.0

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")

	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.2
	phys_mat.bounce = 0.5
	physics_material_override = phys_mat

	_build_geometry()

func _build_geometry() -> void:
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	var col := CollisionShape3D.new()
	col.shape = cyl
	col.name = "Collision"
	add_child(col)

	var mesh_cyl := CylinderMesh.new()
	mesh_cyl.top_radius = radius
	mesh_cyl.bottom_radius = radius
	mesh_cyl.height = height
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_cyl
	mesh.name = "Mesh"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.25, 0.5)
	mesh_cyl.material = mat
	add_child(mesh)

	# Slightly larger trigger ring for the pop impulse.
	var area := Area3D.new()
	area.name = "PopTrigger"
	var trig_shape := CylinderShape3D.new()
	trig_shape.radius = radius + 0.25
	trig_shape.height = height
	var trig_col := CollisionShape3D.new()
	trig_col.shape = trig_shape
	area.add_child(trig_col)
	add_child(area)
	area.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func _on_body_entered(body: Node) -> void:
	if _cooldown > 0.0:
		return
	if not (body is PinballBall):
		return
	var ball := body as PinballBall
	var outward := ball.global_position - global_position
	outward.y = 0.0
	if outward.length() < 0.001:
		outward = Vector3(0.0, 0.0, 1.0)
	outward = outward.normalized()
	ball.apply_central_impulse(outward * tuning.bumper_impulse)
	_cooldown = retrigger_cooldown
	GameEvents.component_hit.emit(self, ball, {"type": "bumper", "impulse": tuning.bumper_impulse})
