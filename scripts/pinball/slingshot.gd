@tool
class_name Slingshot
extends StaticBody3D

## A slingshot kicker (the angled walls above the flippers). @tool so its greybox
## wall shows in the editor.
##
## The solid wall bounces the ball; the front trigger adds a sharp impulse along
## the wall's face normal (taken from the instance's orientation and flipped toward
## the ball, so it is deterministic). Impulse magnitude is read live from
## [PinballTuning]. Emits GameEvents.component_hit.

@export var tuning: PinballTuning
@export var length: float = 2.2:
	set(value):
		length = value
		_rebuild()
@export var thickness: float = 0.4:
	set(value):
		thickness = value
		_rebuild()
@export var height: float = 1.6:
	set(value):
		height = value
		_rebuild()
@export var retrigger_cooldown: float = 0.08

var _cooldown: float = 0.0

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.2
	phys_mat.bounce = 0.4
	physics_material_override = phys_mat
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta("greybox_generated"):
			remove_child(child)
			child.queue_free()

	var size := Vector3(length, height, thickness)
	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	col.set_meta("greybox_generated", true)
	add_child(col)

	var mesh_box := BoxMesh.new()
	mesh_box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_box
	mesh.set_meta("greybox_generated", true)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.75, 0.2)
	mesh_box.material = mat
	add_child(mesh)

	var area := Area3D.new()
	area.name = "KickTrigger"
	area.set_meta("greybox_generated", true)
	var trig := BoxShape3D.new()
	trig.size = Vector3(length, height, thickness + 0.5)
	var trig_col := CollisionShape3D.new()
	trig_col.shape = trig
	trig_col.position = Vector3(0.0, 0.0, thickness * 0.5 + 0.25)
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
	var normal := global_transform.basis.z
	normal.y = 0.0
	if normal.length() < 0.001:
		normal = Vector3(0.0, 0.0, 1.0)
	normal = normal.normalized()
	var to_ball := ball.global_position - global_position
	to_ball.y = 0.0
	if normal.dot(to_ball) < 0.0:
		normal = -normal
	ball.apply_central_impulse(normal * tuning.slingshot_impulse)
	_cooldown = retrigger_cooldown
	GameEvents.component_hit.emit(self, ball, {"type": "slingshot", "impulse": tuning.slingshot_impulse})
