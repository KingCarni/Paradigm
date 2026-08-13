@tool
class_name Bumper
extends StaticBody3D

## A pop bumper. @tool so the greybox cylinder shows in the editor.
##
## The solid cylinder gives a natural elastic bounce; an overlapping trigger ring
## adds a configurable outward "pop" impulse. Emits GameEvents.component_hit so
## scoring / combat / upgrades can react later without this component knowing about
## them. Impulse magnitude is read live from [PinballTuning].

@export var tuning: PinballTuning
@export var radius: float = 1.0:
	set(value):
		radius = value
		_rebuild()
@export var height: float = 1.6:
	set(value):
		height = value
		_rebuild()
## Minimum seconds between pops so a resting/grinding ball does not machine-gun.
@export var retrigger_cooldown: float = 0.08

var _cooldown: float = 0.0

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.2
	phys_mat.bounce = 0.5
	physics_material_override = phys_mat
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta("greybox_generated"):
			remove_child(child)
			child.queue_free()

	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	var col := CollisionShape3D.new()
	col.shape = cyl
	col.set_meta("greybox_generated", true)
	add_child(col)

	var mesh_cyl := CylinderMesh.new()
	mesh_cyl.top_radius = radius
	mesh_cyl.bottom_radius = radius
	mesh_cyl.height = height
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_cyl
	mesh.set_meta("greybox_generated", true)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.25, 0.5)
	mesh_cyl.material = mat
	add_child(mesh)

	var area := Area3D.new()
	area.name = "PopTrigger"
	area.set_meta("greybox_generated", true)
	var trig_shape := CylinderShape3D.new()
	trig_shape.radius = radius + 0.25
	trig_shape.height = height
	var trig_col := CollisionShape3D.new()
	trig_col.shape = trig_shape
	area.add_child(trig_col)
	add_child(area)
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
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
