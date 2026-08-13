class_name Ramp
extends StaticBody3D

## A greybox ramp with real vertical elevation.
##
## Built in ramp-local space: the ball enters at the low -Z end (y ~ 0), rolls up
## the pitched floor between two side rails, and exits at the high +Z end onto the
## upper playfield (where table gravity carries it back down). Entry and exit
## Area3Ds detect traversal and emit semantic events. All CollisionShape3Ds are
## direct children of this body (Godot requires that) with their own transforms.

@export var tuning: PinballTuning
@export var ramp_length: float = 8.0
@export var ramp_width: float = 1.6
@export var ramp_thickness: float = 0.4
@export var ramp_pitch_degrees: float = 20.0
@export var rail_height: float = 1.0

var _rise: float = 0.0
var _entered: bool = false

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")

	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.3
	phys_mat.bounce = 0.1
	physics_material_override = phys_mat

	_build_geometry()

func _build_geometry() -> void:
	var pitch := deg_to_rad(ramp_pitch_degrees)
	_rise = ramp_length * sin(pitch)
	var floor_basis := Basis(Vector3.RIGHT, -pitch)
	var floor_origin := Vector3(0.0, _rise * 0.5, 0.0)

	# Floor.
	_add_box_collision(Vector3(ramp_width, ramp_thickness, ramp_length), Transform3D(floor_basis, floor_origin))
	_add_box_mesh(Vector3(ramp_width, ramp_thickness, ramp_length), Transform3D(floor_basis, floor_origin), Color(0.45, 0.45, 0.5))

	# Side rails, sitting on the floor in local floor space.
	for sign_x in [-1.0, 1.0]:
		var rail_local := Vector3(sign_x * (ramp_width * 0.5), ramp_thickness * 0.5 + rail_height * 0.5, 0.0)
		var rail_origin := floor_origin + floor_basis * rail_local
		var rail_xform := Transform3D(floor_basis, rail_origin)
		var rail_size := Vector3(0.3, rail_height, ramp_length)
		_add_box_collision(rail_size, rail_xform)
		_add_box_mesh(rail_size, rail_xform, Color(0.35, 0.35, 0.4))

	# Entry (low) and exit (high) triggers, placed on the floor surface.
	var surface_y := ramp_thickness * 0.5 + tuning.ball_radius
	var entry_local := Vector3(0.0, surface_y, -(ramp_length * 0.5 - 0.6))
	var exit_local := Vector3(0.0, surface_y, ramp_length * 0.5 - 0.6)
	_add_trigger("EntryTrigger", floor_origin + floor_basis * entry_local, floor_basis, _on_entry)
	_add_trigger("ExitTrigger", floor_origin + floor_basis * exit_local, floor_basis, _on_exit)

func _add_box_collision(size: Vector3, xform: Transform3D) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	col.transform = xform
	add_child(col)

func _add_box_mesh(size: Vector3, xform: Transform3D, color: Color) -> void:
	var mesh_box := BoxMesh.new()
	mesh_box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_box
	mesh.transform = xform
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_box.material = mat
	add_child(mesh)

func _add_trigger(trigger_name: String, origin: Vector3, basis: Basis, callback: Callable) -> void:
	var area := Area3D.new()
	area.name = trigger_name
	area.transform = Transform3D(basis, origin)
	var box := BoxShape3D.new()
	box.size = Vector3(ramp_width, 1.2, 1.0)
	var col := CollisionShape3D.new()
	col.shape = box
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(callback)

func _on_entry(body: Node) -> void:
	if body is PinballBall:
		_entered = true
		GameEvents.component_hit.emit(self, body, {"type": "ramp_entry"})

func _on_exit(body: Node) -> void:
	if body is PinballBall and _entered:
		_entered = false
		GameEvents.component_completed.emit(self, {"type": "ramp", "ball": body})
