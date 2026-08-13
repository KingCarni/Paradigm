@tool
class_name Flipper
extends AnimatableBody3D

## A single flipper bat.
##
## @tool so the bat is visible in the editor. Rotates the body about its pivot
## (local Y) each physics frame; because it is animatable + sync_to_physics its
## motion imparts velocity to the ball. Rotation is stepped by the fixed physics
## delta -> frame-rate independent, deterministic. Rest/pressed angles and speeds
## are read from [PinballTuning] every frame so live tuning takes effect instantly.
## Also measures flip time (input -> full travel) for the debug overlay.
##
## IMPORTANT: table placement yaw is kept separate from runtime bat animation.
## Edit Mode temporarily exposes the authored placement transform and disables
## sync_to_physics so the flipper can be moved/rotated like every other component.

enum Side { LEFT, RIGHT }

@export var tuning: PinballTuning
## Which side this flipper is, which mirrors rest pose and press direction.
@export var side: Flipper.Side = Flipper.Side.LEFT
## Input action that raises this flipper (e.g. "flipper_left").
@export var action_name: StringName = &"flipper_left"
## Resting droop of the bat below horizontal, in degrees.
@export var rest_droop_degrees: float = 22.0
## Length of the bat from the pivot, in world units.
@export var bat_length: float = 3.2:
	set(value):
		bat_length = value
		_rebuild()

var _rest_yaw: float = 0.0
var _pressed_yaw: float = 0.0
var _current_yaw: float = 0.0
var _placement_yaw: float = 0.0
var _editing_table: bool = false
var _was_pressed: bool = false
var _press_start_usec: int = 0
var _measuring: bool = false
## Last measured time from press to full travel, in milliseconds (read by overlay).
var last_flip_ms: float = 0.0

func _ready() -> void:
	if tuning == null:
		tuning = load("res://data/pinball/table_tuning.tres")
	_rebuild()
	_recompute_angles()

	# The transform authored in the table scene / table definition represents
	# placement orientation. Runtime flipper motion is applied on top of it.
	_placement_yaw = rotation.y
	_current_yaw = _rest_yaw

	if not Engine.is_editor_hint():
		sync_to_physics = true
		_apply_runtime_rotation()

func _recompute_angles() -> void:
	var droop := deg_to_rad(rest_droop_degrees)
	var travel := deg_to_rad(tuning.flipper_travel_degrees)
	if side == Side.LEFT:
		_rest_yaw = -droop
		_pressed_yaw = _rest_yaw + travel
	else:
		_rest_yaw = PI + droop
		_pressed_yaw = _rest_yaw - travel

func _apply_runtime_rotation() -> void:
	rotation.y = _placement_yaw + _current_yaw

## Called by Developer Edit Mode before the SceneTree is paused.
## Convert the live animated transform back to the authored placement transform
## and release physics synchronization so direct transform edits are respected.
func begin_table_edit() -> void:
	if _editing_table:
		return
	_editing_table = true
	# Recover placement from the current live rotation in case this is called
	# after the flipper has already moved during gameplay.
	_placement_yaw = rotation.y - _current_yaw
	sync_to_physics = false
	rotation.y = _placement_yaw

## Called by Developer Edit Mode before gameplay resumes.
## Capture the edited placement yaw, then restore normal animated physics motion.
func end_table_edit() -> void:
	if not _editing_table:
		return
	_placement_yaw = rotation.y
	_editing_table = false
	sync_to_physics = true
	_apply_runtime_rotation()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.has_meta("greybox_generated"):
			remove_child(child)
			child.queue_free()

	var size := Vector3(bat_length, 0.8, 0.7)
	var offset := Vector3(bat_length * 0.5, 0.0, 0.0)

	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	col.position = offset
	col.set_meta("greybox_generated", true)
	add_child(col)

	var mesh_box := BoxMesh.new()
	mesh_box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_box
	mesh.position = offset
	mesh.set_meta("greybox_generated", true)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.35, 0.2)
	mesh_box.material = mat
	add_child(mesh)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _editing_table:
		return
	_recompute_angles()  # live-tunable travel/droop
	var pressed := Input.is_action_pressed(action_name)

	if pressed and not _was_pressed:
		_press_start_usec = Time.get_ticks_usec()
		_measuring = true
	_was_pressed = pressed

	var target := _pressed_yaw if pressed else _rest_yaw
	var speed_deg := tuning.flipper_press_speed if pressed else tuning.flipper_return_speed
	_current_yaw = move_toward(_current_yaw, target, deg_to_rad(speed_deg) * delta)
	_apply_runtime_rotation()

	if _measuring and pressed and absf(_current_yaw - _pressed_yaw) < 0.001:
		last_flip_ms = float(Time.get_ticks_usec() - _press_start_usec) / 1000.0
		_measuring = false
