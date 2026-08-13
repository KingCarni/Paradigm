@tool
class_name TableWall
extends StaticBody3D

## A reusable greybox box collider + mesh (floor, walls, lane guides, deflectors).
##
## @tool so the box is visible and live-editable in the Godot editor: change
## [member size] or [member wall_color] on an instance and it rebuilds in place.
## Placement is authored via the instance transform in the table scene, so moving
## a wall never requires editing layout constants in code.

@export var size: Vector3 = Vector3(2.0, 2.0, 2.0):
	set(value):
		size = value
		_rebuild()
@export var wall_color: Color = Color(0.30, 0.32, 0.38):
	set(value):
		wall_color = value
		_rebuild()
@export var friction: float = 0.1:
	set(value):
		friction = value
		_rebuild()
@export var bounce: float = 0.3:
	set(value):
		bounce = value
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_generated()

	var pm := PhysicsMaterial.new()
	pm.friction = friction
	pm.bounce = bounce
	physics_material_override = pm

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
	mat.albedo_color = wall_color
	mesh_box.material = mat
	add_child(mesh)

func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta("greybox_generated"):
			remove_child(child)
			child.queue_free()
