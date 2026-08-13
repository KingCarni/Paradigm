@tool
class_name Drain
extends Area3D

## The bottom drain. @tool so its trigger volume shows (faintly) in the editor.
## When the ball falls between the flippers into this trigger it emits
## GameEvents.ball_drained(ball). The table's active-ball service decides what to
## do next; the drain owns no lifecycle or scoring logic.

@export var size: Vector3 = Vector3(6.0, 2.0, 1.5):
	set(value):
		size = value
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta("greybox_generated"):
			remove_child(child)
			child.queue_free()

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
	mat.albedo_color = Color(0.8, 0.1, 0.1, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_box.material = mat
	add_child(mesh)

	if not Engine.is_editor_hint() and not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is PinballBall:
		GameEvents.ball_drained.emit(body)
