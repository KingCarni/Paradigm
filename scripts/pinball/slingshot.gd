class_name Slingshot
extends StaticBody3D

## A slingshot kicker (the angled walls above the flippers).
##
## The solid angled wall bounces the ball; the front Area3D adds a sharp impulse
## along the wall's face normal for the classic slingshot snap. Impulse direction
## is taken from the body's orientation (deterministic / predictable, a spike pass
## criterion) and flipped if needed so it always fires toward the ball. Emits
## GameEvents.component_hit; knows nothing about scoring or progression.

@export var tuning: PinballTuning
@export var length: float = 3.0
@export var thickness: float = 0.4
@export var height: float = 1.6
@export var retrigger_cooldown: float = 0.08

var _cooldown: float = 0.0

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")

	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.2
	phys_mat.bounce = 0.4
	physics_material_override = phys_mat

	_build_geometry()

func _build_geometry() -> void:
	var size := Vector3(length, height, thickness)
	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	col.name = "Collision"
	add_child(col)

	var mesh_box := BoxMesh.new()
	mesh_box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_box
	mesh.name = "Mesh"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.75, 0.2)
	mesh_box.material = mat
	add_child(mesh)

	# Trigger just in front of the face (local +Z).
	var area := Area3D.new()
	area.name = "KickTrigger"
	var trig := BoxShape3D.new()
	trig.size = Vector3(length, height, thickness + 0.5)
	var trig_col := CollisionShape3D.new()
	trig_col.shape = trig
	trig_col.position = Vector3(0.0, 0.0, thickness * 0.5 + 0.25)
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
