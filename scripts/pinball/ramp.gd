@tool
class_name Ramp
extends StaticBody3D

## A greybox ramp with real vertical elevation, redesigned to be dead-zone free.
## @tool so the geometry is visible in the editor (collision matches the mesh).
##
## Built in ramp-local space (entry at the low -Z end, exit at the high +Z end):
##   * a pitched floor slab the ball rolls up,
##   * two FULL-HEIGHT vertical side walls (floor -> above the slab) that enclose
##     the channel and its underside on both sides,
##   * a cap closing the underside at the high (+Z) end.
## The low end's slab meets the floor, so together these leave no pocket beside,
## behind or underneath the ramp. Meant to be placed flush against a table wall.
## Entry/exit Area3Ds detect traversal and emit semantic events.

@export var tuning: PinballTuning
@export var ramp_length: float = 6.0:
	set(value):
		ramp_length = value
		_rebuild()
@export var ramp_width: float = 1.5:
	set(value):
		ramp_width = value
		_rebuild()
@export var ramp_thickness: float = 0.35:
	set(value):
		ramp_thickness = value
		_rebuild()
@export var ramp_pitch_degrees: float = 18.0:
	set(value):
		ramp_pitch_degrees = value
		_rebuild()
@export var side_wall_height: float = 2.2:
	set(value):
		side_wall_height = value
		_rebuild()

var _rise: float = 0.0
var _entered: bool = false

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.3
	phys_mat.bounce = 0.1
	physics_material_override = phys_mat
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta("greybox_generated"):
			remove_child(child)
			child.queue_free()

	var pitch := deg_to_rad(ramp_pitch_degrees)
	_rise = ramp_length * sin(pitch)
	var slab_basis := Basis(Vector3.RIGHT, -pitch)
	var slab_origin := Vector3(0.0, _rise * 0.5, 0.0)

	# Pitched floor slab (the surface the ball rolls on).
	_add_box(Vector3(ramp_width, ramp_thickness, ramp_length), Transform3D(slab_basis, slab_origin), Color(0.45, 0.45, 0.5))

	# Full-height vertical side walls: enclose the channel and its underside.
	var half_w := ramp_width * 0.5
	for sign_x in [-1.0, 1.0]:
		var wall_origin := Vector3(sign_x * half_w, side_wall_height * 0.5, 0.0)
		_add_box(Vector3(0.2, side_wall_height, ramp_length), Transform3D(Basis(), wall_origin), Color(0.35, 0.35, 0.4))

	# Underside cap at the high (+Z) end (kept below the slab so it never blocks
	# the exit).
	var cap_height: float = maxf(0.6, _rise - ramp_thickness)
	_add_box(Vector3(ramp_width, cap_height, 0.2), Transform3D(Basis(), Vector3(0.0, cap_height * 0.5, ramp_length * 0.5)), Color(0.35, 0.35, 0.4))

	# Entry (low) and exit (high) triggers, sitting on the slab surface.
	var trig_size := Vector3(ramp_width, 1.4, 1.2)
	_add_trigger("EntryTrigger", Vector3(0.0, ramp_thickness + tuning.ball_radius, -(ramp_length * 0.5 - 0.6)), trig_size, _on_entry)
	_add_trigger("ExitTrigger", Vector3(0.0, _rise + tuning.ball_radius, ramp_length * 0.5 - 0.6), trig_size, _on_exit)

func _add_box(size: Vector3, xform: Transform3D, color: Color) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	col.transform = xform
	col.set_meta("greybox_generated", true)
	add_child(col)

	var mesh_box := BoxMesh.new()
	mesh_box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_box
	mesh.transform = xform
	mesh.set_meta("greybox_generated", true)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_box.material = mat
	add_child(mesh)

func _add_trigger(trigger_name: String, origin: Vector3, size: Vector3, callback: Callable) -> void:
	var area := Area3D.new()
	area.name = trigger_name
	area.position = origin
	area.set_meta("greybox_generated", true)
	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	area.add_child(col)
	add_child(area)
	if not Engine.is_editor_hint():
		area.body_entered.connect(callback)

## World position of the entry mouth (used by the QA self-test).
func get_entry_position() -> Vector3:
	var node := get_node_or_null("EntryTrigger")
	return (node as Node3D).global_position if node else global_position

func _on_entry(body: Node) -> void:
	if body is PinballBall:
		_entered = true
		GameEvents.component_hit.emit(self, body, {"type": "ramp_entry"})

func _on_exit(body: Node) -> void:
	if body is PinballBall and _entered:
		_entered = false
		GameEvents.component_completed.emit(self, {"type": "ramp", "ball": body})
